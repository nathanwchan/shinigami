//
//  Favorite.swift
//  shinigami
//
//  Created by Nathan Chan on 6/15/17.
//  Copyright © 2017 Nathan Chan. All rights reserved.
//

import Foundation
import RealmSwift

class Favorite: Object {
    dynamic var ownerId: String = ""
    dynamic var list: TWTRList?
    dynamic var createdAt = Date()
    
    override static func indexedProperties() -> [String] {
        return ["ownerId", "createdAt"]
    }
    
    convenience init(ownerId: String, list: TWTRList) {
        self.init()
        self.ownerId = ownerId
        self.list = list
    }
}
