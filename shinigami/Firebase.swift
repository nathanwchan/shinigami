//
//  Firebase.swift
//  shinigami
//
//  Created by Nathan Chan on 6/19/17.
//  Copyright © 2017 Nathan Chan. All rights reserved.
//

import Foundation
import Firebase
import TwitterKit

class Firebase {
    var userId = Twitter.sharedInstance().sessionStore.session()?.userID
    
    func logEvent(_ name: String, _ params: [String: Any]?) {
        var parameters: [String: Any] = [:]
        if params != nil {
            parameters = params!
        }
        parameters["userId"] = self.userId
        
        FIRAnalytics.logEvent(withName: name, parameters: parameters)
    }
}

