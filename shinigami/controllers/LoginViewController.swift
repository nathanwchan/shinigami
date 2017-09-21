//
//  LoginViewController.swift
//  shinigami
//
//  Created by Nathan Chan on 5/23/17.
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
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if let userID = Twitter.sharedInstance().sessionStore.session()?.userID {
            firebase.logEvent("login_already_\(userID)")
            loginSuccess()
        } else {
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
