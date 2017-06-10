//
//  GoogleAnalytics.swift
//  shinigami
//
//  Created by Nathan Chan on 6/9/17.
//  Copyright © 2017 Nathan Chan. All rights reserved.
//

import Foundation
import Google

class GA {
    func logScreen (name: String){
        guard let tracker = GAI.sharedInstance().defaultTracker else { return }
        tracker.set(kGAIScreenName, value: name)

        guard let builder = GAIDictionaryBuilder.createScreenView() else { return }
        tracker.send(builder.build() as [NSObject : AnyObject])
    }

    func logAction(category: String, action: String, label: String? = nil) {
        let tracker = GAI.sharedInstance().defaultTracker
        tracker?.set(kGAIEventAction, value: action)
        
        let build = (GAIDictionaryBuilder.createEvent(withCategory: category, action: action, label: label, value: nil).build() as NSDictionary) as! [AnyHashable: Any]
        tracker?.send(build)
    }
}
