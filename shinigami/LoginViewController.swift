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
        globals.launchCount = UserDefaults.standard.integer(forKey: Constants.launchCountUserDefaultsKey) + 1
        UserDefaults.standard.set(globals.launchCount, forKey: Constants.launchCountUserDefaultsKey)
        firebase.logEvent("launch_count_\(globals.launchCount)")
        
        DispatchQueue.main.async {
            self.performSegue(withIdentifier: "LoginSuccessSegue", sender: nil)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let userID = Twitter.sharedInstance().sessionStore.session()?.userID {
            firebase.logEvent("login_already_\(userID)")
            loginSuccess()
        } else {
            /*
            // for directly popping up login page
            Twitter.sharedInstance().logIn {(session, error) in
                if let s = session {
                    print("****** logged in user with id \(s.userID)")
                    self.loginSuccess()
                }
            }
            */
            
            loginButton.logInCompletion = { session, error in
                if (session != nil) {
                    let username = session?.userName ?? "unknown"
                    firebase.logEvent("login_success_\(username)")
                    self.loginSuccess()
                }
            }
        }
    }
}

