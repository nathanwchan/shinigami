//
//  Globals.swift
//  shinigami
//
//  Created by Nathan Chan on 6/14/17.
//  Copyright © 2017 Nathan Chan. All rights reserved.
//

import Foundation

struct Constants {
    static let listPrefix: String = "TE_"
    static let launchCountUserDefaultsKey = "launchCount"
}

struct Globals {
    var launchCount: Int = 0
}

var globals = Globals()
