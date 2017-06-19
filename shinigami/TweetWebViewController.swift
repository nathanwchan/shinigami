//
//  TweetWebViewController.swift
//  shinigami
//
//  Created by Nathan Chan on 6/16/17.
//  Copyright © 2017 Nathan Chan. All rights reserved.
//

import UIKit

class TweetWebViewController: UIViewController {

    @IBOutlet weak var webView: UIWebView!
    
    var url: URL?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let redirectUrl = self.url else {
            return
        }
        self.webView.loadRequest(URLRequest(url: redirectUrl))
    }
}
