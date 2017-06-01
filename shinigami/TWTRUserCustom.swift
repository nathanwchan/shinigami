//
//  TWTRUserCustom.swift
//  shinigami
//
//  Created by Nathan Chan on 5/31/17.
//  Copyright © 2017 Nathan Chan. All rights reserved.
//

import Foundation

class TWTRUserCustom {
    let idStr: String
    let name: String
    let screenName: String
    let location: String
    let description: String
    let followersCount: Int // unused
    let followingCount: Int // friends_count
    let isVerified: Bool
    let profileImageUrl: String
    let following: Bool // is the logged-in user following this user?
    
    init?(json: [String: Any]) {
        guard
            let idStr = json["id_str"] as? String,
            let name = json["name"] as? String,
            let screenName = json["screen_name"] as? String,
            let location = json["location"] as? String,
            let description = json["description"] as? String,
            let followersCount = json["followers_count"] as? Int,
            let followingCount = json["friends_count"] as? Int,
            let isVerified = json["verified"] as? Bool,
            let profileImageUrl = json["profile_image_url_https"] as? String,
            let following = json["following"] as? Bool
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
        self.profileImageUrl = profileImageUrl
        self.following = following
    }
}
