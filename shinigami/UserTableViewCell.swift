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
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
