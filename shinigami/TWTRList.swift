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

class TWTRList: Object {
    dynamic var idStr: String = ""
    dynamic var name: String = ""
    dynamic var uri: String = ""
    dynamic var memberCount: Int = 0
    dynamic var createdAt: String = ""
    
    convenience init?(json: JSON) {
        self.init()
        guard
            let idStr = json["id_str"].string,
            let name = json["name"].string,
            let uri = json["uri"].string,
            let memberCount = json["member_count"].int,
            let createdAt = json["created_at"].string
            else {
                return nil
        }
        
        self.idStr = idStr
        self.name = name
        self.uri = uri
        self.memberCount = memberCount
        self.createdAt = createdAt
    }
}
