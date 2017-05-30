//
//  ViewController.swift
//  shinigami
//
//  Created by Nathan Chan on 5/23/17.g
//  Copyright © 2017 Nathan Chan. All rights reserved.
//

import UIKit
import TwitterKit

class ViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var testTextField: UITextField!
    @IBOutlet weak var testLabel: UILabel!
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        //testLabel.text = textField.text
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        testLabel.text = (textField.text as NSString?)?.replacingCharacters(in: range, with: string)
        return true
    }
    
    @IBAction func labelTapGesture(_ sender: UITapGestureRecognizer) {
        testLabel.text = "nate tapped that"
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let store = Twitter.sharedInstance().sessionStore
        /* logout everyone
        if let userID = store.session()?.userID {
            let sessions = store.existingUserSessions()
            store.logOutUserID(userID)
            print("logged out \(userID)")
        }*/
        
        if store.session() == nil {
            Twitter.sharedInstance().logIn {(session, error) in
                if let s = session {
                    print("logged in user with id \(s.userID)")
                } else {
                    print("login error \(error.debugDescription)")
                }
            }
        }
        let client = TWTRAPIClient.withCurrentUser()
        print("current userID: \(client.userID ?? "none")")
        
        /*let statusesShowEndpoint = "https://api.twitter.com/1.1/statuses/show.json"
        let params = ["id": "20"]
        var clientError : NSError?
        
        let request = client.urlRequest(withMethod: "GET", url: statusesShowEndpoint, parameters: params, error: &clientError)
        
        client.sendTwitterRequest(request) { (response, data, connectionError) -> Void in
            if connectionError != nil {
                print("Error: \(String(describing: connectionError))")
                return
            }
            
            do {
                let json = try JSONSerialization.jsonObject(with: data!, options: [])
                //print("json: \(json)")
            } catch let jsonError as NSError {
                print("json error: \(jsonError.localizedDescription)")
            }
        }*/
        
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
        
        testTextField.delegate = self
    }
}

