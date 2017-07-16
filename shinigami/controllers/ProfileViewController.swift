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

class ProfileViewController: UIViewController {
    
    var userID: String? // used only when coming from clicking on tweet's profile pic
    var list: TWTRList?
    var user: TWTRUserCustom?
    var favorite: Favorite?
    private let client = TWTRAPIClient.withCurrentUser()
    private var clientError: NSError?
    internal var showSpinnerCell = true
    internal var showSorryCell = false
    internal var tweets: [TWTRTweet] = [] {
        didSet {
            DispatchQueue.main.async {
                self.showSpinnerCell = false
                self.profileTableView.reloadData()
            }
        }
    }
    internal var usersToShowWhenErrorOccurs: [TWTRUserCustom] = [] {
        didSet {
            DispatchQueue.main.async {
                self.profileTableView.reloadData()
            }
        }
    }
    private func errorOccurred(deleteList: Bool = false) {
        if self.showSorryCell {
            // acting as a lock to prevent multiple calls here to update UI
            return
        }
        self.showSpinnerCell = false
        self.showSorryCell = true
        
        let realm = try! Realm()
        let ownerId = Twitter.sharedInstance().sessionStore.session()!.userID
        let existingListsUsers = Array(realm.objects(TWTRList.self)
            .filter("(ownerId = '\(ownerId)' OR ownerId = '0') AND idStr != '\(self.list?.idStr ?? "unknown")'")
            .map { $0.user! })
        
        var existingListsUsersHiPri = existingListsUsers.filter {$0.followingCount < 500}
        existingListsUsersHiPri.shuffle()
        var existingListsUsersLowPri = existingListsUsers.filter {$0.followingCount >= 500}
        existingListsUsersLowPri.shuffle()
        
        var duplicateUserIds = Set<String>()
        self.usersToShowWhenErrorOccurs = (existingListsUsersHiPri + existingListsUsersLowPri)
            .flatMap { (user) -> TWTRUserCustom? in
                guard !duplicateUserIds.contains(user.idStr) else { return nil }
                duplicateUserIds.insert(user.idStr)
                return user
            }
        
        if deleteList {
            // Delete list from Realm DB and Twitter
            if let listID = self.list?.idStr {
                if let realmList = realm.object(ofType: TWTRList.self, forPrimaryKey: listID) {
                    try! realm.write() {
                        realm.delete(realmList)
                        self.list = nil
                    }
                }
                let deleteListEndpoint = "https://api.twitter.com/1.1/lists/destroy.json?list_id=\(listID)"
                let request = self.client.urlRequest(withMethod: "POST", url: deleteListEndpoint, parameters: nil, error: &self.clientError)
                
                self.client.sendTwitterRequest(request) { (_, data, connectionError) -> Void in
                    if data == nil {
                        print("Error: \(connectionError.debugDescription)")
                        firebase.logEvent("twitter_error_lists_destroy")
                        return
                    }
                    self.list = nil
                }
            }
        }
    }
    var navigationTitleUILabel = UILabel()
    var profileCellInView = true
    
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
        
        if let list = self.list {
            self.user = list.user
            loadTweetsFromList()
        } else if self.user != nil {
            loadTweetsFromList()
        } else {
            guard let userID = self.userID else {
                fatalError("List, User and UserID are not set.")
            }
            let getUserEndpoint = "https://api.twitter.com/1.1/users/show.json?user_id=\(userID)"
            let request = self.client.urlRequest(withMethod: "GET", url: getUserEndpoint, parameters: nil, error: &self.clientError)
            
            self.client.sendTwitterRequest(request) { (_, data, connectionError) -> Void in
                guard let data = data else {
                    print("Error: \(connectionError.debugDescription)")
                    firebase.logEvent("twitter_error_users_show")
                    self.errorOccurred()
                    return
                }
                
                let jsonData = JSON(data: data)
                self.user = TWTRUserCustom(json: jsonData)
                
                self.loadTweetsFromList()
            }
        }
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.setNavigationBarItemsAlpha(hide: self.showSorryCell)
    }
    
    func addOrDeleteFavoriteFromDB() {
        let realm = try! Realm()
        try! realm.write() {
            if let favorite = self.favorite {
                realm.delete(favorite)
                self.favorite = nil
                
                firebase.logEvent("profile_delete_favorite_\(self.user?.screenName ?? "unknown")")
            } else {
                guard let list = self.list else {
                    // this should not happen once the favorite button is disabled after an error occurs
                    print("List is not set.")
                    return
                }
                guard let realmList = realm.object(ofType: TWTRList.self, forPrimaryKey: list.idStr) else {
                    // TODO: retrieve if for some reason not in DB
                    return
                }
                if let favorite = Favorite(list: realmList) {
                    self.favorite = realm.create(Favorite.self, value: favorite)
                    firebase.logEvent("profile_save_favorite_\(list.user?.screenName ?? "unknown")")
                }
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
        
        let realm = try! Realm()
        let ownerId = Twitter.sharedInstance().sessionStore.session()!.userID
        
        self.favorite = realm.objects(Favorite.self)
            .filter("ownerId = '\(ownerId)' AND list.user.screenName = '\(user.screenName)'").first
        
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
        
        let existingListName = Constants.listPrefix + user.screenName
        
        self.list = realm.objects(TWTRList.self)
            .filter("(ownerId = '\(ownerId)' OR ownerId = '0') AND name = '\(existingListName)'")
            .sorted(byKeyPath: "createdAt", ascending: false).first
        
        if let list = self.list {
            if list.ownerId == "0" {
                try! realm.write() {
                    list.ownerId = ownerId
                    list.createdAt = Date()
                    realm.create(TWTRList.self, value: list, update: true)
                }
                self.list = list
            }
            self.retrieveAndRenderListTweets()
        } else {
            self.createAndPopulateList(for: user)
        }
    }

    func createAndPopulateList(for user: TWTRUserCustom) {
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
                self.errorOccurred()
                return
            }
            
            let jsonData = JSON(data: data)
            self.list = TWTRList(json: jsonData, user: user)

            self.populateList(for: user, with: self.retrieveAndRenderListTweets)
        }
    }
    
    func populateList(for user: TWTRUserCustom, forceAll: Bool = false, with callback: @escaping () -> ()) {
        guard let list = self.list else {
            return
        }
        
        let getFollowingIdsEndpoint = "https://api.twitter.com/1.1/friends/ids.json?screen_name=\(user.screenName)"
        let request = self.client.urlRequest(withMethod: "GET", url: getFollowingIdsEndpoint, parameters: nil, error: &self.clientError)
        
        self.client.sendTwitterRequest(request) { (_, data, connectionError) -> Void in
            guard let data = data else {
                print("Error: \(connectionError.debugDescription)")
                firebase.logEvent("twitter_error_friends_ids")
                self.errorOccurred()
                return
            }
            
            let jsonData = JSON(data: data)
            let followingIdsList = (jsonData["ids"].arrayValue).map { String(describing: $0.intValue) }
            
            let addMembersToListEndpoint = "https://api.twitter.com/1.1/lists/members/create_all.json"
            // NOTE: this has a user_id list limit of 100 https://dev.twitter.com/rest/reference/post/lists/members/create_all
            let addMembersDispatchGroup = DispatchGroup()
            let maxMembersCount = 100
            let requestsCount = min(15, (followingIdsList.count / maxMembersCount) + 1)
            for i in 0..<requestsCount {
                addMembersDispatchGroup.enter()
                let startIndex = maxMembersCount*i
                let endIndex = min(maxMembersCount*(i+1), followingIdsList.count)
                let params = [
                    "list_id": list.idStr,
                    "user_id": followingIdsList[startIndex..<endIndex].joined(separator: ",")
                ]
                let request = self.client.urlRequest(withMethod: "POST", url: addMembersToListEndpoint, parameters: params, error: &self.clientError)
                
                self.client.sendTwitterRequest(request) { (_, data, connectionError) -> Void in
                    addMembersDispatchGroup.leave()
                    
                    guard let data = data else {
                        print("Error: \(connectionError.debugDescription)")
                        firebase.logEvent("twitter_error_lists_members_create_all")
                        self.errorOccurred()
                        return
                    }
                    
                    let jsonData = JSON(data: data)
                    self.list = TWTRList(json: jsonData, user: user)
                    if jsonData["member_count"].int == 0 {
                        let errorMessage = "Error: response to lists/members/create_all.json returned successfully, but no members were added"
                        print(errorMessage)
                        firebase.logEvent("twitter_error_lists_no_members")
                        self.errorOccurred(deleteList: true)
                        return
                    }
                    
                    let realm = try! Realm()
                    try! realm.write() {
                        realm.create(TWTRList.self, value: self.list!, update: true)
                    }
                }
            }
            
            addMembersDispatchGroup.notify(queue: .main) {
                callback()
            }
        }
    }
    
    func retrieveAndRenderListTweets() {
        guard let list = self.list else {
            print("Error: no list exists.")
            return
        }
        if list.memberCount == 0 {
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
                self.errorOccurred()
                return
            }
            
            let jsonData = JSON(data: data)
            self.tweets.append(contentsOf: TWTRTweet.tweets(withJSONArray: jsonData.arrayObject) as! [TWTRTweet])
        }
    }
    
    func openUrlInModal(_ url: URL?) {
        if let url = url {
            if UIApplication.shared.canOpenURL(url) {
                let vc = SFSafariViewController(url: url, entersReaderIfAvailable: false)
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
    
    func forcePopulateListSecretCallback() {
        if let list = self.list {
            let alertController = UIAlertController(title: "Done!", message: "This list now has \(list.memberCount) members.", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "Cool", style: .default) { (result : UIAlertAction) -> Void in }
            alertController.addAction(okAction)
            present(alertController, animated: true, completion: nil)
        }
    }
    
    func openSecretMenu(sender: Any?) {
        if let list = list {
            if list.uri.contains("Tw1tterEyes") {
                // can't touch this.
                return
            }
            let ownerId = Twitter.sharedInstance().sessionStore.session()!.userID
            firebase.logEvent("secret_menu_opened_\(ownerId)")
            let alertController = UIAlertController(title: "Hi there!", message: "This list currently has \(list.memberCount) members.\nWould you like to force populate the list?", preferredStyle: .alert)
            let okAction = UIAlertAction(title: "Do it", style: .default) { (result : UIAlertAction) -> Void in
                if let user = list.user {
                    self.populateList(for: user, forceAll: true, with: self.forcePopulateListSecretCallback)
                }
            }
            let cancelAction = UIAlertAction(title: "What is this?", style: .destructive) { (result : UIAlertAction) -> Void in }
            alertController.addAction(okAction)
            alertController.addAction(cancelAction)
            present(alertController, animated: true, completion: nil)
        }
    }
    
    func setNavigationBarItemsAlpha(hide: Bool = false) {
        if hide {
            DispatchQueue.main.async {
                self.navigationTitleUILabel.alpha = 0.0
                self.navigationItem.rightBarButtonItems?[1].customView?.alpha = 0.0
            }
        } else if profileCellInView && !showSorryCell {
            let alpha = max(0, min(1, (profileTableView.contentOffset.y - 30) / 110))
            DispatchQueue.main.async {
                self.navigationTitleUILabel.alpha = alpha
                self.navigationItem.rightBarButtonItems?[1].customView?.alpha = alpha
            }
        }
    }
}

extension ProfileViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == 0 && self.user != nil {
            guard let profileCell = tableView.dequeueReusableCell(withIdentifier: "profileCell", for: indexPath) as? ProfileTableViewCell else {
                fatalError("The dequeued cell is not an instance of ProfileTableViewCell.")
            }
            let user = self.user!
            
            profileCell.profileImageButton.setImage(fromUrl: user.profileImageOriginalSizeUrl, for: .normal)
            profileCell.profileImageButton.layer.cornerRadius = 5
            profileCell.profileImageButton.clipsToBounds = true
            profileCell.profileImageButton.imageView?.contentMode = .scaleAspectFill
            profileCell.profileImageButton.addTarget(self, action: #selector(openTwitterProfile(sender:)), for: .touchUpInside)
            profileCell.nameButton.setTitle(user.name, for: .normal)
            profileCell.nameButton.addTarget(self, action: #selector(openTwitterProfile(sender:)), for: .touchUpInside)
            profileCell.screenNameLabel.text = "@\(user.screenName)"
            profileCell.isVerifiedImageView.isHidden = !user.isVerified
            profileCell.descriptionLabel.text = user.userDescription
            profileCell.whatNameSeesLabel.text = "What \(user.name) sees..."
            profileCell.followingLabel.text = abbreviateNumber(num: user.followingCount)
            if showSorryCell {
                profileCell.favoriteButton.isHidden = true
            } else {
                profileCell.favoriteButton.setImage(getFavoriteButtonUIImage(), for: .normal)
                profileCell.favoriteButton.addTarget(self, action: #selector(toggleFavoriteProfileCellButton(sender:)), for: .touchUpInside)
            }
            
            let longPressGestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(openSecretMenu(sender:)))
            profileCell.secretButton.addGestureRecognizer(longPressGestureRecognizer)
            
            return profileCell
        } else if showSpinnerCell {
            let spinnerCell = tableView.dequeueReusableCell(withIdentifier: "spinnerCell", for: indexPath) as UITableViewCell
            spinnerCell.separatorInset = UIEdgeInsetsMake(0, 0, 0, tableView.bounds.width);
            return spinnerCell
        } else if showSorryCell {
            if (self.user == nil && indexPath.row == 0) || (self.user != nil && indexPath.row == 1) {
                let sorryCell = tableView.dequeueReusableCell(withIdentifier: "sorryCell", for: indexPath) as UITableViewCell
                return sorryCell
            }
            guard let userCell = tableView.dequeueReusableCell(withIdentifier: "userCell", for: indexPath) as? UserTableViewCell else {
                fatalError("The dequeued cell is not an instance of UserTableViewCell.")
            }
            let userIndex = indexPath.row - (self.user == nil ? 1 : 2)
            let user = usersToShowWhenErrorOccurs[userIndex]
            userCell.configureWith(user)
            return userCell
            
        } else {
            guard let tweetCell = tableView.dequeueReusableCell(withIdentifier: "tweetCell", for: indexPath) as? TWTRTweetTableViewCell else {
                fatalError("The dequeued cell is not an instance of TWTRTweetTableViewCell.")
            }
            
            tweetCell.configure(with: tweets[indexPath.row - 1])
            tweetCell.tweetView.showBorder = false
            tweetCell.tweetView.delegate = self
            return tweetCell
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (user != nil ? 1 : 0) + tweets.count + (showSorryCell ? 1 : 0) + (showSpinnerCell ? 1 : 0) + usersToShowWhenErrorOccurs.count
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.row == 0 && user != nil {
            profileCellInView = true
        }
        if indexPath.row == tweets.count - 1 {
            firebase.logEvent("profile_load_more_tweets")
            retrieveAndRenderListTweets()
        }
    }
    
    func tableView(_ tableView: UITableView, didEndDisplaying cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.row == 0 && user != nil {
            profileCellInView = false
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let userCell = tableView.cellForRow(at: indexPath) else {
            return
        }
        if userCell.isKind(of: UserTableViewCell.self) {
            
            let userIndex = indexPath.row - (user == nil ? 1 : 2)
            firebase.logEvent("profile_click_user_when_error_index_\(userIndex)")
            
            let profileViewController = storyboard?.instantiateViewController(withIdentifier: "profileViewController") as! ProfileViewController
            profileViewController.user = usersToShowWhenErrorOccurs[userIndex]
            
            navigationController?.pushViewController(profileViewController, animated: true)
        }
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        setNavigationBarItemsAlpha()
    }
}

extension ProfileViewController: TWTRTweetViewDelegate {
    func tweetView(_ tweetView: TWTRTweetView, didTap tweet: TWTRTweet) {
        firebase.logEvent("profile_tweet_click")
        openUrlInModal(tweet.permalink)
    }
    
    func tweetView(_ tweetView: TWTRTweetView, didTapProfileImageFor user: TWTRUser) {
        firebase.logEvent("profile_tweet_profile_image_click")
        let profileViewController = storyboard?.instantiateViewController(withIdentifier: "profileViewController") as! ProfileViewController
        profileViewController.userID = user.userID
        navigationController?.pushViewController(profileViewController, animated: true)
    }
    
    func tweetView(_ tweetView: TWTRTweetView, didTap url: URL) {
        firebase.logEvent("profile_tweet_url_click")
        openUrlInModal(url)
    }
}
