//
//  UIButton+setImageFromUrl.swift
//  shinigami
//
//  Created by Nathan Chan on 6/19/17.
//  Copyright © 2017 Nathan Chan. All rights reserved.
//

import UIKit

extension UIButton {
    public func setImage(fromUrl urlString: String, for state: UIControlState) {
        guard let url = URL(string: urlString) else {
            print("Couldn't create URL from \(urlString)")
            return
        }
        let theTask = URLSession.shared.dataTask(with: url) {
            data, response, error in
            if let response = data {
                DispatchQueue.main.async {
                    self.setImage(UIImage(data: response), for: state)
                }
            }
        }
        theTask.resume()
    }
}
