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

class TwitterNetworkManager {
    let client = TWTRAPIClient.withCurrentUser()
    var clientError: NSError?

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

    func getFriendsIds(for screenName: String) -> Promise<[String]> {
        return Promise { fulfill, reject in
            let getFollowingIdsEndpoint = "https://api.twitter.com/1.1/friends/ids.json?screen_name=\(screenName)"
            let request = client.urlRequest(withMethod: "GET", url: getFollowingIdsEndpoint, parameters: nil, error: &clientError)
            
            client.sendTwitterRequest(request) { (_, data, connectionError) -> Void in
                guard let data = data else {
                    print("Error: \(connectionError.debugDescription)")
                    firebase.logEvent("twitter_error_friends_ids")
                    let error = NSError(domain: "TwitterError", code: 0,
                                        userInfo: [NSLocalizedDescriptionKey: connectionError.debugDescription])
                    reject(error)
                    return
                }
                
                let jsonData = JSON(data: data)
                fulfill((jsonData["ids"].arrayValue).map { String(describing: $0.intValue) })
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

    func getUser(_ userID: String) -> Promise<TWTRUserCustom?> {
        return Promise { fulfill, reject in
            let getUserEndpoint = "https://api.twitter.com/1.1/users/show.json?user_id=\(userID)"
            let request = client.urlRequest(withMethod: "GET", url: getUserEndpoint, parameters: nil, error: &clientError)
            
            client.sendTwitterRequest(request) { (_, data, connectionError) -> Void in
                guard let data = data else {
                    print("Error: \(connectionError.debugDescription)")
                    firebase.logEvent("twitter_error_users_show")
                    let error = NSError(domain: "TwitterError", code: 0,
                                        userInfo: [NSLocalizedDescriptionKey: connectionError.debugDescription])
                    reject(error)
                    return
                }
                
                let jsonData = JSON(data: data)
                fulfill(TWTRUserCustom(json: jsonData))
            }
        }
    }
    
    func getListTweets(for listID: String, maxTweetID: String? = nil) -> Promise<[TWTRTweet]> {
        return Promise { fulfill, reject in
            let getListTweetsEndpoint = "https://api.twitter.com/1.1/lists/statuses.json?list_id=\(listID)"
            var params = [
                "count": "50"
            ]
            if let maxTweetID = maxTweetID {
                params["max_id"] = maxTweetID
            }
            
            let request = client.urlRequest(withMethod: "GET", url: getListTweetsEndpoint, parameters: params, error: &clientError)
            
            client.sendTwitterRequest(request) { (_, data, connectionError) -> Void in
                guard let data = data else {
                    print("Error: \(connectionError.debugDescription)")
                    firebase.logEvent("twitter_error_lists_statuses")
                    let error = NSError(domain: "TwitterError", code: 0,
                                        userInfo: [NSLocalizedDescriptionKey: connectionError.debugDescription])
                    reject(error)
                    return
                }
                
                let jsonData = JSON(data: data)
                fulfill(TWTRTweet.tweets(withJSONArray: jsonData.arrayObject) as! [TWTRTweet])
            }
        }
    }
    
    func createList(for user: TWTRUserCustom) -> Promise<TWTRList?> {
        return Promise { fulfill, reject in
            let createListEndpoint = "https://api.twitter.com/1.1/lists/create.json"
            var listName = "\(Constants.listPrefix)\(user.screenName)"
            let listNameCharacterLimit = 25
            if listName.characters.count > listNameCharacterLimit {
                listName = listName.substring(to: listName.index(listName.startIndex, offsetBy: listNameCharacterLimit))
            }
            let params = [
                "name": listName,
                "description": "List generated by @TweetseeApp",
                "mode": "private"
            ]
            let request = client.urlRequest(withMethod: "POST", url: createListEndpoint, parameters: params, error: &clientError)
            
            client.sendTwitterRequest(request) { (_, data, connectionError) -> Void in
                guard let data = data else {
                    print("Error: \(connectionError.debugDescription)")
                    firebase.logEvent("twitter_error_lists_create")
                    let error = NSError(domain: "TwitterError", code: 0,
                                        userInfo: [NSLocalizedDescriptionKey: connectionError.debugDescription])
                    reject(error)
                    return
                }
                
                let jsonData = JSON(data: data)
                fulfill(TWTRList(json: jsonData, user: user))
            }
        }
    }

    func addMembersToList(membersIdsList: [String], listID: String, forceAll: Bool) -> Promise<TWTRList> {
        return Promise { fulfill, reject in
            var updatedList: TWTRList?
            let addMembersToListEndpoint = "https://api.twitter.com/1.1/lists/members/create_all.json"
            // NOTE: this has a user_id list limit of 100 https://dev.twitter.com/rest/reference/post/lists/members/create_all
            let addMembersDispatchGroup = DispatchGroup()
            let maxMembersCount = 100
            let requestsCount = forceAll ? min(15, (membersIdsList.count / maxMembersCount) + 1) : 1
            for i in 0..<requestsCount {
                addMembersDispatchGroup.enter()
                let startIndex = maxMembersCount*i
                let endIndex = min(maxMembersCount*(i+1), membersIdsList.count)
                let params = [
                    "list_id": listID,
                    "user_id": membersIdsList[startIndex..<endIndex].joined(separator: ",")
                ]
                let request = client.urlRequest(withMethod: "POST", url: addMembersToListEndpoint, parameters: params, error: &clientError)
                
                client.sendTwitterRequest(request) { (_, data, connectionError) -> Void in
                    addMembersDispatchGroup.leave()
                    
                    guard let data = data else {
                        print("Error: \(connectionError.debugDescription)")
                        firebase.logEvent("twitter_error_lists_members_create_all")
                        return
                    }
                    
                    let jsonData = JSON(data: data)
                    if jsonData["member_count"].int == 0 {
                        let errorMessage = "Error: response to lists/members/create_all.json returned successfully, but no members were added"
                        print(errorMessage)
                        firebase.logEvent("twitter_error_lists_no_members")
                        return
                    }
                    updatedList = TWTRList(json: jsonData, user: nil)
                }
            }

            addMembersDispatchGroup.notify(queue: .main) {
                guard let updatedList = updatedList else {
                    let error = NSError(domain: "TwitterError", code: 0,
                                        userInfo: [NSLocalizedDescriptionKey: "Failed to add members to list."])
                    reject(error)
                    return
                }
                fulfill(updatedList)
            }
        }
    }
    
    func deleteList(_ listID: String) -> Promise<Void> {
        return Promise { fulfill, reject in
            let deleteListEndpoint = "https://api.twitter.com/1.1/lists/destroy.json?list_id=\(listID)"
            let request = self.client.urlRequest(withMethod: "POST", url: deleteListEndpoint, parameters: nil, error: &self.clientError)
            
            self.client.sendTwitterRequest(request) { (_, data, connectionError) -> Void in
                if data == nil {
                    print("Error: \(connectionError.debugDescription)")
                    firebase.logEvent("twitter_error_lists_destroy")
                    let error = NSError(domain: "TwitterError", code: 0,
                                        userInfo: [NSLocalizedDescriptionKey: "Failed to add members to list."])
                    reject(error)
                    return
                }
                fulfill()
            }
        }
    }
}
