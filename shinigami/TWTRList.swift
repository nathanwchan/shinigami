//
//  TWTRList.swift
//  shinigami
//
//  Created by Nathan Chan on 6/13/17.
//  Copyright © 2017 Nathan Chan. All rights reserved.
//

import Foundation
import SwiftyJSON

class TWTRList {
    let idStr: String
    let name: String
    let uri: String
    let memberCount: Int
    let createdAt: String
    
    init?(json: JSON) {
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
