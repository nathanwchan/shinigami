//
//  HomeSearchViewController.swift
//  shinigami
//
//  Created by Nathan Chan on 5/30/17.
//  Copyright © 2017 Nathan Chan. All rights reserved.
//

import UIKit
import TwitterKit

class HomeSearchViewController: UIViewController, UITextFieldDelegate, UITableViewDataSource, UIScrollViewDelegate {

    @IBOutlet weak var searchTextField: UITextField!
    @IBOutlet weak var usersTableView: UITableView!
    @IBOutlet weak var usersTableScrollView: UIScrollView!
    
    private var users: [AnyObject] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.searchTextField.becomeFirstResponder()
        
        self.searchTextField.delegate = self
        self.usersTableView.dataSource = self
        self.usersTableScrollView.delegate = self
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let currentText = (textField.text as NSString?)?.replacingCharacters(in: range, with: string)
        
        let client = TWTRAPIClient.withCurrentUser()
        
        let urlEncodedCurrentText = (currentText?.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed))!
        if !urlEncodedCurrentText.isEmpty {
            let usersSearchEndpoint = "https://api.twitter.com/1.1/users/search.json?q=\(urlEncodedCurrentText)"
            var clientError : NSError?
            
            let request = client.urlRequest(withMethod: "GET", url: usersSearchEndpoint, parameters: nil, error: &clientError)
            
            client.sendTwitterRequest(request) { (response, data, connectionError) -> Void in
                guard let data = data else {
                    print("Error: \(connectionError.debugDescription)")
                    return
                }
                
                do {
                    self.users = try JSONSerialization.jsonObject(with: data) as! [AnyObject]
                    self.usersTableView.reloadData()
                } catch let jsonError as NSError {
                    // intentionally don't reset self.users values so we can continue displaying last retrieved results in case of error
                    print("json error: \(jsonError.localizedDescription)")
                }
            }
        } else {
            self.users = []
            self.usersTableView.reloadData()
        }
        return true
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let userCell = tableView.dequeueReusableCell(withIdentifier: "userCell", for: indexPath)
        userCell.textLabel?.text = String(describing: self.users[indexPath.row]["screen_name"]!!)
        return userCell
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.users.count
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
}
