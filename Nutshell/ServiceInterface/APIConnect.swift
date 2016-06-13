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
import CocoaLumberjack

/// APIConnector is a singleton object with the main responsibility of communicating to the Tidepool service:
/// - Given a username and password, login.
/// - Can refresh connection.
/// - Fetches Tidepool data.
/// - Provides online/offline statis.
class APIConnector {
    
    static var _connector: APIConnector?
    /// Supports a singleton for the application.
    class func connector() -> APIConnector {
        if _connector == nil {
        _connector = APIConnector()
        }
        return _connector!
    }
    
    // MARK: - Constants
    
    private let kSessionTokenDefaultKey = "SToken"
    private let kCurrentServiceDefaultKey = "SCurrentService"
    private let kSessionIdHeader = "x-tidepool-session-token"

    // Error domain and codes
    private let kNutshellErrorDomain = "NutshellErrorDomain"
    private let kNoSessionTokenErrorCode = -1
    
    // Session token, acquired on login and saved in NSUserDefaults
    // TODO: save in database?
    private var _sessionToken: String?
    var sessionToken: String? {
        set(newToken) {
            if ( newToken != nil ) {
                NSUserDefaults.standardUserDefaults().setValue(newToken, forKey:kSessionTokenDefaultKey)
            } else {
                NSUserDefaults.standardUserDefaults().removeObjectForKey(kSessionTokenDefaultKey)
            }
            NSUserDefaults.standardUserDefaults().synchronize()
            _sessionToken = newToken
        }
        get {
            return _sessionToken
        }
    }
    
    // Dictionary of servers and their base URLs
    let kServers = [
        "Production" :   "https://api.tidepool.org",
        "Staging" :      "https://stg-api.tidepool.org",
        "Development" :  "https://dev-api.tidepool.org",
    ]
    private let kDefaultServerName = "Production"

    private var _currentService: String?
    var currentService: String? {
        set(newService) {
            if newService == nil {
                NSUserDefaults.standardUserDefaults().removeObjectForKey(kCurrentServiceDefaultKey)
                NSUserDefaults.standardUserDefaults().synchronize()
                _currentService = nil
            } else {
                if kServers[newService!] != nil {
                    NSUserDefaults.standardUserDefaults().setValue(newService, forKey: kCurrentServiceDefaultKey)
                    NSUserDefaults.standardUserDefaults().synchronize()
                    _currentService = newService
                }
            }
        }
        get {
            if _currentService == nil {
                if let service = NSUserDefaults.standardUserDefaults().stringForKey(kCurrentServiceDefaultKey) {
                    _currentService = service
                }
            }
            if _currentService == nil || kServers[_currentService!] == nil {
                _currentService = kDefaultServerName
            }
            return _currentService
        }
    }
    
    // Base URL for API calls, set during initialization
    var baseUrl: NSURL?
 
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

    func serviceAvailable() -> Bool {
        if !isConnectedToNetwork() || sessionToken == nil {
            return false
        }
        return true
    }

    // MARK: Initialization
    
    /// Creator of APIConnector must call this function after init!
    func configure() -> APIConnector {
        HealthKitDataUploader.sharedInstance.uploadHandler = self.doUpload
        self.baseUrl = NSURL(string: kServers[currentService!]!)!
        NSLog("Using service: \(self.baseUrl)")
        self.sessionToken = NSUserDefaults.standardUserDefaults().stringForKey(kSessionTokenDefaultKey)
        if let reachability = reachability {
            reachability.stopNotifier()
        }
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
        return self
    }
    
    deinit {
        reachability?.stopNotifier()
    }
    
    func switchToServer(serverName: String) {
        if (currentService != serverName) {
            currentService = serverName
            // refresh connector since there is a new service...
            configure()
            NSLog("Switched to \(serverName) server")
        }
    }
    
    /// Logs in the user and obtains the session token for the session (stored internally)
    func login(username: String, password: String, completion: (Result<User, NSError>) -> (Void)) {
        // Clear in case it was set while logged out...
        self.lastNetworkError = nil
        // Set our endpoint for login
        let endpoint = "auth/login"
        
        // Create the authorization string (user:pass base-64 encoded)
        let base64LoginString = NSString(format: "%@:%@", username, password)
            .dataUsingEncoding(NSUTF8StringEncoding)?
            .base64EncodedStringWithOptions(NSDataBase64EncodingOptions(rawValue: 0))
        
        // Set our headers with the login string
        let headers = ["Authorization" : "Basic " + base64LoginString!]
        
        // Send the request and deal with the response as JSON
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        sendRequest(Method.POST, endpoint: endpoint, headers:headers).responseJSON { response in
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
            if ( response.result.isSuccess ) {
                // Look for the auth token
                self.sessionToken = response.response!.allHeaderFields[self.kSessionIdHeader] as! String?
                let json = JSON(response.result.value!)
                
                // Create the User object
                // TODO: Should this call be made in NutshellDataController?
                let moc = NutDataController.controller().mocForCurrentUser()
                if let user = User.fromJSON(json, moc: moc) {
                    NutDataController.controller().loginUser(user)
                    APIConnector.connector().trackMetric("Logged In")
                    completion(Result.Success(user))
                } else {
                    APIConnector.connector().trackMetric("Log In Failed")
                    NutDataController.controller().logoutUser()
                    completion(Result.Failure(NSError(domain: self.kNutshellErrorDomain,
                        code: -1,
                        userInfo: ["description":"Could not create user from JSON", "result":response.result.value!])))
                }
            } else {
                APIConnector.connector().trackMetric("Log In Failed")
                NutDataController.controller().logoutUser()
                completion(Result.Failure(response.result.error!))
            }
        }
    }
 
    func fetchProfile(completion: (Result<JSON, NSError>) -> (Void)) {
        // Set our endpoint for the user profile
        // format is like: https://api.tidepool.org/metadata/f934a287c4/profile
        let endpoint = "metadata/" + NutDataController.controller().currentUserId! + "/profile"
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        sendRequest(Method.GET, endpoint: endpoint).responseJSON { response in
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
            if ( response.result.isSuccess ) {
                let json = JSON(response.result.value!)
                completion(Result.Success(json))
            } else {
                // Failure
                completion(Result.Failure(response.result.error!))
            }
        }
    }
    
    // When offline just stash metrics in metricsCache array
    private var metricsCache: [String] = []
    // Used so we only have one metric send in progress at a time, to help balance service load a bit...
    private var metricSendInProgress = false
    func trackMetric(metric: String, flushBuffer: Bool = false) {
        // Set our endpoint for the event tracking
        // Format: https://api.tidepool.org/metrics/thisuser/urchin%20-%20Remember%20Me%20Used?source=urchin&sourceVersion=1.1
        // Format: https://api.tidepool.org/metrics/thisuser/nutshell-Viewed%20Hamburger%20Menu?source=nutshell&sourceVersion=0%2E8%2E1

        metricsCache.append(metric)
        if !serviceAvailable() || (metricSendInProgress && !flushBuffer) {
            //NSLog("Offline: trackMetric stashed: \(metric)")
            return
        }
        
        let nextMetric = metricsCache.removeFirst()
        let endpoint = "metrics/thisuser/nutshell-" + nextMetric
        let parameters = ["source": "nutshell", "sourceVersion": UIApplication.appVersion()]
        metricSendInProgress = true
        sendRequest(Method.GET, endpoint: endpoint, parameters: parameters).responseJSON { response in
            self.metricSendInProgress = false
            if let theResponse = response.response {
                let statusCode = theResponse.statusCode
                if statusCode == 200 {
                    NSLog("Tracked metric: \(nextMetric)")
                    if !self.metricsCache.isEmpty {
                        self.trackMetric(self.metricsCache.removeFirst(), flushBuffer: flushBuffer)
                    }
                } else {
                    NSLog("Failed status code: \(statusCode) for tracking metric: \(metric)")
                    self.lastNetworkError = statusCode
                    if let error = response.result.error {
                        NSLog("NSError: \(error)")
                    }
                }
            } else {
                NSLog("Invalid response for tracking metric")
            }
        }
    }
    
    /// Remembers last network error for authorization problem monitoring
    var lastNetworkError: Int?
    func logout(completion: () -> (Void)) {
        // Clear our session token and remove entries from the db
        APIConnector.connector().trackMetric("Logged Out", flushBuffer: true)
        self.lastNetworkError = nil
        self.sessionToken = nil
        NutDataController.controller().logoutUser()
        completion()
    }
    
    func refreshToken(completion: (succeeded: Bool) -> (Void)) {
        
        let endpoint = "/auth/login"
        
        if self.sessionToken == nil || NutDataController.controller().currentUserId == nil {
            // We don't have a session token to refresh.
            completion(succeeded: false)
            return
        }
        
        // Post the request.
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        self.sendRequest(Method.GET, endpoint:endpoint).responseJSON { response in
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
            if ( response.result.isSuccess ) {
                NSLog("Session token updated")
                self.sessionToken = response.response!.allHeaderFields[self.kSessionIdHeader] as! String?
                completion(succeeded: true)
            } else {
                NSLog("Session token update failed: \(response.result)")
                if let error = response.result.error {
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
    func getUserData(completion: (Result<JSON, NSError>) -> (Void)) {
        // Set our endpoint for the user data
        let endpoint = "data/" + NutDataController.controller().currentUserId!;
        
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        sendRequest(Method.GET, endpoint: endpoint).responseJSON { response in
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
            if ( response.result.isSuccess ) {
                let json = JSON(response.result.value!)
                completion(Result.Success(json))
            } else {
                // Failure
                completion(Result.Failure(response.result.error!))
            }
        }
    }
    
    func getReadOnlyUserData(startDate: NSDate? = nil, endDate: NSDate? = nil,  objectTypes: String = "smbg,bolus,cbg,wizard,basal", completion: (Result<JSON, NSError>) -> (Void)) {
        // Set our endpoint for the user data
        // TODO: centralize define of read-only events!
        // request format is like: https://api.tidepool.org/data/f934a287c4?endDate=2015-11-17T08%3A00%3A00%2E000Z&startDate=2015-11-16T12%3A00%3A00%2E000Z&type=smbg%2Cbolus%2Ccbg%2Cwizard%2Cbasal
        let endpoint = "data/" + NutDataController.controller().currentUserId!
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
        // TODO: If there is no data returned, I get a failure case with status code 200, and error FAILURE: Error Domain=NSCocoaErrorDomain Code=3840 "Invalid value around character 0." UserInfo={NSDebugDescription=Invalid value around character 0.} ] Maybe an Alamofire issue?
        var parameters: Dictionary = ["type": objectTypes]
        if let startDate = startDate {
            // NOTE: start date is excluded (i.e., dates > start date)
            parameters.updateValue(NutUtils.dateToJSON(startDate), forKey: "startDate")
        }
        if let endDate = endDate {
            // NOTE: end date is included (i.e., dates <= end date)
            parameters.updateValue(NutUtils.dateToJSON(endDate), forKey: "endDate")
        }
        sendRequest(Method.GET, endpoint: endpoint, parameters: parameters).responseJSON { response in
            UIApplication.sharedApplication().networkActivityIndicatorVisible = false
            if (response.result.isSuccess) {
                let json = JSON(response.result.value!)
                var validResult = true
                if let status = json["status"].number {
                    let statusCode = Int(status)
                    NSLog("getReadOnlyUserData includes status field: \(statusCode)")
                    // TODO: determine if any status is indicative of failure here! Note that if call was successful, there will be no status field in the json result. The only verified error response is 403 which happens when we pass an invalid token.
                    if statusCode == 401 || statusCode == 403 {
                        validResult = false
                        self.lastNetworkError = statusCode
                        completion(Result.Failure(NSError(domain: self.kNutshellErrorDomain,
                            code: statusCode,
                            userInfo: nil)))
                    }
                }
                if validResult {
                    completion(Result.Success(json))
                }
            } else {
                // Failure: typically, no data were found:
                // Error Domain=NSCocoaErrorDomain Code=3840 "Invalid value around character 0." UserInfo={NSDebugDescription=Invalid value around character 0.}
                if let theResponse = response.response {
                    let statusCode = theResponse.statusCode
                    if statusCode != 200 {
                        NSLog("Failure status code: \(statusCode) for getReadOnlyUserData")
                        APIConnector.connector().trackMetric("Tidepool Data Fetch Failure - Code " + String(statusCode))
                    }
                    // Otherwise, just indicates no data were found...
                } else {
                    NSLog("Invalid response for getReadOnlyUserData metric")
                }
                completion(Result.Failure(response.result.error!))
            }
        }
    }
    
    

    func clearSessionToken() -> Void {
        NSUserDefaults.standardUserDefaults().removeObjectForKey(kSessionTokenDefaultKey)
        NSUserDefaults.standardUserDefaults().synchronize()
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
        let url = baseUrl!.URLByAppendingPathComponent(endpoint)
        
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
            return [kSessionIdHeader : sessionToken!]
        }
        return nil
    }
    
    func doUpload(body: NSData, completion: (error: NSError?, duplicateSampleCount: Int) -> (Void)) {
        DDLogVerbose("trace")
        
        var error: NSError?
        
        defer {
            if error != nil {
                DDLogError("Upload failed: \(error), \(error?.userInfo)")
                
                completion(error: error, duplicateSampleCount: 0)
            }
        }
        
        guard self.isConnectedToNetwork() else {
            error = NSError(domain: "APIConnect-doUpload", code: -1, userInfo: [NSLocalizedDescriptionKey:"Unable to upload, not connected to network"])
            return
        }
        
        guard let currentUserId = NutDataController.controller().currentUserId else {
            error = NSError(domain: "APIConnect-doUpload", code: -2, userInfo: [NSLocalizedDescriptionKey:"Unable to upload, no user is logged in"])
            return
        }

        let urlExtension = "/data/" + currentUserId
        let headerDict = ["x-tidepool-session-token":"\(sessionToken!)", "Content-Type":"application/json"]
        let preRequest = { () -> Void in }
        
        let handleRequestCompletion = { (response: NSURLResponse!, data: NSData!, requestError: NSError!) -> Void in
            // TODO: Per this Trello card (https://trello.com/c/ixKq9mHM/102-ios-bg-uploader-when-updating-uploader-to-new-upload-service-api-consider-that-the-duplicate-item-indices-may-be-going-away), this dup item indices response may be going away in future version of upload service, so we may need to revisit this when we move to the upload service API.
            var error = requestError
            var duplicateSampleCount = 0
            if error == nil {
                if let httpResponse = response as? NSHTTPURLResponse {
                    if data != nil {
                        let statusCode = httpResponse.statusCode
                        let duplicateItemIndices: NSArray? = (try? NSJSONSerialization.JSONObjectWithData(data!, options: [])) as? NSArray
                        duplicateSampleCount = duplicateItemIndices?.count ?? 0
                        
                        if statusCode >= 400 && statusCode < 600 {
                            let dataString = NSString(data: data!, encoding: NSUTF8StringEncoding)! as String
                            error = NSError(domain: "APIConnect-doUpload", code: -2, userInfo: [NSLocalizedDescriptionKey:"Upload failed with status code: \(statusCode), error message: \(dataString)"])
                        }
                    }
                }
            }
            
            if error != nil {
                DDLogError("Upload failed: \(error), \(error?.userInfo)")
            }
            
            completion(error: error, duplicateSampleCount: duplicateSampleCount)
        }

        uploadRequest("POST", urlExtension: urlExtension, headerDict: headerDict, body: body, preRequest: preRequest, subdomainRootOverride: "uploads", completion: handleRequestCompletion)
    }


    func uploadRequest(method: String, urlExtension: String, headerDict: [String: String], body: NSData?, preRequest: () -> Void, subdomainRootOverride: String = "api", completion: (response: NSURLResponse!, data: NSData!, error: NSError!) -> Void) {
        
        if (self.isConnectedToNetwork()) {
            preRequest()
            
            let baseURL = kServers[currentService!]!
            let baseUrlWithSubdomainRootOverride = baseURL.stringByReplacingOccurrencesOfString("api", withString: subdomainRootOverride)
            var urlString = baseUrlWithSubdomainRootOverride + urlExtension
            urlString = urlString.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())!
            let url = NSURL(string: urlString)
            let request = NSMutableURLRequest(URL: url!)
            request.HTTPMethod = method
            for (field, value) in headerDict {
                request.setValue(value, forHTTPHeaderField: field)
            }
            request.HTTPBody = body
            
            let task = NSURLSession.sharedSession().dataTaskWithRequest(
                request,
                completionHandler: {
                    (data, response, error) -> Void in
                    dispatch_async(dispatch_get_main_queue(), {
                        completion(response: response, data: data, error: error)
                    })
            })
            task.resume()
        } else {
            DDLogInfo("Not connected to network")
        }
    }
    
 }