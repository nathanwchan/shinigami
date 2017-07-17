//
//  SearchViewController.swift
//  shinigami
//
//  Created by Nathan Chan on 5/30/17.
//  Copyright © 2017 Nathan Chan. All rights reserved.
//

import UIKit
import TwitterKit
import SwiftyJSON
import RealmSwift

class SearchViewController: UIViewController, Logoutable, UIScrollViewDelegate {

    @IBOutlet weak var searchTextField: UITextField!
    @IBOutlet weak var suggestionsForYouLabelHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var usersTableView: UITableView!
    @IBOutlet weak var usersTableScrollView: UIScrollView!
    @IBOutlet weak var searchActivityIndicator: UIActivityIndicatorView!
    
    private let searchTextPlaceholders = ["elon musk", "donald trump", "michelle obama", "katy perry", "lebron james"]
    
    fileprivate let client = TWTRAPIClient.withCurrentUser()
    fileprivate var clientError: NSError?
    private var followingUsers: [TWTRUserCustom] = []
    private var suggestedUsers: [TWTRUserCustom] = []
    private let maxSuggestedUsersCount = 100
    fileprivate var usersToShow: [TWTRUserCustom] = [] {
        didSet {
            DispatchQueue.main.async {
                self.searchActivityIndicator.stopAnimating()
                self.usersTableView.reloadData()
            }
        }
    }
    fileprivate var urlEncodedCurrentText = ""
    fileprivate var showingSuggestedUsers = false
    private var publicLists: [TWTRList] = []
    
    let cachedLists: Results<TWTRList> = {
        let realm = try! Realm()
        let ownerId = Twitter.sharedInstance().sessionStore.session()!.userID
        return realm.objects(TWTRList.self)
            .filter("ownerId = '\(ownerId)'")
            .sorted(byKeyPath: "createdAt", ascending: false)
    }()
    var notificationToken: NotificationToken?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if globals.launchCount == 1 {
            searchTextField.becomeFirstResponder()
        }
        searchTextField.placeholder = searchTextPlaceholders[Int(arc4random()) % searchTextPlaceholders.count]
        suggestionsForYouLabelHeightConstraint.constant = 0
        
        searchTextField.delegate = self
        usersTableView.dataSource = self
        usersTableScrollView.delegate = self
        usersTableScrollView.keyboardDismissMode = .onDrag
        
        usersTableView.tableFooterView = UIView(frame: CGRect.zero)
        // dynamic cell height based on inner content
        usersTableView.rowHeight = UITableViewAutomaticDimension
        usersTableView.estimatedRowHeight = 70

        let logoutButton = UIButton(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
        logoutButton.setImage(UIImage(named: "exit.png"), for: .normal)
        logoutButton.addTarget(self, action: #selector(clickedLogoutButton(sender:)), for: .touchUpInside)
        let negativeSpacer = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        negativeSpacer.width = -8
        navigationItem.rightBarButtonItems = [negativeSpacer, UIBarButtonItem(customView: logoutButton)]
        
        // Observe Results Notifications
        notificationToken = cachedLists.addNotificationBlock { (_: RealmCollectionChange) in }

        // Retrieve updated lists from Twitter
        let getListsEndpoint = "https://api.twitter.com/1.1/lists/ownerships.json?count=1000"
        let request = client.urlRequest(withMethod: "GET", url: getListsEndpoint, parameters: nil, error: &clientError)
        client.sendTwitterRequest(request) { (_, data, connectionError) -> Void in
            guard let data = data else {
                print("Error: \(connectionError.debugDescription)")
                if connectionError!._code == 89 {
                    // invalid or expired token
                    firebase.logEvent("twitter_error_invalid_or_expired_token")
                    self.logout()
                } else {
                    firebase.logEvent("twitter_error_lists_ownerships")
                }
                return
            }
            let jsonData = JSON(data: data)
            var usersTELists = jsonData["lists"].arrayValue
                .map { TWTRList(json: $0, user: nil)! }
                .filter { $0.name.hasPrefix(Constants.listPrefix) && $0.memberCount > 0 }
            usersTELists = Array(usersTELists[0..<min(20, usersTELists.count)])
                
            if usersTELists.isEmpty {
                // User doesn't have existing TE lists
                self.retrieveAndShowSuggestedUsers()
            } else {
                let getUsersEndpoint = "https://api.twitter.com/1.1/users/lookup.json"
                let usersFromTELists = usersTELists.map { String($0.name.characters.dropFirst(Constants.listPrefix.characters.count)) } // drop prefix from list name to get username
                let params = [
                    "screen_name": usersFromTELists.joined(separator: ",")
                ]
                let request = self.client.urlRequest(withMethod: "GET", url: getUsersEndpoint, parameters: params, error: &self.clientError)
                self.client.sendTwitterRequest(request) { (_, data, connectionError) -> Void in
                    guard let data = data else {
                        print("Error: \(connectionError.debugDescription)")
                        firebase.logEvent("twitter_error_users_lookup")
                        return
                    }
                    let jsonData = JSON(data: data)
                    let usersTEListsUsers = jsonData.arrayValue.map { TWTRUserCustom(json: $0)! }
                    
                    var userTEListsToCache: [TWTRList] = []
                    for userTEList in usersTELists {
                        let userScreenName = String(userTEList.name.characters.dropFirst(Constants.listPrefix.characters.count))
                        if let user = usersTEListsUsers.filter({ $0.screenName == userScreenName }).first {
                            userTEList.user = user
                            userTEListsToCache.append(userTEList)
                        }
                    }
                    
                    let realm = try! Realm()
                    try! realm.write {
                        for userTEListToCache in userTEListsToCache {
                            realm.create(TWTRList.self, value: userTEListToCache, update: true)
                        }
                    }
                    
                    self.retrieveAndShowSuggestedUsers()
                }
            }
        }
    }
    
    func showSuggestedUsers() {
        // dedup suggested users
        var duplicateUserIds = Set<String>()
        let dedupedSuggestedUsers = suggestedUsers.flatMap { (user) -> TWTRUserCustom? in
            guard !duplicateUserIds.contains(user.idStr) else { return nil }
            duplicateUserIds.insert(user.idStr)
            return user
        }
        suggestedUsers = Array(dedupedSuggestedUsers[0..<min(dedupedSuggestedUsers.count, maxSuggestedUsersCount)])
        
        usersToShow = suggestedUsers
        showingSuggestedUsers = true
        suggestionsForYouLabelHeightConstraint.constant = 15
    }
    
    func retrieveAndShowSuggestedUsers() {
        if followingUsers.isEmpty {
            let usersFollowingEndpoint = "https://api.twitter.com/1.1/friends/list.json?count=200"
            let request = client.urlRequest(withMethod: "GET", url: usersFollowingEndpoint, parameters: nil, error: &clientError)
            
            client.sendTwitterRequest(request) { (_, data, connectionError) -> Void in
                guard let data = data else {
                    print("Error: \(connectionError.debugDescription)")
                    firebase.logEvent("twitter_error_friends_list")
                    return
                }
                let jsonData = JSON(data: data)
                var followingTWTRUsers = jsonData["users"].arrayValue.map { TWTRUserCustom(json: $0)! }
                
                let publicListsEndpoint = "https://api.twitter.com/1.1/lists/list.json?screen_name=\(Constants.publicListsTwitterAccount)"
                let request = self.client.urlRequest(withMethod: "GET", url: publicListsEndpoint, parameters: nil, error: &self.clientError)
                
                self.client.sendTwitterRequest(request) { (_, data, connectionError) -> Void in
                    guard let data = data else {
                        print("Error: \(connectionError.debugDescription)")
                        firebase.logEvent("twitter_error_lists_list")
                        return
                    }
                    let jsonData = JSON(data: data)
                    self.publicLists = jsonData.arrayValue
                        .map { TWTRList(json: $0, user: nil)! }
                        .filter { $0.name.hasPrefix(Constants.listPrefix) && $0.memberCount > 0 }
                    
                    let getUsersEndpoint = "https://api.twitter.com/1.1/users/lookup.json"
                    let usersFromPublicLists = self.publicLists.map { String($0.name.characters.dropFirst(Constants.listPrefix.characters.count)) } // drop prefix from list name to get username
                    let params = [
                        "screen_name": usersFromPublicLists.joined(separator: ",")
                    ]
                    let request = self.client.urlRequest(withMethod: "GET", url: getUsersEndpoint, parameters: params, error: &self.clientError)
                    self.client.sendTwitterRequest(request) { (_, data, _) -> Void in
                        var publicListsUsers: [TWTRUserCustom] = []
                        if let data = data {
                            let jsonData = JSON(data: data)
                            publicListsUsers = jsonData.arrayValue.map { TWTRUserCustom(json: $0)! }
                            
                            let realm = try! Realm()
                            let favorites = realm.objects(Favorite.self)
                            
                            var publicListsWithUsersToCache: [TWTRList] = []
                            
                            func queueUpForStorage(_ publicList: TWTRList) {
                                let userScreenName = String(publicList.name.characters.dropFirst(Constants.listPrefix.characters.count))
                                if let user = publicListsUsers.filter({ $0.screenName == userScreenName }).first {
                                    publicList.user = user
                                    publicList.ownerId = "0"
                                    publicListsWithUsersToCache.append(publicList)
                                }
                            }
                            
                            for publicList in self.publicLists {
                                // make sure it's not an existing favorite
                                if favorites.filter({ $0.list?.name == publicList.name }).first == nil {
                                    if let existingList = self.cachedLists.filter({ $0.name == publicList.name && $0.idStr != publicList.idStr }).first {
                                        // user has already visited this user (stored in DB), but it is not a public list (maybe this is a newly created public list)
                                        if let existingRealmList = realm.object(ofType: TWTRList.self, forPrimaryKey: existingList.idStr) {
                                            try! realm.write {
                                                realm.delete(existingRealmList)
                                            }
                                        }
                                        queueUpForStorage(publicList)
                                    } else if self.cachedLists.filter({ $0.name == publicList.name }).isEmpty {
                                        // user has never visited this user and it is public list
                                        queueUpForStorage(publicList)
                                    }
                                }
                            }
                            self.publicLists = publicListsWithUsersToCache
                            
                            try! realm.write {
                                for publicList in self.publicLists {
                                    realm.create(TWTRList.self, value: publicList, update: true)
                                }
                            }
                        }
                        
                        // sort to move groups of users with less following users to the top
                        var idealFollowingTWTRUsers = followingTWTRUsers.filter { $0.followingCount >= 10 && $0.followingCount < 200 } + publicListsUsers
                        idealFollowingTWTRUsers.shuffle()
                        followingTWTRUsers = idealFollowingTWTRUsers +
                            followingTWTRUsers.filter { $0.followingCount >= 200 && $0.followingCount < 500 } +
                            followingTWTRUsers.filter { $0.followingCount >= 500 }
                        self.followingUsers = followingTWTRUsers
                        
                        self.suggestedUsers = self.cachedLists
                            .filter { $0.user != nil && $0.memberCount > 0}
                            .map { $0.user! }
                            + followingTWTRUsers
                        self.showSuggestedUsers()
                    }
                }
            }
        } else {
            suggestedUsers = cachedLists
                .filter { $0.user != nil && $0.memberCount > 0}
                .map { $0.user! }
                + followingUsers
            showSuggestedUsers()
        }
    }
    
    func clickedLogoutButton(sender: Any?) {
        let alertController = UIAlertController(title: "Logout?", message: "Are you sure you want to logout of your Twitter account?", preferredStyle: .alert)
        let logoutAction = UIAlertAction(title: "Yes", style: .default) { (_: UIAlertAction) -> Void in
            self.logout()
        }
        let cancelAction = UIAlertAction(title: "No", style: .cancel) { (_: UIAlertAction) -> Void in }
        alertController.addAction(cancelAction)
        alertController.addAction(logoutAction)
        present(alertController, animated: true, completion: nil)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        super.prepare(for: segue, sender: sender)
        
        switch(segue.identifier ?? "") {
            case "ShowProfileSegue":
                guard let profileViewController = segue.destination as? ProfileViewController else {
                    fatalError("Unexpected destination: \(segue.destination)")
                }
                
                guard let selectedUserCell = sender as? UserTableViewCell else {
                    fatalError("Unexpected sender: \(sender.debugDescription)")
                }
                
                guard let indexPath = usersTableView.indexPath(for: selectedUserCell) else {
                    fatalError("The selected cell is not being displayed by the table")
                }
                    
                profileViewController.user = usersToShow[indexPath.row]
                let listName = "\(Constants.listPrefix)\(profileViewController.user!.screenName)"
                
                var listInDB = cachedLists.filter { $0.name == listName }.first
                if listInDB == nil {
                    if let publicList = publicLists.filter({ $0.name == listName }).first {
                        publicList.user = profileViewController.user
                        if let ownerId = Twitter.sharedInstance().sessionStore.session()?.userID {
                            publicList.ownerId = ownerId
                        }
                        let realm = try! Realm()
                        try! realm.write {
                            realm.create(TWTRList.self, value: publicList, update: true)
                        }
                        listInDB = publicList
                    }
                }
                
                profileViewController.list = listInDB
                
                if showingSuggestedUsers {
                    firebase.logEvent("search_click_suggested_index_\(indexPath.row)")
                }
            case "LogoutSegue":
                break
            default:
                fatalError("Unexpected Segue Identifier; \(segue.identifier ?? "unknown")")
        }
    }
}

extension SearchViewController: UITextFieldDelegate {
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let currentText = (textField.text as NSString?)?.replacingCharacters(in: range, with: string)
        urlEncodedCurrentText = (currentText?.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed))!
        if urlEncodedCurrentText.isEmpty {
            retrieveAndShowSuggestedUsers()
        } else {
            let usersSearchEndpoint = "https://api.twitter.com/1.1/users/search.json?q=\(urlEncodedCurrentText)"
            let request = client.urlRequest(withMethod: "GET", url: usersSearchEndpoint, parameters: nil, error: &clientError)
            
            client.sendTwitterRequest(request) { (response, data, connectionError) -> Void in
                guard let data = data else {
                    print("Error: \(connectionError.debugDescription)")
                    firebase.logEvent("twitter_error_users_search")
                    return
                }
                guard let url = response?.url,
                    let queryItem = URLComponents(string: url.absoluteString)?.queryItems?.filter({$0.name == "q"}).first
                    else {
                        print("Error in response")
                        return
                }
                
                // to prevent race condition, ensure only current text's results are displayed
                if self.urlEncodedCurrentText == (queryItem.value?.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed))! {
                    let jsonData = JSON(data: data)
                    let searchResultsUsers = jsonData.arrayValue.map { TWTRUserCustom.init(json: $0)! }
                    if !searchResultsUsers.isEmpty {
                        self.usersToShow = searchResultsUsers
                        self.showingSuggestedUsers = false
                        self.suggestionsForYouLabelHeightConstraint.constant = 0
                    }
                }
            }
        }
        scrollToFirstRow()
        return true
    }
    
    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        retrieveAndShowSuggestedUsers()
        scrollToFirstRow()
        return true
    }
    
    func scrollToFirstRow() {
        if !usersToShow.isEmpty {
            let indexPath = IndexPath(row: 0, section: 0)
            usersTableView.scrollToRow(at: indexPath, at: .top, animated: true)
        }
    }
}

extension SearchViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let userCell = tableView.dequeueReusableCell(withIdentifier: "userCell", for: indexPath) as? UserTableViewCell else {
            fatalError("The dequeued cell is not an instance of UserTableViewCell.")
        }
        let user = usersToShow[indexPath.row]
        userCell.configureWith(user)
        return userCell
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return usersToShow.count
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAtIndexPath indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
}
