/*
* Copyright (c) 2015, Tidepool Project
*
* This program is free software; you can redistribute it and/or modify it under
* the terms of the associated License, which is identical to the BSD 2-Clause
* License as published by the Open Source Initiative at opensource.org.
*
* This program is distributed in the hope that it will be useful, but WITHOUT
* ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
* FOR A PARTICULAR PURPOSE. See the License for more details.
*
* You should have received a copy of the License along with this program; if
* not, you can obtain one from Tidepool Project at tidepool.org.
*/

import Foundation
import UIKit
import Alamofire
import SwiftyJSON
import CoreData

/*
    Most of the service interface is exposed via the data classes. However, for login/logout, some set of service interface functions are needed. Much of the needed login code should be portable from Urchin.
*/

class APIConnector {
    // MARK: Properties
    
    /** ID of the currently logged-in user, or nil if nobody is logged in */
    private var _currentUserId: String?
    var currentUserId: String? {
        get {
            if (_currentUserId == nil) {
                let ad = UIApplication.sharedApplication().delegate as! AppDelegate
                if let user = DatabaseUtils.getUser(ad.managedObjectContext) {
                    _currentUserId = user.username
                }
            }
            return _currentUserId
        }
        set {
            _currentUserId = newValue
        }
    }

    // MARK: - Constants
    
    static let kSessionTokenDefaultKey = "SToken"
    static let kSessionIdHeader = "x-tidepool-session-token"

    // Error domain and codes
    static let kNutshellErrorDomain = "NutshellErrorDomain"
    static let kNoSessionTokenErrorCode = -1
    
    // Dictionary of servers and their base URLs
    static let kServers = ["Production" :   "https://api.tidepool.io",
                           "Staging" :      "https://staging-api.tidepool.io",
                           "Development" :  "https://devel-api.tidepool.io"]
    
    // Session token, acquired on login and saved in NSUserDefaults
    private var _rememberToken = true
    private var _sessionToken: String?
    var sessionToken: String? {
        set(newToken) {
            if ( newToken != nil  && _rememberToken) {
                NSUserDefaults.standardUserDefaults().setValue(newToken, forKey: APIConnector.kSessionTokenDefaultKey)
            } else {
                NSUserDefaults.standardUserDefaults().removeObjectForKey(APIConnector.kSessionTokenDefaultKey)
            }
            _sessionToken = newToken
        }
        get {
            return _sessionToken
        }
    }
    
    // Base URL for API calls, set during initialization
    var baseUrl: NSURL
    
    // MARK: Initializaion
    
    // Required initializer
    required init(baseUrl: NSURL) {
        self.baseUrl = baseUrl
        self.sessionToken = NSUserDefaults.standardUserDefaults().stringForKey(APIConnector.kSessionTokenDefaultKey)
    }
    
    
    // Convenience initializer using the server name
    convenience init(_ server: String = "Production") {
        self.init(baseUrl: NSURL(string:APIConnector.kServers[server]!)!)
    }
    
    /**
     * Logs in the user and obtains the session token for the session (stored internally)
    */
    func login(username: String, password: String, remember: Bool, completion: (Result<User>) -> (Void)) {
        // Set our endpoint for login
        let endpoint = "auth/login"
        _rememberToken = remember
        
        // Create the authorization string (user:pass base-64 encoded)
        let base64LoginString = NSString(format: "%@:%@", username, password)
            .dataUsingEncoding(NSUTF8StringEncoding)?
            .base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0))
        
        // Set our headers with the login string
        let headers = ["Authorization" : "Basic " + base64LoginString!]
        
        // Send the request and deal with the response as JSON
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        sendRequest(Method.POST, endpoint: endpoint, headers:headers).responseJSON { (request, response, result) -> (Void) in
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
            if ( result.isSuccess ) {
                // Look for the auth token
                self.sessionToken = response!.allHeaderFields[APIConnector.kSessionIdHeader] as! String?
                let json = JSON(result.value!)
                
                // Create the User object
                let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
                if let user = User.fromJSON(json, moc: appDelegate.managedObjectContext) {
                    completion(Result.Success(user))
                    self.currentUserId = username
                } else {
                    completion(Result.Failure(nil, NSError(domain: APIConnector.kNutshellErrorDomain,
                        code: -1,
                        userInfo: ["description":"Could not create user from JSON", "result":result.value!])))
                }
            } else {
                completion(Result.Failure(nil, result.error!))
            }
        }
    }
    
    func logout(completion: () -> (Void)) {
        // Clear our session token and remove entries from the db
        self.sessionToken = nil
        currentUserId = nil
        let ad = UIApplication.sharedApplication().delegate as! AppDelegate!
        DatabaseUtils.clearDatabase(ad.managedObjectContext)
        completion()
    }
    
    func refreshToken(completion: (succeeded: Bool) -> (Void)) {
        
        let endpoint = "/auth/login"
        
        if ( self.sessionToken == nil ) {
            // We don't have a session token to refresh.
            completion(succeeded: false)
            return
        }
        
        // Post the request.
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        self.sendRequest(Method.GET, endpoint:endpoint).responseJSON { (request, response, result) -> Void in
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
            if ( result.isSuccess ) {
                NSLog("Session token updated")
                self.sessionToken = response!.allHeaderFields[APIConnector.kSessionIdHeader] as! String?
                completion(succeeded: true)
            } else {
                NSLog("Session token update failed: \(result)")
                if let error = result.error as? NSError {
                    print("NSError: \(error)")
                    // TODO: handle network offline!
                }
                completion(succeeded: false)
            }
        }
    }
    
    
    /** For now this method returns the result as a JSON object. The result set can be huge, and we want processing to
     *  happen outside of this method until we have something a little less firehose-y.
     */
    func getUserData(userId: String, completion: (Result<JSON>) -> (Void)) {
        // Set our endpoint for the user data
        let endpoint = "data/" + userId;
        
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        sendRequest(Method.GET, endpoint: endpoint).responseJSON { (request, response, result) -> Void in
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
            if ( result.isSuccess ) {
                let json = JSON(result.value!)
                completion(Result.Success(json))
            } else {
                // Failure
                completion(Result.Failure(nil, result.error!))
            }
        }
    }
    
    /**
    :returns: Returns true if connected.
    Uses reachability to determine whether device is connected to a network.
    */
    class func isConnectedToNetwork() -> Bool {
        return true
    }
    
    func clearSessionToken() -> Void {
        NSUserDefaults.standardUserDefaults().removeObjectForKey(APIConnector.kSessionTokenDefaultKey)
        sessionToken = nil
    }

    // MARK: - Internal methods
    
    /**
     * Sends a request to the specified endpoint
    */
    private func sendRequest(requestType: (Alamofire.Method)? = Method.GET,
        endpoint: (String),
        parameters: [String: AnyObject]? = nil,
        headers: [String: String]? = nil) -> (Request)
    {
        let url = baseUrl.URLByAppendingPathComponent(endpoint)
        
        // Get our API headers (the session token) and add any headers supplied by the caller
        var apiHeaders = getApiHeaders()
        if ( apiHeaders != nil ) {
            if ( headers != nil ) {
                for(k, v) in headers! {
                    apiHeaders?.updateValue(v, forKey: k)
                }
            }
        } else {
            // We have no headers of our own to use- just use the caller's directly
            apiHeaders = headers
        }
        
        // Fire off the network request
        return Alamofire.request(requestType!, url, headers: apiHeaders, parameters:parameters).validate()
    }
    
    func getApiHeaders() -> [String: String]? {
        if ( sessionToken != nil ) {
            return [APIConnector.kSessionIdHeader : sessionToken!]
        }
        return nil
    }
 }