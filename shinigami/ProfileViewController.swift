//
//  ProfileViewController.swift
//  shinigami
//
//  Created by Nathan Chan on 6/1/17.
//  Copyright © 2017 Nathan Chan. All rights reserved.
//

import UIKit
import TwitterKit

class ProfileViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    var user: TWTRUserCustom?
    
    @IBOutlet weak var profileTableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.profileTableView.dataSource = self
        self.profileTableView.delegate = self
        
        self.profileTableView.rowHeight = UITableViewAutomaticDimension
        self.profileTableView.estimatedRowHeight = 120
        self.profileTableView.tableFooterView = UIView(frame: CGRect.zero)
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        //if indexPath.row == 0 {
        guard let profileCell = tableView.dequeueReusableCell(withIdentifier: "profileCell", for: indexPath) as? ProfileTableViewCell else {
            fatalError("The dequeued cell is not an instance of ProfileTableViewCell.")
        }
        
        guard let user = self.user else {
            fatalError("User is not set.")
        }
        
        profileCell.profileImageView.image(fromUrl: user.profileImageOriginalSizeUrl)
        profileCell.profileImageView.layer.cornerRadius = 5
        profileCell.profileImageView.clipsToBounds = true
        profileCell.nameLabel.text = user.name
        profileCell.screenNameLabel.text = "@\(user.screenName)"
        profileCell.isVerifiedImageView.isHidden = !user.isVerified
        profileCell.descriptionLabel.text = user.description
        profileCell.whatNameSeesLabel.text = "What \(user.name) sees..."
        profileCell.followingLabel.text = "\(user.followingCount) following"
        return profileCell
        /*} else {
            
        }*/
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 0 {
        }
    }
}
