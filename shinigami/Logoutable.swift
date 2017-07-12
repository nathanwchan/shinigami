//
//  Logoutable.swift
//  shinigami
//
//  Created by Nathan Chan on 7/12/17.
//  Copyright © 2017 Nathan Chan. All rights reserved.
//

import Foundation
import TwitterKit

protocol Logoutable {
    func logout()
}

extension Logoutable where Self : UIViewController {
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
}
