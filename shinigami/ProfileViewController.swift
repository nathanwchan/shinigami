//
//  ProfileViewController.swift
//  shinigami
//
//  Created by Nathan Chan on 6/1/17.
//  Copyright © 2017 Nathan Chan. All rights reserved.
//

import UIKit
import TwitterKit
import SwiftyJSON
import RealmSwift
import SafariServices

class ProfileViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, TWTRTweetViewDelegate, SFSafariViewControllerDelegate {
    
    var user: TWTRUserCustom?
    var userID: String?
    var list: TWTRList?
    var favorite: Favorite?
    private let client = TWTRAPIClient.withCurrentUser()
    private var clientError: NSError?
    private var tweets: [TWTRTweet] = []
    private var showSpinnerCell: Bool = true
    private var showSorryCell: Bool = false
    private func errorOccured() {
        self.showSpinnerCell = false
        self.showSorryCell = true
        self.profileTableView.reloadData()
    }
    var navigationTitleUILabel = UILabel()
    var profileCellInView: Bool = true
    
    @IBOutlet weak var profileTableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.profileTableView.dataSource = self
        self.profileTableView.delegate = self
        
        // dynamic cell height based on inner content
        self.profileTableView.rowHeight = UITableViewAutomaticDimension
        self.profileTableView.estimatedRowHeight = 120
        // remove separator lines between empty rows
        self.profileTableView.tableFooterView = UIView(frame: CGRect.zero)
        
        if self.user != nil {
            loadTweetsFromList()
        } else {
            guard let userID = self.userID else {
                fatalError("User and UserID are not set.")
            }
            let getUserEndpoint = "https://api.twitter.com/1.1/users/show.json?user_id=\(userID)"
            let request = self.client.urlRequest(withMethod: "GET", url: getUserEndpoint, parameters: nil, error: &self.clientError)
            
            self.client.sendTwitterRequest(request) { (_, data, connectionError) -> Void in
                guard let data = data else {
                    print("Error: \(connectionError.debugDescription)")
                    firebase.logEvent("twitter_error_users_show")
                    self.errorOccured()
                    return
                }
                
                let jsonData = JSON(data: data)
                self.user = TWTRUserCustom(json: jsonData)
                
                self.loadTweetsFromList()
            }
        }
        
    }
    
    func addOrDeleteFavoriteFromDB() {
        let realm = try! Realm()
        try! realm.write() {
            if let favorite = self.favorite {
                realm.delete(favorite)
                self.favorite = nil
                
                firebase.logEvent("profile_delete_favorite_\(self.user?.screenName ?? "unknown")")
            } else {
                guard let ownerId = Twitter.sharedInstance().sessionStore.session()?.userID else {
                    return
                }
                guard let user = self.user else {
                    fatalError("User is not set.")
                }
                guard let list = self.list else {
                    // this should not happen once the favorite button is disabled after an error occurs
                    print("List is not set.")
                    return
                }
                let favorite = Favorite(ownerId: ownerId, user: user, list: list)
                self.favorite = realm.create(Favorite.self, value: favorite)
                
                firebase.logEvent("profile_save_favorite_\(user.screenName)")
            }
        }
    }
    
    func toggleFavoriteNavBarButton(sender: UIButton) {
        addOrDeleteFavoriteFromDB()
        let favoriteButtonImage = self.getFavoriteButtonUIImage()
        DispatchQueue.main.async {
            sender.setImage(favoriteButtonImage, for: .normal)
        }
        guard let profileCell = self.profileTableView.dequeueReusableCell(withIdentifier: "profileCell", for: IndexPath(row: 0, section: 0)) as? ProfileTableViewCell else {
            return
        }
        DispatchQueue.main.async {
            profileCell.favoriteButton.setImage(favoriteButtonImage, for: .normal)
        }
    }
    
    func toggleFavoriteProfileCellButton(sender: UIButton) {
        addOrDeleteFavoriteFromDB()
        let favoriteButtonImage = self.getFavoriteButtonUIImage()
        DispatchQueue.main.async {
            sender.setImage(favoriteButtonImage, for: .normal)
        }
        guard let favoriteNavBarButton = self.navigationItem.rightBarButtonItems?[1].customView as? UIButton else {
            return
        }
        DispatchQueue.main.async {
            favoriteNavBarButton.setImage(favoriteButtonImage, for: .normal)
        }
    }
    
    func getFavoriteButtonUIImage() -> UIImage {
        enum HeartFileNames: String {
            case on = "heart-filled.png"
            case off = "heart.png"
        }
        let heartFileName = self.favorite != nil ? HeartFileNames.on.rawValue : HeartFileNames.off.rawValue
        guard let image = UIImage(named: heartFileName) else {
            fatalError("heart image \(heartFileName) can't be found")
        }
        return image.withRenderingMode(.alwaysOriginal)
    }
    
    func loadTweetsFromList() {
        guard let user = self.user else {
            fatalError("User is not set.")
        }
        firebase.logEvent("profile_page_\(user.screenName)")
        
        let favorites: Results<Favorite> = {
            let realm = try! Realm()
            let ownerId = Twitter.sharedInstance().sessionStore.session()!.userID
            let predicate = NSPredicate(format: "ownerId = '\(ownerId)'")
            return realm.objects(Favorite.self).filter(predicate)
        }()
        self.favorite = favorites.filter { $0.user?.screenName == user.screenName }.first
        
        let favoriteButton = UIButton(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
        favoriteButton.setImage(getFavoriteButtonUIImage(), for: .normal)
        favoriteButton.addTarget(self, action: #selector(self.toggleFavoriteNavBarButton(sender:)), for: .touchUpInside)
        let negativeSpacer = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        negativeSpacer.width = -11;
        self.navigationItem.rightBarButtonItems = [negativeSpacer, UIBarButtonItem(customView: favoriteButton)]
        
        DispatchQueue.main.async {
            self.navigationItem.titleView = self.navigationTitleUILabel
            self.navigationTitleUILabel.text = user.name
            self.navigationTitleUILabel.font = UIFont(name: "HelveticaNeue-Bold", size: 17)
            self.navigationTitleUILabel.sizeToFit()
            self.navigationTitleUILabel.alpha = 0.0
            
            self.navigationItem.rightBarButtonItems?[1].customView?.alpha = 0.0
        }
        
        if self.list == nil {
            self.createAndPopulateList(user: user)
        } else {
            self.retrieveAndRenderListTweets()
        }
    }
    
    func createAndPopulateList(user: TWTRUserCustom) {
        let createListEndpoint = "https://api.twitter.com/1.1/lists/create.json"
        var listName = "\(Constants.listPrefix)\(user.screenName)"
        let listNameCharacterLimit = 25
        if listName.characters.count > listNameCharacterLimit {
            listName = listName.substring(to: listName.index(listName.startIndex, offsetBy: listNameCharacterLimit))
        }
        let params = [
            "name": listName,
            "description": "List generated by @TweetseeApp",
            "mode": "private"
        ]
        let request = self.client.urlRequest(withMethod: "POST", url: createListEndpoint, parameters: params, error: &self.clientError)
        
        self.client.sendTwitterRequest(request) { (_, data, connectionError) -> Void in
            guard let data = data else {
                print("Error: \(connectionError.debugDescription)")
                firebase.logEvent("twitter_error_lists_create")
                self.errorOccured()
                return
            }
            
            let jsonData = JSON(data: data)
            self.list = TWTRList(json: jsonData)
            // TODO: add this new list back to usersTELists
            
            let getFollowingIdsEndpoint = "https://api.twitter.com/1.1/friends/ids.json?screen_name=\(user.screenName)"
            let request = self.client.urlRequest(withMethod: "GET", url: getFollowingIdsEndpoint, parameters: nil, error: &self.clientError)
            
            self.client.sendTwitterRequest(request) { (_, data, connectionError) -> Void in
                guard let data = data else {
                    print("Error: \(connectionError.debugDescription)")
                    firebase.logEvent("twitter_error_friends_ids")
                    self.errorOccured()
                    return
                }
                
                let jsonData = JSON(data: data)
                let followingIdsList = (jsonData["ids"].arrayValue).map { String(describing: $0.intValue) }
                
                let addMembersToListEndpoint = "https://api.twitter.com/1.1/lists/members/create_all.json"
                // NOTE: this has a user_id list limit of 100 https://dev.twitter.com/rest/reference/post/lists/members/create_all
                let addMembersDispatchGroup = DispatchGroup()
                let maxMembersCount = 100
                let requestsCount = 1 // TEMPORARY: (followingIdsList.count / maxMembersCount) + 1
                for i in 0..<requestsCount {
                    addMembersDispatchGroup.enter()
                    let startIndex = maxMembersCount*i
                    let endIndex = min(maxMembersCount*(i+1), followingIdsList.count)
                    let params = [
                        "list_id": self.list!.idStr,
                        "user_id": followingIdsList[startIndex..<endIndex].joined(separator: ",")
                    ]
                    let request = self.client.urlRequest(withMethod: "POST", url: addMembersToListEndpoint, parameters: params, error: &self.clientError)
                    
                    self.client.sendTwitterRequest(request) { (_, data, connectionError) -> Void in
                        addMembersDispatchGroup.leave()
                        
                        guard let data = data else {
                            print("Error: \(connectionError.debugDescription)")
                            firebase.logEvent("twitter_error_lists_members_create_all")
                            self.errorOccured()
                            return
                        }
                        
                        let jsonData = JSON(data: data)
                        if jsonData["member_count"].int == 0 {
                            let errorMessage = "Error: response to lists/members/create_all.json returned successfully, but no members were added"
                            print(errorMessage)
                            firebase.logEvent("twitter_error_lists_no_members")
                            self.errorOccured()
                            return
                        }
                    }
                }
                
                addMembersDispatchGroup.notify(queue: .main) {
                    self.retrieveAndRenderListTweets()
                }
            }
        }
    }
    
    func retrieveAndRenderListTweets() {
        guard let list = self.list else {
            print("Error: no list exists.")
            return
        }
        let getListTweetsEndpoint = "https://api.twitter.com/1.1/lists/statuses.json?list_id=\(list.idStr)"
        var params = [
            "count": "50"
        ]
        if let oldestTweet = self.tweets.last {
            if let tweetID = Int(oldestTweet.tweetID) {
                params["max_id"] = String(describing: tweetID - 1)
            } else {
                params["max_id"] = oldestTweet.tweetID
            }
            // attempt to prompt store review when loading more tweets
            attemptPromptStoreReview()
        }
        let request = self.client.urlRequest(withMethod: "GET", url: getListTweetsEndpoint, parameters: params, error: &self.clientError)
        
        self.client.sendTwitterRequest(request) { (_, data, connectionError) -> Void in
            guard let data = data else {
                print("Error: \(connectionError.debugDescription)")
                firebase.logEvent("twitter_error_lists_statuses")
                self.errorOccured()
                return
            }
            
            let jsonData = JSON(data: data)
            self.tweets.append(contentsOf: TWTRTweet.tweets(withJSONArray: jsonData.arrayObject) as! [TWTRTweet])
            self.showSpinnerCell = false
            self.profileTableView.reloadData()
        }
    }
    
    func openUrlInModal(_ url: URL?) {
        if let url = url {
            if UIApplication.shared.canOpenURL(url) {
                let vc = SFSafariViewController(url: url, entersReaderIfAvailable: true)
                vc.modalPresentationStyle = .overFullScreen
                present(vc, animated: true, completion: nil)
            }
        }
    }
    
    func openTwitterProfile(sender: Any?) {
        guard let user = self.user else {
            fatalError("User is not set.")
        }
        
        firebase.logEvent("profile_image_or_name_click")
        let profileUrl = URL(string: "https://twitter.com/\(user.screenName)")
        self.openUrlInModal(profileUrl)
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == 0 && self.user != nil {
            guard let profileCell = tableView.dequeueReusableCell(withIdentifier: "profileCell", for: indexPath) as? ProfileTableViewCell else {
                fatalError("The dequeued cell is not an instance of ProfileTableViewCell.")
            }
            let user = self.user!

            profileCell.profileImageButton.setImage(fromUrl: user.profileImageOriginalSizeUrl, for: .normal)
            profileCell.profileImageButton.layer.cornerRadius = 5
            profileCell.profileImageButton.clipsToBounds = true
            profileCell.profileImageButton.addTarget(self, action: #selector(self.openTwitterProfile(sender:)), for: .touchUpInside)
            profileCell.nameButton.setTitle(user.name, for: .normal)
            profileCell.nameButton.addTarget(self, action: #selector(self.openTwitterProfile(sender:)), for: .touchUpInside)
            profileCell.screenNameLabel.text = "@\(user.screenName)"
            profileCell.isVerifiedImageView.isHidden = !user.isVerified
            profileCell.descriptionLabel.text = user.userDescription
            profileCell.whatNameSeesLabel.text = "What \(user.name) sees..."
            profileCell.followingLabel.text = abbreviateNumber(num: user.followingCount)
            if self.showSorryCell {
                profileCell.favoriteButton.isHidden = true
            } else {
                profileCell.favoriteButton.setImage(getFavoriteButtonUIImage(), for: .normal)
                profileCell.favoriteButton.addTarget(self, action: #selector(self.toggleFavoriteProfileCellButton(sender:)), for: .touchUpInside)
            }
            return profileCell
        } else if self.showSpinnerCell {
            let spinnerCell = tableView.dequeueReusableCell(withIdentifier: "spinnerCell", for: indexPath) as UITableViewCell
            spinnerCell.separatorInset = UIEdgeInsetsMake(0, 0, 0, tableView.bounds.width);
            return spinnerCell
        } else if self.showSorryCell {
            let sorryCell = tableView.dequeueReusableCell(withIdentifier: "sorryCell", for: indexPath) as UITableViewCell
            return sorryCell
        } else {
            guard let tweetCell = tableView.dequeueReusableCell(withIdentifier: "tweetCell", for: indexPath) as? TWTRTweetTableViewCell else {
                fatalError("The dequeued cell is not an instance of TWTRTweetTableViewCell.")
            }
            
            tweetCell.configure(with: self.tweets[indexPath.row - 1])
            tweetCell.tweetView.showActionButtons = true
            tweetCell.tweetView.showBorder = false
            tweetCell.tweetView.delegate = self
            return tweetCell
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if self.profileCellInView && !self.showSorryCell {
            let alpha = max(0, min(1, (self.profileTableView.contentOffset.y - 30) / 110))
            self.navigationTitleUILabel.alpha = alpha
            self.navigationItem.rightBarButtonItems?[1].customView?.alpha = alpha
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (self.user != nil ? 1 : 0) + tweets.count + (self.showSorryCell ? 1 : 0) + (self.showSpinnerCell ? 1 : 0)
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.row == 0 && self.user != nil {
            self.profileCellInView = true
        }
        if indexPath.row == self.tweets.count - 1 {
            firebase.logEvent("profile_load_more_tweets")
            self.retrieveAndRenderListTweets()
        }
    }
    
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.row == 0 && self.user != nil {
            self.profileCellInView = false
        }
    }
    
    func tweetView(_ tweetView: TWTRTweetView, didTap tweet: TWTRTweet) {
        firebase.logEvent("profile_tweet_click")
        self.openUrlInModal(tweet.permalink)
    }
    
    func tweetView(_ tweetView: TWTRTweetView, didTapProfileImageFor user: TWTRUser) {
        firebase.logEvent("profile_tweet_profile_image_click")
        let profileViewController = self.storyboard?.instantiateViewController(withIdentifier: "profileViewController") as! ProfileViewController
        profileViewController.userID = user.userID
        self.navigationController?.pushViewController(profileViewController, animated: true)
    }
    
    func tweetView(_ tweetView: TWTRTweetView, didTap url: URL) {
        firebase.logEvent("profile_tweet_url_click")
        self.openUrlInModal(url)
    }
}
