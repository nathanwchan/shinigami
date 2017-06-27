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

class SearchViewController: UIViewController, UITextFieldDelegate, UITableViewDataSource, UIScrollViewDelegate {

    @IBOutlet weak var searchTextField: UITextField!
    @IBOutlet weak var suggestionsForYouLabelHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var usersTableView: UITableView!
    @IBOutlet weak var usersTableScrollView: UIScrollView!
    @IBOutlet weak var searchActivityIndicator: UIActivityIndicatorView!
    
    private let searchTextPlaceholders = ["elon musk", "donald trump", "michelle obama", "katy perry", "lebron james"]
    
    private let client = TWTRAPIClient.withCurrentUser()
    private var clientError: NSError?
    private var usersTELists: [TWTRList] = []
    private var usersTEListsUsers: [TWTRUserCustom] = []
    private var suggestedUsers: [TWTRUserCustom] = []
    private let maxSuggestedUsersCount: Int = 100
    private var usersToShow: [TWTRUserCustom] = []
    private var urlEncodedCurrentText: String = ""
    private var showingSuggestedUsers: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if globals.launchCount == 1 {
            self.searchTextField.becomeFirstResponder()
        }
        self.searchTextField.placeholder = self.searchTextPlaceholders[Int(arc4random()) % self.searchTextPlaceholders.count]
        self.suggestionsForYouLabelHeightConstraint.constant = 0
        
        self.searchTextField.delegate = self
        self.usersTableView.dataSource = self
        self.usersTableScrollView.delegate = self
        self.usersTableScrollView.keyboardDismissMode = .onDrag
        
        self.usersTableView.tableFooterView = UIView(frame: CGRect.zero)
        // dynamic cell height based on inner content
        self.usersTableView.rowHeight = UITableViewAutomaticDimension
        self.usersTableView.estimatedRowHeight = 70

        let getListsEndpoint = "https://api.twitter.com/1.1/lists/ownerships.json?count=1000"
        let request = self.client.urlRequest(withMethod: "GET", url: getListsEndpoint, parameters: nil, error: &self.clientError)
        self.client.sendTwitterRequest(request) { (_, data, connectionError) -> Void in
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
            self.usersTELists = jsonData["lists"].arrayValue
                .map { TWTRList(json: $0)! }
                .filter { $0.name.hasPrefix(Constants.listPrefix) && $0.memberCount > 0 }
            
            if self.usersTELists.isEmpty {
                // User doesn't have existing TE lists
                self.retrieveAndShowSuggestedUsers()
            } else {
                let getUsersEndpoint = "https://api.twitter.com/1.1/users/lookup.json"
                let usersFromTELists = self.usersTELists.map { String($0.name.characters.dropFirst(Constants.listPrefix.characters.count)) } // drop prefix from list name to get username
                let params = [
                    "screen_name": usersFromTELists[0..<min(usersFromTELists.count,100)].joined(separator: ",") // users/lookup.json API has 100 users per request limit
                ]
                let request = self.client.urlRequest(withMethod: "GET", url: getUsersEndpoint, parameters: params, error: &self.clientError)
                self.client.sendTwitterRequest(request) { (_, data, connectionError) -> Void in
                    guard let data = data else {
                        print("Error: \(connectionError.debugDescription)")
                        firebase.logEvent("twitter_error_users_lookup")
                        return
                    }
                    let jsonData = JSON(data: data)
                    self.usersTEListsUsers = jsonData.arrayValue.map { TWTRUserCustom(json: $0)! }
                    
                    self.retrieveAndShowSuggestedUsers()
                }
            }
        }
    }
    
    func showSuggestedUsers() {
        self.usersToShow = self.suggestedUsers
        self.searchActivityIndicator.stopAnimating()
        self.usersTableView.reloadData()
        self.showingSuggestedUsers = true
        self.suggestionsForYouLabelHeightConstraint.constant = 15
    }
    
    func retrieveAndShowSuggestedUsers() {
        if self.suggestedUsers.isEmpty {
            if self.usersTEListsUsers.count < self.maxSuggestedUsersCount {
                let usersFollowingEndpoint = "https://api.twitter.com/1.1/friends/list.json?count=200"
                let request = self.client.urlRequest(withMethod: "GET", url: usersFollowingEndpoint, parameters: nil, error: &self.clientError)
                
                self.client.sendTwitterRequest(request) { (_, data, connectionError) -> Void in
                    guard let data = data else {
                        print("Error: \(connectionError.debugDescription)")
                        firebase.logEvent("twitter_error_friends_list")
                        return
                    }
                    let jsonData = JSON(data: data)
                    var followingTWTRUsers = jsonData["users"].arrayValue.map { TWTRUserCustom(json: $0)! }
                    // sort by popularity (follower count)
                    followingTWTRUsers = followingTWTRUsers.sorted(by: { $0.followersCount > $1.followersCount })
                    // sort to move groups of users with less following users to the top
                    followingTWTRUsers =
                        followingTWTRUsers.filter{$0.followingCount > 0 && $0.followingCount < 200} +
                        followingTWTRUsers.filter{$0.followingCount >= 200 && $0.followingCount < 500} +
                        followingTWTRUsers.filter{$0.followingCount >= 500}
                    
                    self.suggestedUsers = self.usersTEListsUsers + followingTWTRUsers
                    // remove duplicates
                    var duplicateUserIds = Set<String>()
                    let dedupedSuggestedUsers = self.suggestedUsers.flatMap { (user) -> TWTRUserCustom? in
                        guard !duplicateUserIds.contains(user.idStr) else { return nil }
                        duplicateUserIds.insert(user.idStr)
                        return user
                    }
                    self.suggestedUsers = Array(dedupedSuggestedUsers[0..<min(dedupedSuggestedUsers.count, self.maxSuggestedUsersCount)])
                    self.showSuggestedUsers()
                }
            } else {
                // suggested users will be all from existing TE lists
                self.suggestedUsers = Array(self.usersTEListsUsers[0..<100])
                self.showSuggestedUsers()
            }
        } else {
            self.showSuggestedUsers()
        }
    }

    func scrollToFirstRow() {
        if self.usersToShow.count > 0 {
            let indexPath = IndexPath(row: 0, section: 0)
            self.usersTableView.scrollToRow(at: indexPath, at: .top, animated: true)
        }
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let currentText = (textField.text as NSString?)?.replacingCharacters(in: range, with: string)
        self.urlEncodedCurrentText = (currentText?.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed))!
        if self.urlEncodedCurrentText.isEmpty {
            self.retrieveAndShowSuggestedUsers()
        } else {
            let usersSearchEndpoint = "https://api.twitter.com/1.1/users/search.json?q=\(self.urlEncodedCurrentText)"
            let request = self.client.urlRequest(withMethod: "GET", url: usersSearchEndpoint, parameters: nil, error: &self.clientError)
            
            self.client.sendTwitterRequest(request) { (response, data, connectionError) -> Void in
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
                    if searchResultsUsers.count > 0 {
                        self.usersToShow = searchResultsUsers
                        self.searchActivityIndicator.stopAnimating()
                        self.usersTableView.reloadData()
                        self.showingSuggestedUsers = false
                        self.suggestionsForYouLabelHeightConstraint.constant = 0
                    }
                }
            }
        }
        self.scrollToFirstRow()
        return true
    }
    
    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        self.retrieveAndShowSuggestedUsers()
        self.scrollToFirstRow()
        return true
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let userCell = tableView.dequeueReusableCell(withIdentifier: "userCell", for: indexPath) as? UserTableViewCell else {
            fatalError("The dequeued cell is not an instance of UserTableViewCell.")
        }
        let user = self.usersToShow[indexPath.row]
        userCell.configureWith(user)
        // Kinda hacky, but what StackOverflow told me to do.  Set height constraint of following icon to zero.
        userCell.followingIconHeightConstraint.constant = user.following ? 18 : 0
        return userCell
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.usersToShow.count
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAtIndexPath indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func logout() {
        let store = Twitter.sharedInstance().sessionStore
        
        if let userID = store.session()?.userID {
            store.logOutUserID(userID)
            globals.launchCount = UserDefaults.standard.integer(forKey: Constants.launchCountUserDefaultsKey) - 1
            UserDefaults.standard.set(globals.launchCount, forKey: Constants.launchCountUserDefaultsKey)
            firebase.logEvent("logout_\(userID)")
        }
        
        DispatchQueue.main.async {
            self.navigationController?.viewControllers = []
            self.performSegue(withIdentifier: "LogoutSegue", sender: nil)
        }
    }
    
    @IBAction func clickedLogout(_ sender: Any) {
        self.logout()
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
                    
                profileViewController.user = self.usersToShow[indexPath.row]
                let listName = "\(Constants.listPrefix)\(profileViewController.user!.screenName)"
                profileViewController.list = usersTELists.filter { $0.name == listName }.first
                
                if self.showingSuggestedUsers {
                    firebase.logEvent("search_click_suggested_index_\(indexPath.row)")
                }
            case "LogoutSegue":
                break
            default:
                fatalError("Unexpected Segue Identifier; \(segue.identifier ?? "unknown")")
        }
    }
}
