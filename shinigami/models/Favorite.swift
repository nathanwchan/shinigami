//
//  Favorite.swift
//  shinigami
//
//  Created by Nathan Chan on 6/15/17.
//  Copyright © 2017 Nathan Chan. All rights reserved.
//

import Foundation
import RealmSwift
import TwitterKit

class Favorite: Object {
    @objc dynamic var ownerId: String = ""
    @objc dynamic var list: TWTRList?
    @objc dynamic var createdAt = Date()
    
    override static func indexedProperties() -> [String] {
        return ["ownerId", "createdAt"]
    }
    
    convenience init?(list: TWTRList) {
        self.init()
        guard let ownerId = Twitter.sharedInstance().sessionStore.session()?.userID else {
            return nil
        }
        self.ownerId = ownerId
        self.list = list
    }
}
