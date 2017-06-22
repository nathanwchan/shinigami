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
    func logEvent(_ name: String) {
        let eventNameCharacterLimit = 40
        var eventName = name
        if eventName.characters.count > eventNameCharacterLimit {
            eventName = eventName.substring(to: eventName.index(eventName.startIndex, offsetBy: eventNameCharacterLimit))
        }
        // FYI: Firebase Analytics doesn't expose parameters unless you hook it up to BigQuery
        FIRAnalytics.logEvent(withName: eventName, parameters: nil)
    }
}

let firebase = Firebase()

