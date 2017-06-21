//
//  LoginViewController.swift
//  shinigami
//
//  Created by Nathan Chan on 5/23/17.g
//  Copyright © 2017 Nathan Chan. All rights reserved.
//

import UIKit
import TwitterKit

class LoginViewController: UIViewController {
    
    @IBOutlet weak var loginButton: TWTRLogInButton!
    
    private func loginSuccess() {
        DispatchQueue.main.async {
            self.performSegue(withIdentifier: "LoginSuccessSegue", sender: nil)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let store = Twitter.sharedInstance().sessionStore

        if let userID = store.session()?.userID {
            print("****** user already logged in with id \(userID)")
            Firebase().logEvent("login_already", nil)
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
            
            loginButton.logInCompletion = { session, error in
                if (session != nil) {
                    let userID = session?.userID ?? "none"
                    let username = session?.userName ?? "unknown"
                    print("****** logged in with id \(userID) and username \(username)");
                    Firebase().logEvent("login_success", [
                        "username": username
                        ])
                    self.loginSuccess()
                } else {
                    print("******  login error: \(error?.localizedDescription ?? "unknown")");
                }
            }
        }
    }
}

