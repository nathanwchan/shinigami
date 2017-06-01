//
//  UIImageView+downloadedFrom.swift
//  shinigami
//
//  Created by Nathan Chan on 5/31/17.
//  Copyright © 2017 Nathan Chan. All rights reserved.
//

import UIKit

extension UIImageView {
    public func image(fromUrl urlString: String) {
        guard let url = URL(string: urlString) else {
            print("Couldn't create URL from \(urlString)")
            return
        }
        let theTask = URLSession.shared.dataTask(with: url) {
            data, response, error in
            if let response = data {
                DispatchQueue.main.async {
                    self.image = UIImage(data: response)
                }
            }
        }
        theTask.resume()
    }
}



/*
 extension UIImageView {
 func downloadedFrom(url: URL, contentMode mode: UIViewContentMode = .scaleAspectFit) {
 contentMode = mode
 URLSession.shared.dataTask(with: url) { (data, response, error) in
 guard let httpURLResponse = response as? HTTPURLResponse, httpURLResponse.statusCode == 200,
 let mimeType = response?.mimeType, mimeType.hasPrefix("image"),
 let data = data, error == nil,
 let image = UIImage(data: data)
 else { return }
 DispatchQueue.main.async() { () -> Void in
 self.image = image
 }
 }.resume()
 }
 func downloadedFrom(link: String, contentMode mode: UIViewContentMode = .scaleAspectFit) {
 guard let url = URL(string: link) else { return }
 downloadedFrom(url: url, contentMode: mode)
 }
 }*/
