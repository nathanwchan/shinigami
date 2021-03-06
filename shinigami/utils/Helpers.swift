//
//  Helpers.swift
//  shinigami
//
//  Created by Nathan Chan on 6/7/17.
//  Copyright © 2017 Nathan Chan. All rights reserved.
//

import Foundation
import StoreKit

func abbreviateNumber(num: Int) -> String {
    // Used to abbreviate users' following count - eg. 1,495 -> 1.5K; 23,948,123 -> 23.9M
    // NOTE: really dumb implementation, should probably come back and make this more accurate, but good enough for now.
    if (num < 1000) {
        return String(describing: num)
    } else if (num < 1000000) {
        return "\(round(Double(num) / 100) / 10)K"
    } else {
        return "\(round(Double(num) / 100000) / 10)M"
    }
}

func attemptPromptStoreReview() {
    if (globals.launchCount - globals.lastStoreReviewLaunchCount) > 2 {
        // the last attempt was 3 or more launches ago
        globals.lastStoreReviewLaunchCount = globals.launchCount
        UserDefaults.standard.set(globals.launchCount, forKey: Constants.lastStoreReviewLaunchCountUserDefaultsKey)
        SKStoreReviewController.requestReview()
        firebase.logEvent("store_review_request")
    }
}
