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

    @IBOutlet weak var profileImageButton: UIButton!
    @IBOutlet weak var nameButton: UIButton!
    @IBOutlet weak var screenNameLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var whatNameSeesLabel: UILabel!
    @IBOutlet weak var isVerifiedImageView: UIImageView!
    @IBOutlet weak var followingLabel: UILabel!
    @IBOutlet weak var favoriteButton: UIButton!
    var isFavorite: Bool = false
    var favorite: Favorite?
    var user: TWTRUserCustom?
    var list: TWTRList?
    
    enum HeartFileNames: String {
        case on = "heart-filled.png"
        case off = "heart.png"
    }
    override func awakeFromNib() {
        super.awakeFromNib()
    }
    
    func toggleFavoriteButton(_ turnOn: Bool) {
        self.isFavorite = turnOn
        let heartFileName = turnOn ? HeartFileNames.on.rawValue : HeartFileNames.off.rawValue
        self.favoriteButton.setImage(UIImage(named: heartFileName)!, for: .normal)
    }
    
    @IBAction func clickFavoriteButton(_ sender: UIButton) {
        let realm = try! Realm()
        try! realm.write() {
            if self.isFavorite {
                if let favorite = self.favorite {
                    realm.delete(favorite)
                    
                    firebase.logEvent("profile_delete_favorite_\(self.user?.screenName ?? "unknown")")
                }
            } else {
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
                self.favorite = realm.create(Favorite.self, value: favorite)
                
                firebase.logEvent("profile_save_favorite_\(user.screenName)")
            }
            self.toggleFavoriteButton(!self.isFavorite)
        }
    }
}
