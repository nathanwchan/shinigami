//
//  ViewController.swift
//  shinigami
//
//  Created by Nathan Chan on 5/23/17.
//  Copyright © 2017 Nathan Chan. All rights reserved.
//

import UIKit
import TwitterKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        let logInButton = TWTRLogInButton(logInCompletion: { session, error in
            if (session != nil) {
                print("signed in as \(session?.userName ?? "unknown")");
                /*
                 let nextViewController =  yBoard.instantiateViewControllerWithIdentifier("nextView") as NextViewController
                self.presentViewController(nextViewController, animated:true, completion:nil)
                */
            } else {
                print("error: \(error?.localizedDescription ?? "unknown")");
            }
        })
        logInButton.center = self.view.center
        self.view.addSubview(logInButton)
    }
}

