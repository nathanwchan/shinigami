//
//  TWTRUserCustom.swift
//  shinigami
//
//  Created by Nathan Chan on 5/31/17.
//  Copyright © 2017 Nathan Chan. All rights reserved.
//

import Foundation
import SwiftyJSON

class TWTRUserCustom {
    let idStr: String
    let name: String
    let screenName: String
    let location: String
    let description: String
    let followersCount: Int // unused
    let followingCount: Int // friends_count
    let isVerified: Bool
    let profileImageNormalSizeUrl: String
    let profileImageOriginalSizeUrl: String
    let following: Bool // is the logged-in user following this user?
    
    init?(json: JSON) {
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
        self.description = description
        self.followersCount = followersCount
        self.followingCount = followingCount
        self.isVerified = isVerified
        self.profileImageNormalSizeUrl = profileImageNormalSizeUrl
        self.profileImageOriginalSizeUrl = profileImageNormalSizeUrl.replacingOccurrences(of: "_normal", with: "")
        self.following = following
    }
}
