//
//  Globals.swift
//  shinigami
//
//  Created by Nathan Chan on 6/14/17.
//  Copyright © 2017 Nathan Chan. All rights reserved.
//

import Foundation

struct Constants {
    static let listPrefix: String = "Tweetsee_"
    static let launchCountUserDefaultsKey = "launchCount"
    static let lastStoreReviewLaunchCountUserDefaultsKey = "lastStoreReviewLaunchCount"
}

struct Globals {
    var launchCount: Int = 0
    var lastStoreReviewLaunchCount: Int = UserDefaults.standard.integer(forKey: Constants.lastStoreReviewLaunchCountUserDefaultsKey)
}

var globals = Globals()
