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
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.searchTextField.becomeFirstResponder()
        
        self.searchTextField.delegate = self
        self.usersTableView.dataSource = self
        self.usersTableScrollView.delegate = self
        
        self.usersTableView.tableFooterView = UIView(frame: CGRect.zero)

        self.showFollowingUsers()
    }
    
    func showFollowingUsers() {
        if self.followingUsers.isEmpty {
            let usersFollowingEndpoint = "https://api.twitter.com/1.1/friends/list.json"
            let request = self.client.urlRequest(withMethod: "GET", url: usersFollowingEndpoint, parameters: nil, error: &self.clientError)
            
            self.client.sendTwitterRequest(request) { (_, data, connectionError) -> Void in
                guard let data = data else {
                    print("Error: \(connectionError.debugDescription)")
                    return
                }
                let jsonData = JSON(data: data)
                self.followingUsers = jsonData["users"].arrayValue.map { TWTRUserCustom.init(json: $0)! }
                self.users = self.followingUsers
                self.usersTableView.reloadData()
            }
        } else {
            self.users = self.followingUsers
            self.usersTableView.reloadData()
        }
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let currentText = (textField.text as NSString?)?.replacingCharacters(in: range, with: string)
        self.urlEncodedCurrentText = (currentText?.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed))!
        if self.urlEncodedCurrentText.isEmpty {
            self.showFollowingUsers()
        } else {
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
                }
            }
        }
        return true
    }
    
    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        self.showFollowingUsers()
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
        return userCell
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.users.count
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAtIndexPath indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // hide keyboard when scroll detected
        self.view.endEditing(true)
    }
    
    @IBAction func clickedLogout(_ sender: Any) {
        let store = Twitter.sharedInstance().sessionStore
        
        if let userID = store.session()?.userID {
            store.logOutUserID(userID)
            print("logged out user with id \(userID)")
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
            case "LogoutSegue":
                break
            default:
                fatalError("Unexpected Segue Identifier; \(segue.identifier ?? "unknown")")
        }
    }
}
