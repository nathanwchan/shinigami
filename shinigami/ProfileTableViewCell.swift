//
//  ProfileTableViewCell.swift
//  shinigami
//
//  Created by Nathan Chan on 6/1/17.
//  Copyright © 2017 Nathan Chan. All rights reserved.
//

import UIKit
import TwitterKit
import RealmSwift

class ProfileTableViewCell: UITableViewCell {

    @IBOutlet weak var profileImageView: UIImageView!
    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var screenNameLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var whatNameSeesLabel: UILabel!
    @IBOutlet weak var isVerifiedImageView: UIImageView!
    @IBOutlet weak var followingLabel: UILabel!
    @IBOutlet weak var favoriteButton: UIButton!
    var isFavorite: Bool = false
    var user: TWTRUserCustom?
    var list: TWTRList?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func toggleFavoriteButtonOn() {
        self.isFavorite = true
        self.favoriteButton.setImage(UIImage(named: "heart-filled.png")!, for: .normal)
    }
    
    @IBAction func clickFavoriteButton(_ sender: UIButton) {
        if !self.isFavorite {
            let realm = try! Realm()
            try! realm.write() {
                guard let ownerId = Twitter.sharedInstance().sessionStore.session()?.userID else {
                    return
                }
                guard let user = self.user else {
                    fatalError("User is not set.")
                }
                guard let list = self.list else {
                    // this should not happen once the favorite button is disabled after an error occurs
                    print("List is not set.")
                    return
                }
                let favorite = Favorite(ownerId: ownerId, user: user, list: list)
                realm.create(Favorite.self, value: favorite)
            }
            self.toggleFavoriteButtonOn()
        }
    }
}
