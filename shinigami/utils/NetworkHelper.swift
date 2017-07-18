//
//  NetworkHelper.swift
//  shinigami
//
//  Created by Nathan Chan on 7/18/17.
//  Copyright © 2017 Nathan Chan. All rights reserved.
//

import Foundation
import TwitterKit
import SwiftyJSON
import PromiseKit

private let client = TWTRAPIClient.withCurrentUser()
private var clientError: NSError?

func getLists() -> Promise<[TWTRList]> {
    return Promise { fulfill, reject in
        let getListsEndpoint = "https://api.twitter.com/1.1/lists/ownerships.json?count=1000"
        let request = client.urlRequest(withMethod: "GET", url: getListsEndpoint, parameters: nil, error: &clientError)
        client.sendTwitterRequest(request) { (_, data, connectionError) -> Void in
            guard let data = data else {
                print("Error: \(connectionError.debugDescription)")
                if connectionError!._code == 89 {
                    // invalid or expired token
                    firebase.logEvent("twitter_error_invalid_or_expired_token")
                } else {
                    firebase.logEvent("twitter_error_lists_ownerships")
                }
                let error = NSError(domain: "TwitterError", code: 0,
                                    userInfo: [NSLocalizedDescriptionKey: connectionError.debugDescription])
                reject(error)
                return
            }
            let jsonData = JSON(data: data)
            var usersTELists = jsonData["lists"].arrayValue
                .map { TWTRList(json: $0, user: nil)! }
                .filter { $0.name.hasPrefix(Constants.listPrefix) && $0.memberCount > 0 }
            usersTELists = Array(usersTELists[0..<min(20, usersTELists.count)])
            fulfill(usersTELists)
        }
    }
}
    
func getFriends() -> Promise<[TWTRUserCustom]> {
    return Promise { fulfill, reject in
        let usersFollowingEndpoint = "https://api.twitter.com/1.1/friends/list.json?count=200"
        let request = client.urlRequest(withMethod: "GET", url: usersFollowingEndpoint, parameters: nil, error: &clientError)
        
        client.sendTwitterRequest(request) { (_, data, connectionError) -> Void in
            guard let data = data else {
                print("Error: \(connectionError.debugDescription)")
                firebase.logEvent("twitter_error_friends_list")
                let error = NSError(domain: "TwitterError", code: 0,
                                    userInfo: [NSLocalizedDescriptionKey: connectionError.debugDescription])
                reject(error)
                return
            }
            let jsonData = JSON(data: data)
            fulfill(jsonData["users"].arrayValue.map { TWTRUserCustom(json: $0)! })
        }
    }
}

func getPublicLists() -> Promise<[TWTRList]> {
    return Promise { fulfill, reject in
        let publicListsEndpoint = "https://api.twitter.com/1.1/lists/list.json?screen_name=\(Constants.publicListsTwitterAccount)"
        let request = client.urlRequest(withMethod: "GET", url: publicListsEndpoint, parameters: nil, error: &clientError)
        
        client.sendTwitterRequest(request) { (_, data, connectionError) -> Void in
            guard let data = data else {
                print("Error: \(connectionError.debugDescription)")
                firebase.logEvent("twitter_error_lists_list")
                let error = NSError(domain: "TwitterError", code: 0,
                                    userInfo: [NSLocalizedDescriptionKey: connectionError.debugDescription])
                reject(error)
                return
            }
            let jsonData = JSON(data: data)
            fulfill(jsonData.arrayValue
                .map { TWTRList(json: $0, user: nil)! }
                .filter { $0.name.hasPrefix(Constants.listPrefix) && $0.memberCount > 0 })
        }
    }
}

func getListsUsers(lists: [TWTRList]) -> Promise<[TWTRUserCustom]> {
    return Promise { fulfill, reject in
        let getUsersEndpoint = "https://api.twitter.com/1.1/users/lookup.json"
        let usersFromLists = lists.map { String($0.name.characters.dropFirst(Constants.listPrefix.characters.count)) } // drop prefix from list name to get username
        let params = [
            "screen_name": usersFromLists.joined(separator: ",")
        ]
        let request = client.urlRequest(withMethod: "GET", url: getUsersEndpoint, parameters: params, error: &clientError)
        client.sendTwitterRequest(request) { (_, data, _) -> Void in
            if let data = data {
                let jsonData = JSON(data: data)
                fulfill(jsonData.arrayValue.map { TWTRUserCustom(json: $0)! })
            }
            
            let error = NSError(domain: "TwitterError", code: 0,
                                userInfo: [NSLocalizedDescriptionKey: "data not set."])
            reject(error)
            return
        }
    }
}

func usersSearch(_ urlEncodedCurrentText: String) -> Promise<([TWTRUserCustom], URLQueryItem)> {
    return Promise { fulfill, reject in
        let usersSearchEndpoint = "https://api.twitter.com/1.1/users/search.json?q=\(urlEncodedCurrentText)"
        let request = client.urlRequest(withMethod: "GET", url: usersSearchEndpoint, parameters: nil, error: &clientError)

        client.sendTwitterRequest(request) { (response, data, connectionError) -> Void in
            guard let data = data else {
                print("Error: \(connectionError.debugDescription)")
                firebase.logEvent("twitter_error_users_search")
                let error = NSError(domain: "TwitterError", code: 0,
                                    userInfo: [NSLocalizedDescriptionKey: connectionError.debugDescription])
                reject(error)
                return
            }
            guard let url = response?.url,
                let queryItem = URLComponents(string: url.absoluteString)?.queryItems?.filter({$0.name == "q"}).first
                else {
                    print("Error in response")
                    return
            }
            let jsonData = JSON(data: data)
            let searchResultsUsers = jsonData.arrayValue.map { TWTRUserCustom.init(json: $0)! }
            fulfill(searchResultsUsers, queryItem)
        }
    }
}
