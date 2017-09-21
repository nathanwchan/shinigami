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
import PromiseKit

class SearchViewController: UIViewController, Logoutable, UIScrollViewDelegate {

    @IBOutlet weak var searchTextField: UITextField!
    @IBOutlet weak var suggestionsForYouLabelHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var usersTableView: UITableView!
    @IBOutlet weak var usersTableScrollView: UIScrollView!
    @IBOutlet weak var searchActivityIndicator: UIActivityIndicatorView!
    
    private let searchTextPlaceholders = ["elon musk", "donald trump", "michelle obama", "katy perry", "lebron james"]

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
    fileprivate let twtrNetworkManager = TwitterNetworkManager()
    
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
        twtrNetworkManager.getLists().then { usersTELists -> Void in
            if usersTELists.isEmpty {
                // User doesn't have existing TE lists
                return
            } else {
                self.twtrNetworkManager.getListsUsers(lists: usersTELists).then { usersTEListsUsers -> Void in
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
                }.catch { error in
                    print("Error: \(error)")
                }
            }
        }.always {
            self.retrieveAndShowSuggestedUsers()
        }.catch { error in
            print("Error, logging out: \(error)")
            self.logout()
        }
    }
    
    func showSuggestedUsers() {
        suggestedUsers = cachedLists
            .filter { $0.user != nil && $0.memberCount > 0}
            .map { $0.user! }
            + followingUsers
        
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
        if !suggestedUsers.isEmpty {
            showSuggestedUsers()
            return
        }
        
        twtrNetworkManager.getFriends().then { followingTWTRUsers -> Promise<[TWTRList]> in
            self.followingUsers = followingTWTRUsers
            return self.twtrNetworkManager.getPublicLists()
        }.then { publicLists -> Promise<[TWTRUserCustom]> in
            self.publicLists = publicLists
            return self.twtrNetworkManager.getListsUsers(lists: publicLists)
        }.then { publicListsUsers -> Void in
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
            
            // sort to move groups of users with less following users to the top
            var followingTWTRUsers = self.followingUsers
            var idealFollowingTWTRUsers = followingTWTRUsers.filter { $0.followingCount >= 10 && $0.followingCount < 200 } + publicListsUsers
            idealFollowingTWTRUsers.shuffle()
            followingTWTRUsers = idealFollowingTWTRUsers +
                followingTWTRUsers.filter { $0.followingCount >= 200 && $0.followingCount < 500 } +
                followingTWTRUsers.filter { $0.followingCount >= 500 }
            self.followingUsers = followingTWTRUsers
        }.always {
            self.showSuggestedUsers()
        }.catch { error in
            print("Error: \(error)")
        }
    }
    
    @objc func clickedLogoutButton(sender: Any?) {
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
            twtrNetworkManager.usersSearch(urlEncodedCurrentText).then { (searchResultsUsers, queryItem) -> Void in
                if self.urlEncodedCurrentText == (queryItem.value?.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed))! {
                    if !searchResultsUsers.isEmpty {
                        self.usersToShow = searchResultsUsers
                        self.showingSuggestedUsers = false
                        self.suggestionsForYouLabelHeightConstraint.constant = 0
                    }
                }
            }.catch { error in
                print("Error: \(error)")
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
