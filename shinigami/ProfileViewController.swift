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

class ProfileViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, TWTRTweetViewDelegate {
    
    var user: TWTRUserCustom?
    var list: TWTRList?
    private let client = TWTRAPIClient.withCurrentUser()
    private var clientError: NSError?
    private var tweets: [TWTRTweet] = []
    private var showSorryCell: Bool = false
    private func errorOccured() {
        self.showSorryCell = true
        self.profileTableView.reloadData()
    }
    
    @IBOutlet weak var profileTableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        GA().logScreen(name: "profile")
        
        self.profileTableView.dataSource = self
        self.profileTableView.delegate = self
        
        // dynamic cell height based on inner content
        self.profileTableView.rowHeight = UITableViewAutomaticDimension
        self.profileTableView.estimatedRowHeight = 120
        // remove separator lines between empty rows
        self.profileTableView.tableFooterView = UIView(frame: CGRect.zero)
        
        guard let user = self.user else {
            fatalError("User is not set.")
        }
        
        if self.list == nil {
        
            let createListEndpoint = "https://api.twitter.com/1.1/lists/create.json"
            var listName = "\(Constants.listPrefix)\(user.screenName)"
            let listNameCharacterLimit = 25
            if listName.characters.count > listNameCharacterLimit {
                listName = listName.substring(to: listName.index(listName.startIndex, offsetBy: listNameCharacterLimit))
            }
            let params = [
                "name": listName,
                "description": "List generated by Twitter Eyes",
                "mode": "private"
            ]
            let request = self.client.urlRequest(withMethod: "POST", url: createListEndpoint, parameters: params, error: &self.clientError)
            
            self.client.sendTwitterRequest(request) { (_, data, connectionError) -> Void in
                guard let data = data else {
                    print("Error: \(connectionError.debugDescription)")
                    GA().logAction(category: "twitter-error", action: "lists-create", label: connectionError.debugDescription)
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
                        GA().logAction(category: "twitter-error", action: "friends-ids", label: connectionError.debugDescription)
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
                            guard let data = data else {
                                print("Error: \(connectionError.debugDescription)")
                                GA().logAction(category: "twitter-error", action: "lists-members-create-all", label: connectionError.debugDescription)
                                self.errorOccured()
                                return
                            }
                            
                            let jsonData = JSON(data: data)
                            if jsonData["member_count"].int == 0 {
                                let errorMessage = "Error: response to lists/members/create_all.json returned successfully, but no members were added"
                                print(errorMessage)
                                GA().logAction(category: "twitter-error", action: "lists-no-members", label: errorMessage)
                                self.errorOccured()
                                return
                            }
                            
                            addMembersDispatchGroup.leave()
                        }
                    }
                    
                    addMembersDispatchGroup.notify(queue: .main) {
                        self.loadListTweets()
                    }
                }
            }
        } else {
            self.loadListTweets()
        }
    }
    
    func loadListTweets() {
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
        }
        let request = self.client.urlRequest(withMethod: "GET", url: getListTweetsEndpoint, parameters: params, error: &self.clientError)
        
        self.client.sendTwitterRequest(request) { (_, data, connectionError) -> Void in
            guard let data = data else {
                print("Error: \(connectionError.debugDescription)")
                GA().logAction(category: "twitter-error", action: "lists-statuses", label: connectionError.debugDescription)
                self.errorOccured()
                return
            }
            
            let jsonData = JSON(data: data)
            self.tweets.append(contentsOf: TWTRTweet.tweets(withJSONArray: jsonData.arrayObject) as! [TWTRTweet])
            self.profileTableView.reloadData()
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row == 0 {
            guard let profileCell = tableView.dequeueReusableCell(withIdentifier: "profileCell", for: indexPath) as? ProfileTableViewCell else {
                fatalError("The dequeued cell is not an instance of ProfileTableViewCell.")
            }
            guard let user = self.user else {
                fatalError("User is not set.")
            }
            
            profileCell.profileImageView.image(fromUrl: user.profileImageOriginalSizeUrl)
            profileCell.profileImageView.layer.cornerRadius = 5
            profileCell.profileImageView.clipsToBounds = true
            profileCell.nameLabel.text = user.name
            profileCell.screenNameLabel.text = "@\(user.screenName)"
            profileCell.isVerifiedImageView.isHidden = !user.isVerified
            profileCell.descriptionLabel.text = user.description
            profileCell.whatNameSeesLabel.text = "What \(user.name) sees..."
            profileCell.followingLabel.text = abbreviateNumber(num: user.followingCount)
            return profileCell
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
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tweets.count + 1 + (self.showSorryCell ? 1 : 0)
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if indexPath.row == self.tweets.count - 1 {
            GA().logAction(category: "profile", action: "load-more-tweets", label: self.user!.screenName)
            loadListTweets()
        }
    }
    
    func tweetView(_ tweetView: TWTRTweetView, didTap tweet: TWTRTweet) {
        GA().logAction(category: "profile", action: "tweet-click", label: "\(self.user!.screenName),\(tweet.author.screenName)")
        UIApplication.shared.open(tweet.permalink)
    }
    
    func tweetView(_ tweetView: TWTRTweetView, didTapProfileImageFor user: TWTRUser) {
        GA().logAction(category: "profile", action: "tweet-profile-image-click", label: "\(self.user!.screenName),\(user.screenName)")
        UIApplication.shared.open(user.profileURL)
    }
    
    /*func tweetView(_ tweetView: TWTRTweetView, didTap url: URL) {
        let webViewController = UIViewController()
        let webView = UIWebView(frame: webViewController.view.bounds)
        webView.loadRequest(URLRequest(url: url))
        webViewController.view = webView
        self.navigationController!.pushViewController(webViewController, animated: true)
    }*/
}
