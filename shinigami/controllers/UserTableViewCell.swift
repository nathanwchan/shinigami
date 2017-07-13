//
//  UserTableViewCell.swift
//  shinigami
//
//  Created by Nathan Chan on 5/31/17.
//  Copyright © 2017 Nathan Chan. All rights reserved.
//

import UIKit

class UserTableViewCell: UITableViewCell {

    @IBOutlet weak var userProfileImageView: UIImageView!
    @IBOutlet weak var userNameLabel: UILabel!
    @IBOutlet weak var userScreenNameLabel: UILabel!
    @IBOutlet weak var userIsVerifiedImageView: UIImageView!
    @IBOutlet weak var followingCountLabel: UILabel!
    @IBOutlet weak var followingIcon: UIImageView!
    @IBOutlet weak var isFollowingLabel: UILabel!
    @IBOutlet weak var followingIconHeightConstraint: NSLayoutConstraint!

    func configureWith(_ user: TWTRUserCustom) {
        self.userProfileImageView.image(fromUrl: user.profileImageNormalSizeUrl)
        self.userProfileImageView.layer.cornerRadius = 5
        self.userProfileImageView.clipsToBounds = true
        self.userNameLabel.text = user.name
        self.userScreenNameLabel.text = "@\(user.screenName)"
        self.followingCountLabel.text = abbreviateNumber(num: user.followingCount)
        self.userIsVerifiedImageView.isHidden = !user.isVerified
        self.followingIcon.isHidden = !user.following
        self.isFollowingLabel.isHidden = !user.following
        // Feels hacky, but what StackOverflow told me to do.  Set height constraint of following icon to zero.
        self.followingIconHeightConstraint.constant = user.following ? 18 : 0
    }
}
