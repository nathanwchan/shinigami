//
//  Globals.swift
//  shinigami
//
//  Created by Nathan Chan on 6/14/17.
//  Copyright © 2017 Nathan Chan. All rights reserved.
//

import Foundation

struct Constants {
    static let listPrefix = "Tweetsee_"
    static let launchCountUserDefaultsKey = "launchCount"
    static let lastStoreReviewLaunchCountUserDefaultsKey = "lastStoreReviewLaunchCount"
    static let publicListsTwitterAccount = "Tw1tterEyes"
}

struct Globals {
    var launchCount = 0
    var lastStoreReviewLaunchCount = UserDefaults.standard.integer(forKey: Constants.lastStoreReviewLaunchCountUserDefaultsKey)
}

var globals = Globals()
