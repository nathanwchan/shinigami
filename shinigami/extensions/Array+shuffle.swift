//
//  Array+shuffle.swift
//  shinigami
//
//  Created by Nathan Chan on 7/4/17.
//  Copyright © 2017 Nathan Chan. All rights reserved.
//

import Foundation

extension Array {
    /** Randomizes the order of an array's elements. */
    mutating func shuffle() {
        for _ in 0..<10 {
            sort { (_,_) in arc4random() < arc4random() }
        }
    }
}
