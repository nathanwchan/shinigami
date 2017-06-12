//
//  HomeSearchViewController.swift
//  shinigami
//
//  Created by Nathan Chan on 5/30/17.
//  Copyright © 2017 Nathan Chan. All rights reserved.
//

import UIKit
import TwitterKit
import SwiftyJSON

class HomeSearchViewController: UIViewController, UITextFieldDelegate, UITableViewDataSource, UIScrollViewDelegate {

    @IBOutlet weak var searchTextField: UITextField!
    @IBOutlet weak var usersTableView: UITableView!
    @IBOutlet weak var usersTableScrollView: UIScrollView!
    
    private let client = TWTRAPIClient.withCurrentUser()
    private var clientError : NSError?
    private var users: [TWTRUserCustom] = []
    private var followingUsers: [TWTRUserCustom] = []
    private var urlEncodedCurrentText: String = ""
    private var showingFollowingUsers: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        GA().logScreen(name: "search")
        
        self.searchTextField.becomeFirstResponder()
        
        self.searchTextField.delegate = self
        self.usersTableView.dataSource = self
        self.usersTableScrollView.delegate = self
        self.usersTableScrollView.keyboardDismissMode = .onDrag
        
        self.usersTableView.tableFooterView = UIView(frame: CGRect.zero)
        // dynamic cell height based on inner content
        self.usersTableView.rowHeight = UITableViewAutomaticDimension
        self.usersTableView.estimatedRowHeight = 70

        self.showFollowingUsers()
    }
    
    func showFollowingUsers() {
        if self.followingUsers.isEmpty {
            let usersFollowingEndpoint = "https://api.twitter.com/1.1/friends/list.json?count=200"
            let request = self.client.urlRequest(withMethod: "GET", url: usersFollowingEndpoint, parameters: nil, error: &self.clientError)
            
            self.client.sendTwitterRequest(request) { (_, data, connectionError) -> Void in
                guard let data = data else {
                    print("Error: \(connectionError.debugDescription)")
                    return
                }
                let jsonData = JSON(data: data)
                var followingTWTRUserCustoms = jsonData["users"].arrayValue.map { TWTRUserCustom.init(json: $0)! }
                // sort by popularity (follower count)
                followingTWTRUserCustoms = followingTWTRUserCustoms.sorted(by: { $0.followersCount > $1.followersCount })
                // sort to move groups of users with less following users to the top
                self.followingUsers =
                    followingTWTRUserCustoms.filter{$0.followingCount > 0 && $0.followingCount < 200} +
                    followingTWTRUserCustoms.filter{$0.followingCount >= 200 && $0.followingCount < 500} +
                    followingTWTRUserCustoms.filter{$0.followingCount >= 500}
                self.users = self.followingUsers
                self.usersTableView.reloadData()
            }
        } else {
            self.users = self.followingUsers
            self.usersTableView.reloadData()
        }
        self.showingFollowingUsers = true
    }

    func scrollToFirstRow() {
        if self.users.count > 0 {
            let indexPath = IndexPath(row: 0, section: 0)
            self.usersTableView.scrollToRow(at: indexPath, at: .top, animated: true)
        }
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let currentText = (textField.text as NSString?)?.replacingCharacters(in: range, with: string)
        self.urlEncodedCurrentText = (currentText?.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed))!
        if self.urlEncodedCurrentText.isEmpty {
            GA().logAction(category: "search", action: "change-empty")
            self.showFollowingUsers()
        } else {
            GA().logAction(category: "search", action: "change", label: self.urlEncodedCurrentText)
            
            let usersSearchEndpoint = "https://api.twitter.com/1.1/users/search.json?q=\(self.urlEncodedCurrentText)"
            let request = self.client.urlRequest(withMethod: "GET", url: usersSearchEndpoint, parameters: nil, error: &self.clientError)
            
            self.client.sendTwitterRequest(request) { (response, data, connectionError) -> Void in
                guard let data = data else {
                    print("Error: \(connectionError.debugDescription)")
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
                    self.users = jsonData.arrayValue.map { TWTRUserCustom.init(json: $0)! }
                    self.usersTableView.reloadData()
                    self.showingFollowingUsers = false
                }
            }
        }
        self.scrollToFirstRow()
        return true
    }
    
    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        GA().logAction(category: "search", action: "clear")
        self.showFollowingUsers()
        self.scrollToFirstRow()
        return true
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let userCell = tableView.dequeueReusableCell(withIdentifier: "userCell", for: indexPath) as? UserTableViewCell else {
            fatalError("The dequeued cell is not an instance of UserTableViewCell.")
        }
        let user = self.users[indexPath.row]
        userCell.userProfileImageView.image(fromUrl: user.profileImageNormalSizeUrl)
        userCell.userProfileImageView.layer.cornerRadius = 5
        userCell.userProfileImageView.clipsToBounds = true
        userCell.userNameLabel.text = user.name
        userCell.userScreenNameLabel.text = "@\(user.screenName)"
        userCell.followingCountLabel.text = abbreviateNumber(num: user.followingCount)
        userCell.userIsVerifiedImageView.isHidden = !user.isVerified
        userCell.followingIcon.isHidden = !user.following
        userCell.isFollowingLabel.isHidden = !user.following
        // Kinda hacky, but what StackOverflow told me to do.  Set height constraint of following icon to zero.
        userCell.followingIconHeightConstraint.constant = user.following ? 18 : 0
        return userCell
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.users.count
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAtIndexPath indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    @IBAction func clickedLogout(_ sender: Any) {
        let store = Twitter.sharedInstance().sessionStore
        
        if let userID = store.session()?.userID {
            store.logOutUserID(userID)
            print("logged out user with id \(userID)")
            GA().logAction(category: "logout", action: "success", label: userID)
        }
        
        DispatchQueue.main.async {
            self.navigationController?.viewControllers = []
            self.performSegue(withIdentifier: "LogoutSegue", sender: nil)
        }
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
                    
                profileViewController.user = self.users[indexPath.row]
                if self.showingFollowingUsers {
                    GA().logAction(category: "search", action: "click-following-index", label: String(describing: indexPath.row))
                    GA().logAction(category: "search", action: "click-following-screenname", label: profileViewController.user?.screenName)
                } else {
                    GA().logAction(category: "search", action: "click-search-screenname", label: profileViewController.user?.screenName)
                }
            case "LogoutSegue":
                break
            default:
                fatalError("Unexpected Segue Identifier; \(segue.identifier ?? "unknown")")
        }
    }
}
