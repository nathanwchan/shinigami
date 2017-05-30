//
//  ViewController.swift
//  shinigami
//
//  Created by Nathan Chan on 5/23/17.g
//  Copyright © 2017 Nathan Chan. All rights reserved.
//

import UIKit
import TwitterKit

class ViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var testTextField: UITextField!
    @IBOutlet weak var testLabel: UILabel!
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        //testLabel.text = textField.text
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        testLabel.text = (textField.text as NSString?)?.replacingCharacters(in: range, with: string)
        return true
    }
    
    @IBAction func labelTapGesture(_ sender: UITapGestureRecognizer) {
        testLabel.text = "nate tapped that"
    }
    
    private func loginSuccess() {
        DispatchQueue.main.async {
            self.performSegue(withIdentifier: "LoginSuccessSegue", sender: nil)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        /* logout last session
        let store = Twitter.sharedInstance().sessionStore
        if let userID = store.session()?.userID {
            let sessions = store.existingUserSessions()
            store.logOutUserID(userID)
            print("logged out \(userID)")
        }*/
        
        let client = TWTRAPIClient.withCurrentUser()
        print("****** current userID: \(client.userID ?? "none")")
        
        if client.userID != nil {
            print("****** user already logged in with id \(client.userID!)")
            loginSuccess()
        } else {
            /*
            // for directly popping up login page
            Twitter.sharedInstance().logIn {(session, error) in
                if let s = session {
                    print("****** logged in user with id \(s.userID)")
                    self.loginSuccess()
                } else {
                    print("****** login error \(error.debugDescription)")
                }
            }
            */
            
            let logInButton = TWTRLogInButton(logInCompletion: { session, error in
                if (session != nil) {
                    print("****** logged in with id \(session?.userID ?? "none") and username \(session?.userName ?? "unknown")");
                    self.loginSuccess()
                } else {
                    print("******  login error: \(error?.localizedDescription ?? "unknown")");
                }
            })
            logInButton.center = self.view.center
            self.view.addSubview(logInButton)
        }
        
        
        testTextField.delegate = self
    }
}

