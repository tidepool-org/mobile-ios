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
    
    fileprivate let kSessionTokenDefaultKey = "SToken"
    fileprivate let kCurrentServiceDefaultKey = "SCurrentService"
    fileprivate let kSessionIdHeader = "x-tidepool-session-token"

    // Error domain and codes
    fileprivate let kNutshellErrorDomain = "NutshellErrorDomain"
    fileprivate let kNoSessionTokenErrorCode = -1
    
    // Session token, acquired on login and saved in NSUserDefaults
    // TODO: save in database?
    fileprivate var _sessionToken: String?
    var sessionToken: String? {
        set(newToken) {
            if ( newToken != nil ) {
                UserDefaults.standard.setValue(newToken, forKey:kSessionTokenDefaultKey)
            } else {
                UserDefaults.standard.removeObject(forKey: kSessionTokenDefaultKey)
            }
            UserDefaults.standard.synchronize()
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
    fileprivate let kDefaultServerName = "Production"

    fileprivate var _currentService: String?
    var currentService: String? {
        set(newService) {
            if newService == nil {
                UserDefaults.standard.removeObject(forKey: kCurrentServiceDefaultKey)
                UserDefaults.standard.synchronize()
                _currentService = nil
            } else {
                if kServers[newService!] != nil {
                    UserDefaults.standard.setValue(newService, forKey: kCurrentServiceDefaultKey)
                    UserDefaults.standard.synchronize()
                    _currentService = newService
                }
            }
        }
        get {
            if _currentService == nil {
                if let service = UserDefaults.standard.string(forKey: kCurrentServiceDefaultKey) {
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
    var baseUrl: URL?
 
    // Reachability object, valid during lifetime of this APIConnector, and convenience function that uses this
    // Register for ReachabilityChangedNotification to monitor reachability changes             
    var reachability: Reachability?
    func isConnectedToNetwork() -> Bool {
        if let reachability = reachability {
            return reachability.isReachable
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
        self.baseUrl = URL(string: kServers[currentService!]!)!
        NSLog("Using service: \(self.baseUrl)")
        self.sessionToken = UserDefaults.standard.string(forKey: kSessionTokenDefaultKey)
        if let reachability = reachability {
            reachability.stopNotifier()
        }
        self.reachability = Reachability()
        
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
    
    func switchToServer(_ serverName: String) {
        if (currentService != serverName) {
            currentService = serverName
            // refresh connector since there is a new service...
            _ = configure()
            NSLog("Switched to \(serverName) server")
        }
    }
    
    /// Logs in the user and obtains the session token for the session (stored internally)
    func login(_ username: String, password: String, completion: @escaping (Result<User>) -> (Void)) {
        // Clear in case it was set while logged out...
        self.lastNetworkError = nil
        // Set our endpoint for login
        let endpoint = "auth/login"
        
        // Create the authorization string (user:pass base-64 encoded)
        let base64LoginString = NSString(format: "%@:%@", username, password)
            .data(using: String.Encoding.utf8.rawValue)?
            .base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
        
        // Set our headers with the login string
        let headers = ["Authorization" : "Basic " + base64LoginString!]
        
        // Send the request and deal with the response as JSON
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        sendRequest(.post, endpoint: endpoint, headers:headers).responseJSON { response in
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
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
                    completion(Result.success(user))
                } else {
                    APIConnector.connector().trackMetric("Log In Failed")
                    NutDataController.controller().logoutUser()
                    completion(Result.failure(NSError(domain: self.kNutshellErrorDomain,
                        code: -1,
                        userInfo: ["description":"Could not create user from JSON", "result":response.result.value!])))
                }
            } else {
                APIConnector.connector().trackMetric("Log In Failed")
                NutDataController.controller().logoutUser()
                completion(Result.failure(response.result.error!))
            }
        }
    }
 
    func fetchProfile(_ completion: @escaping (Result<JSON>) -> (Void)) {
        // Set our endpoint for the user profile
        // format is like: https://api.tidepool.org/metadata/f934a287c4/profile
        let endpoint = "metadata/" + NutDataController.controller().currentUserId! + "/profile"
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        sendRequest(.get, endpoint: endpoint).responseJSON { response in
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            if ( response.result.isSuccess ) {
                let json = JSON(response.result.value!)
                completion(Result.success(json))
            } else {
                // Failure
                completion(Result.failure(response.result.error!))
            }
        }
    }
    
    // When offline just stash metrics in metricsCache array
    fileprivate var metricsCache: [String] = []
    // Used so we only have one metric send in progress at a time, to help balance service load a bit...
    fileprivate var metricSendInProgress = false
    func trackMetric(_ metric: String, flushBuffer: Bool = false) {
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
        sendRequest(.get, endpoint: endpoint, parameters: parameters as [String : AnyObject]?).responseJSON { response in
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
    func logout(_ completion: () -> (Void)) {
        // Clear our session token and remove entries from the db
        APIConnector.connector().trackMetric("Logged Out", flushBuffer: true)
        self.lastNetworkError = nil
        self.sessionToken = nil
        NutDataController.controller().logoutUser()
        completion()
    }
    
    func refreshToken(_ completion: @escaping (_ succeeded: Bool) -> (Void)) {
        
        let endpoint = "/auth/login"
        
        if self.sessionToken == nil || NutDataController.controller().currentUserId == nil {
            // We don't have a session token to refresh.
            completion(false)
            return
        }
        
        // Post the request.
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        self.sendRequest(.get, endpoint:endpoint).responseJSON { response in
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            if ( response.result.isSuccess ) {
                NSLog("Session token updated")
                self.sessionToken = response.response!.allHeaderFields[self.kSessionIdHeader] as! String?
                completion(true)
            } else {
                NSLog("Session token update failed: \(response.result)")
                if let error = response.result.error {
                    print("NSError: \(error)")
                    // TODO: handle network offline!
                }
                completion(false)
            }
        }
    }
    
    /** For now this method returns the result as a JSON object. The result set can be huge, and we want processing to
     *  happen outside of this method until we have something a little less firehose-y.
     */
    func getUserData(_ completion: @escaping (Result<JSON>) -> (Void)) {
        // Set our endpoint for the user data
        let endpoint = "data/" + NutDataController.controller().currentUserId!;
        
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        sendRequest(.get, endpoint: endpoint).responseJSON { response in
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            if ( response.result.isSuccess ) {
                let json = JSON(response.result.value!)
                completion(Result.success(json))
            } else {
                // Failure
                completion(Result.failure(response.result.error!))
            }
        }
    }
    
    func getReadOnlyUserData(_ startDate: Date? = nil, endDate: Date? = nil,  objectTypes: String = "smbg,bolus,cbg,wizard,basal", completion: @escaping (Result<JSON>) -> (Void)) {
        // Set our endpoint for the user data
        // TODO: centralize define of read-only events!
        // request format is like: https://api.tidepool.org/data/f934a287c4?endDate=2015-11-17T08%3A00%3A00%2E000Z&startDate=2015-11-16T12%3A00%3A00%2E000Z&type=smbg%2Cbolus%2Ccbg%2Cwizard%2Cbasal
        let endpoint = "data/" + NutDataController.controller().currentUserId!
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
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
        sendRequest(.get, endpoint: endpoint, parameters: parameters as [String : AnyObject]?).responseJSON { response in
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
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
                        completion(Result.failure(NSError(domain: self.kNutshellErrorDomain,
                            code: statusCode,
                            userInfo: nil)))
                    }
                }
                if validResult {
                    completion(Result.success(json))
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
                completion(Result.failure(response.result.error!))
            }
        }
    }
    
    

    func clearSessionToken() -> Void {
        UserDefaults.standard.removeObject(forKey: kSessionTokenDefaultKey)
        UserDefaults.standard.synchronize()
        sessionToken = nil
    }

    // MARK: - Internal methods
    
    /**
     * Sends a request to the specified endpoint
    */
    fileprivate func sendRequest(_ requestType: HTTPMethod? = .get,
        endpoint: (String),
        parameters: [String: AnyObject]? = nil,
        headers: [String: String]? = nil) -> (DataRequest)
    {
        let url = baseUrl!.appendingPathComponent(endpoint)
        
        // Get our API headers (the session token) and add any headers supplied by the caller
        var apiHeaders = getApiHeaders()
        if ( apiHeaders != nil ) {
            if ( headers != nil ) {
                for(k, v) in headers! {
                    _ = apiHeaders?.updateValue(v, forKey: k)
                }
            }
        } else {
            // We have no headers of our own to use- just use the caller's directly
            apiHeaders = headers
        }
        
        // Fire off the network request
        return Alamofire.request(url, method: requestType!, parameters: parameters, headers: apiHeaders).validate()
    }
    
    func getApiHeaders() -> [String: String]? {
        if ( sessionToken != nil ) {
            return [kSessionIdHeader : sessionToken!]
        }
        return nil
    }
    
    func doUpload(_ body: Data, completion: @escaping (_ error: NSError?, _ duplicateSampleCount: Int) -> (Void)) -> (Void) {
        DDLogVerbose("trace")
        
        var error: NSError?
        
        defer {
            if error != nil {
                DDLogError("Upload failed: \(error), \(error?.userInfo)")
                
                completion(error, 0)
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
        
        let handleRequestCompletion = { (response: URLResponse!, data: Data!, requestError: NSError!) -> Void in
            // TODO: Per this Trello card (https://trello.com/c/ixKq9mHM/102-ios-bg-uploader-when-updating-uploader-to-new-upload-service-api-consider-that-the-duplicate-item-indices-may-be-going-away), this dup item indices response may be going away in future version of upload service, so we may need to revisit this when we move to the upload service API.
            var error = requestError
            var duplicateSampleCount = 0
            if error == nil {
                if let httpResponse = response as? HTTPURLResponse {
                    if data != nil {
                        let statusCode = httpResponse.statusCode
                        let duplicateItemIndices: NSArray? = (try? JSONSerialization.jsonObject(with: data!, options: [])) as? NSArray
                        duplicateSampleCount = duplicateItemIndices?.count ?? 0
                        
                        if statusCode >= 400 && statusCode < 600 {
                            let dataString = NSString(data: data!, encoding: String.Encoding.utf8.rawValue)! as String
                            error = NSError(domain: "APIConnect-doUpload", code: -2, userInfo: [NSLocalizedDescriptionKey:"Upload failed with status code: \(statusCode), error message: \(dataString)"])
                        }
                    }
                }
            }
            
            if error != nil {
                DDLogError("Upload failed: \(error), \(error?.userInfo)")
            }
            
            completion(error, duplicateSampleCount)
        }

        uploadRequest("POST", urlExtension: urlExtension, headerDict: headerDict, body: body, preRequest: preRequest, subdomainRootOverride: "uploads", completion: handleRequestCompletion as! (URLResponse?, Data?, NSError?) -> Void)
    }


    func uploadRequest(_ method: String, urlExtension: String, headerDict: [String: String], body: Data?, preRequest: () -> Void, subdomainRootOverride: String = "api", completion: @escaping (_ response: URLResponse?, _ data: Data?, _ error: NSError?) -> Void) {
        
        if (self.isConnectedToNetwork()) {
            preRequest()
            
            let baseURL = kServers[currentService!]!
            let baseUrlWithSubdomainRootOverride = baseURL.replacingOccurrences(of: "api", with: subdomainRootOverride)
            var urlString = baseUrlWithSubdomainRootOverride + urlExtension
            urlString = urlString.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!
            let url = URL(string: urlString)
            let request = NSMutableURLRequest(url: url!)
            request.httpMethod = method
            for (field, value) in headerDict {
                request.setValue(value, forHTTPHeaderField: field)
            }
            request.httpBody = body
            
            let task = URLSession.shared.dataTask(with: request as URLRequest) {
                (data, response, error) -> Void in
                DispatchQueue.main.async(execute: {
                    completion(response, data, (error as? NSError))
                })
                return
            }
            task.resume()
        } else {
            DDLogInfo("Not connected to network")
        }
    }
    
 }
