//
//  TWTRUserCustom.swift
//  shinigami
//
//  Created by Nathan Chan on 5/31/17.
//  Copyright © 2017 Nathan Chan. All rights reserved.
//

import Foundation
import SwiftyJSON
import RealmSwift

class TWTRUserCustom: Object {
    dynamic var idStr: String = ""
    dynamic var name: String = ""
    dynamic var screenName: String = ""
    dynamic var location: String = ""
    dynamic var userDescription: String = ""
    dynamic var followersCount: Int = 0 // unused
    dynamic var followingCount: Int = 0 // friends_count
    dynamic var isVerified: Bool = false
    dynamic var profileImageNormalSizeUrl: String = ""
    dynamic var profileImageOriginalSizeUrl: String = ""
    dynamic var following: Bool = false // is the logged-in user following this user?
    
    convenience init?(json: JSON) {
        self.init()
        guard
            let idStr = json["id_str"].string,
            let name = json["name"].string,
            let screenName = json["screen_name"].string,
            let location = json["location"].string,
            let description = json["description"].string,
            let followersCount = json["followers_count"].int,
            let followingCount = json["friends_count"].int,
            let isVerified = json["verified"].bool,
            let profileImageNormalSizeUrl = json["profile_image_url_https"].string,
            let following = json["following"].bool
        else {
            return nil
        }
        
        self.idStr = idStr
        self.name = name
        self.screenName = screenName
        self.location = location
        self.userDescription = description
        self.followersCount = followersCount
        self.followingCount = followingCount
        self.isVerified = isVerified
        self.profileImageNormalSizeUrl = profileImageNormalSizeUrl
        self.profileImageOriginalSizeUrl = profileImageNormalSizeUrl.replacingOccurrences(of: "_normal", with: "")
        self.following = following
    }
    
    override static func primaryKey() -> String? {
        return "idStr"
    }
}
