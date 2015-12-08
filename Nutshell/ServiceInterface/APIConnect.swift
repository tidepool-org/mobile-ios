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
    
    
    private var _currentUser: User?
    var currentUser: User? {
        get {
            if _currentUser == nil {
                let ad = UIApplication.sharedApplication().delegate as! AppDelegate
                if let user = DatabaseUtils.getUser(ad.managedObjectContext) {
                    _currentUser = user
                }
            }
            return _currentUser
        }
        set(newUser) {
            if newUser != _currentUser {
                DatabaseUtils.updateUser(_currentUser, newUser: newUser)
                _currentUser = newUser
                if newUser != nil {
                    NSLog("Set currentUser, name: \(newUser!.username), id: \(newUser!.userid)")
                } else {
                    NSLog("Cleared currentUser!")
                }
            }
        }
    }
    
    // MARK: - Constants
    
    static let kSessionTokenDefaultKey = "SToken"
    static let kCurrentServiceDefaultKey = "SCurrentService"
    static let kSessionIdHeader = "x-tidepool-session-token"

    // Error domain and codes
    static let kNutshellErrorDomain = "NutshellErrorDomain"
    static let kNoSessionTokenErrorCode = -1
    
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
    
    // Dictionary of servers and their base URLs
    static let kServers = [
        "Production" :   "https://api.tidepool.org",
        "Staging" :      "https://stg-api.tidepool.org",
        "Development" :  "https://dev-api.tidepool.org",
    ]
    static let kDefaultServerName = "Production"

    static var _currentService: String?
    static var currentService: String? {
        set(newService) {
            if newService == nil {
                NSUserDefaults.standardUserDefaults().removeObjectForKey(APIConnector.kCurrentServiceDefaultKey)
                _currentService = nil
            } else {
                if APIConnector.kServers[newService!] != nil {
                    NSUserDefaults.standardUserDefaults().setValue(newService, forKey: APIConnector.kCurrentServiceDefaultKey)
                    _currentService = newService
                }
            }
        }
        get {
            if _currentService == nil {
                if let service = NSUserDefaults.standardUserDefaults().stringForKey(APIConnector.kCurrentServiceDefaultKey) {
                    _currentService = service
                }
            }
            if _currentService == nil || APIConnector.kServers[_currentService!] == nil {
                _currentService = APIConnector.kDefaultServerName
            }
            return _currentService
        }
    }
    
    // Base URL for API calls, set during initialization
    var baseUrl: NSURL
 
    // Reachability object, valid during lifetime of this APIConnector, and convenience function that uses this
    // Register for ReachabilityChangedNotification to monitor reachability changes             
    var reachability: Reachability?
    func isConnectedToNetwork() -> Bool {
        if let reachability = reachability {
            return reachability.isReachable()
        } else {
            NSLog("Error: reachability object not configured!")
            return true
        }
    }
    
    // MARK: Initialization
    
    // Required initializer
    init() {
        self.baseUrl = NSURL(string:APIConnector.kServers[APIConnector.currentService!]!)!
        NSLog("Using service: \(self.baseUrl)")
        self.sessionToken = NSUserDefaults.standardUserDefaults().stringForKey(APIConnector.kSessionTokenDefaultKey)
        do {
            let reachability = try Reachability.reachabilityForInternetConnection()
            self.reachability = reachability
        } catch ReachabilityError.FailedToCreateWithAddress(let address) {
            NSLog("Unable to create\nReachability with address:\n\(address)")
        } catch {
            NSLog("Other reachability error!")
        }
        
        do {
            try reachability?.startNotifier()
        } catch {
            NSLog("Error: Unable to start notifier!")
        }
    }
    
    deinit {
        reachability?.stopNotifier()
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
                    self.currentUser = user
                    completion(Result.Success(user))
                } else {
                    self.currentUser = nil
                    completion(Result.Failure(nil, NSError(domain: APIConnector.kNutshellErrorDomain,
                        code: -1,
                        userInfo: ["description":"Could not create user from JSON", "result":result.value!])))
                }
            } else {
                self.currentUser = nil
                completion(Result.Failure(nil, result.error!))
            }
        }
    }
    
    func logout(completion: () -> (Void)) {
        // Clear our session token and remove entries from the db
        self.sessionToken = nil
        currentUser = nil
        let ad = UIApplication.sharedApplication().delegate as! AppDelegate!
        DatabaseUtils.clearDatabase(ad.managedObjectContext)
        completion()
    }
    
    func refreshToken(completion: (succeeded: Bool) -> (Void)) {
        
        let endpoint = "/auth/login"
        
        if self.sessionToken == nil || self.currentUser == nil {
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
    func getUserData(completion: (Result<JSON>) -> (Void)) {
        // Set our endpoint for the user data
        let endpoint = "data/" + currentUser!.userid!;
        
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
    
    func getReadOnlyUserData(startDate: String, endDate: String,completion: (Result<JSON>) -> (Void)) {
        // Set our endpoint for the user data
        // TODO: centralize define of read-only events!
        let endpoint = "data/" + currentUser!.userid! //+ "?type=smbg,bolus,cbg,wizard,basal&startdate=" + startDate + "&enddate=" + endDate
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        // TODO: Alamofire isn't escaping the periods, but service appears to expect this... right now I have Alamofire modified to do this.
        // TODO: If there is no data returned, I get a failure case with status code 200, and error FAILURE: Error Domain=NSCocoaErrorDomain Code=3840 "Invalid value around character 0." UserInfo={NSDebugDescription=Invalid value around character 0.} ] Maybe an Alamofire issue?
        //let escapedStart = startDate.stringByReplacingOccurrencesOfString(".", withString: "%2E")
        //let escapedEnd = endDate.stringByReplacingOccurrencesOfString(".", withString: "%2E")
        sendRequest(Method.GET, endpoint: endpoint, parameters: ["type":"smbg,bolus,cbg,wizard,basal", "startDate": startDate, "endDate": endDate]).responseJSON { (request, response, result) -> Void in
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
            if ( result.isSuccess ) {
                let json = JSON(result.value!)
                completion(Result.Success(json))
            } else {
                // Failure: Note we get here when no data is found as well!
                completion(Result.Failure(nil, result.error!))
            }
        }
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