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
    @objc dynamic var idStr: String = ""
    @objc dynamic var name: String = ""
    @objc dynamic var screenName: String = ""
    @objc dynamic var location: String = ""
    @objc dynamic var userDescription: String = ""
    @objc dynamic var followersCount: Int = 0 // unused
    @objc dynamic var followingCount: Int = 0 // friends_count
    @objc dynamic var isVerified: Bool = false
    @objc dynamic var profileImageNormalSizeUrl: String = ""
    @objc dynamic var profileImageOriginalSizeUrl: String = ""
    @objc dynamic var following: Bool = false // is the logged-in user following this user?
    
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
