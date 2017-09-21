//
//  TWTRList.swift
//  shinigami
//
//  Created by Nathan Chan on 6/13/17.
//  Copyright © 2017 Nathan Chan. All rights reserved.
//

import Foundation
import SwiftyJSON
import RealmSwift
import TwitterKit

class TWTRList: Object {
    @objc dynamic var ownerId: String = ""
    @objc dynamic var idStr: String = ""
    @objc dynamic var name: String = ""
    @objc dynamic var uri: String = ""
    @objc dynamic var memberCount: Int = 0
    @objc dynamic var createdAt: Date?
    @objc dynamic var user: TWTRUserCustom?
    
    convenience init?(json: JSON, user: TWTRUserCustom?) {
        self.init()
        guard
            let ownerId = Twitter.sharedInstance().sessionStore.session()?.userID,
            let idStr = json["id_str"].string,
            let name = json["name"].string,
            let uri = json["uri"].string,
            let memberCount = json["member_count"].int,
            let createdAtStr = json["created_at"].string
            else {
                return nil
        }
        
        let formatter  = DateFormatter()
        formatter.dateFormat = "E MMM d HH:mm:ss Z yyyy"
        
        self.ownerId = ownerId
        self.idStr = idStr
        self.name = name
        self.uri = uri
        self.memberCount = memberCount
        self.createdAt = formatter.date(from: createdAtStr) ?? Date()
        self.user = user
    }
    
    override static func primaryKey() -> String? {
        return "idStr"
    }
}
