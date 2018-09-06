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

protocol NoteAPIWatcher {
    // Notify caller that a cell has been updated...
    func loadingNotes(_ loading: Bool)
    func endRefresh()
    func addNotes(_ notes: [BlipNote])
    func addComments(_ notes: [BlipNote], messageId: String)
    func postComplete(_ note: BlipNote)
    func deleteComplete(_ note: BlipNote)
    func updateComplete(_ originalNote: BlipNote, editedNote: BlipNote)
}

protocol UsersFetchAPIWatcher {
    func viewableUsers(_ userIds: [String])
}

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
    fileprivate let kSessionTokenHeaderId = "X-Tidepool-Session-Token"
    fileprivate let kSessionTokenResponseId = "x-tidepool-session-token"

    // Error domain and codes
    fileprivate let kTidepoolMobileErrorDomain = "TidepoolMobileErrorDomain"
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
        "Development" :  "https://dev-api.tidepool.org",
        "Staging" :      "https://stg-api.tidepool.org",
        "Integration" :  "https://int-api.tidepool.org",
        //"Production" :   "https://api.tidepool.org"
    ]
    let kSortedServerNames = [
        "Development",
        "Staging",
        "Integration",
        //"Production"
    ]
    //fileprivate let kDefaultServerName = "Production"
    fileprivate let kDefaultServerName = "Integration"

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
                    // don't set a service this build does not support
                    if kServers[service] != nil {
                        _currentService = service
                    }
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
            DDLogError("Reachability object not configured!")
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
        HealthKitUploadManager.sharedInstance.makeDataUploadRequestHandler = self.blipMakeDataUploadRequest
        self.baseUrl = URL(string: kServers[currentService!]!)!
        DDLogInfo("Using service: \(String(describing: self.baseUrl))")
        self.sessionToken = UserDefaults.standard.string(forKey: kSessionTokenDefaultKey)
        if let reachability = reachability {
            reachability.stopNotifier()
        }
        self.reachability = Reachability()
        
        do {
           try reachability?.startNotifier()
        } catch {
            DDLogError("Unable to start notifier!")
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
            DDLogInfo("Switched to \(serverName) server")
            
            let notification = Notification(name: Notification.Name(rawValue: "switchedToNewServer"), object: nil)
            NotificationCenter.default.post(notification)
            
            if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                appDelegate.logout()
            }
        }
    }
    
    /// Logs in the user and obtains the session token for the session (stored internally)
    func login(_ username: String, password: String, completion: @escaping (Result<User>, Int?) -> (Void)) {
        // Similar to email inputs in HTML5, trim the email (username) string of whitespace
        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Clear in case it was set while logged out...
        self.lastNetworkError = nil
        // Set our endpoint for login
        let endpoint = "auth/login"
        
        // Create the authorization string (user:pass base-64 encoded)
        let base64LoginString = NSString(format: "%@:%@", trimmedUsername, password)
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
                self.sessionToken = response.response!.allHeaderFields[self.kSessionTokenResponseId] as! String?
                let json = JSON(response.result.value!)
                
                // Create the User object
                // TODO: Should this call be made in TidepoolMobileDataController?
                let moc = TidepoolMobileDataController.sharedInstance.mocForCurrentUser()
                if let user = User.fromJSON(json, email: trimmedUsername, moc: moc) {
                    TidepoolMobileDataController.sharedInstance.loginUser(user)
                    APIConnector.connector().trackMetric("Logged In")
                    completion(Result.success(user), nil)
                } else {
                    APIConnector.connector().trackMetric("Log In Failed")
                    TidepoolMobileDataController.sharedInstance.logoutUser()
                    completion(Result.failure(NSError(domain: self.kTidepoolMobileErrorDomain,
                        code: -1,
                        userInfo: ["description":"Could not create user from JSON", "result":response.result.value!])), -1)
                }
            } else {
                APIConnector.connector().trackMetric("Log In Failed")
                TidepoolMobileDataController.sharedInstance.logoutUser()
                let statusCode = response.response?.statusCode
                completion(Result.failure(response.result.error!), statusCode)
            }
        }
    }
 
    func fetchProfile(_ userId: String, _ completion: @escaping (Result<JSON>) -> (Void)) {
        // Set our endpoint for the user profile
        // format is like: https://api.tidepool.org/metadata/f934a287c4/profile
        let endpoint = "metadata/" + userId + "/profile"
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        DDLogInfo("fetchProfile endpoint: \(endpoint)")
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
    
    /// Call this after fetching user profile, as part of configureHealthKitInterface, to ensure we have a dataset id for health data uploads (if so enabled).
    /// - parameter completion: Method that will be called when this async operation has completed. If successful, currentUploadId in TidepoolMobileDataController will be set; if not, it will still be nil.
    func configureUploadId(_ completion: @escaping () -> (Void)) {
        let dataCtrl = TidepoolMobileDataController.sharedInstance
        if let user = dataCtrl.currentLoggedInUser, let isDSAUser = dataCtrl.isDSAUser {
            // if we don't have an uploadId, first try fetching one from the server...
            if isDSAUser && dataCtrl.currentUploadId == nil {
                self.fetchDataset(user.userid) {
                    (result: String?) -> (Void) in
                    if result != nil && !result!.isEmpty {
                        DDLogInfo("Dataset fetched existing: \(result!)")
                        dataCtrl.currentUploadId = result
                        completion()
                        return
                    }
                    if result == nil {
                        // network failure for fetchDataset, don't try creating a new one in case one already does exist...
                        completion()
                        return
                    }
                    // Existing dataset fetch failed, try creating a new one...
                    DDLogInfo("Dataset fetch failed, try creating new dataset!")
                    self.createDataset(user.userid) {
                        (result: String?) -> (Void) in
                        if result != nil && !result!.isEmpty {
                            DDLogInfo("New dataset created: \(result!)")
                            dataCtrl.currentUploadId = result!
                        } else {
                            DDLogError("Unable to fetch existing upload dataset or create a new one!")
                        }
                        completion()
                    }
                }
            } else {
                DDLogInfo("Not a DSA user or userid nil or uploadId is not nil")
                completion()
            }
        } else {
            DDLogInfo("No current user or isDSAUser is nil")
            completion()
        }
    }

    /// Ask service for the existing mobile app upload id for this user, if one exists.
    /// - parameter userId: Current user id
    /// - parameter completion: Method that accepts an optional String which will be nil if the network request did not complete, an empty string if an uploadId for this user does not yet exist, and the upload id if it does exist.
    private func fetchDataset(_ userId: String, _ completion: @escaping (String?) -> (Void)) {
        DDLogInfo("Try fetching existing dataset!")
        // Set our endpoint for the dataset fetch
        // format is: https://api.tidepool.org/v1/users/<user-id-here>/data_sets?client.name=tidepool.mobile&size=1"
        let endpoint = "v1/users/" + userId + "/data_sets"
        let parameters = ["client.name": "org.tidepool.mobile", "size": "1"]
        let headerDict = ["Content-Type":"application/json"]

        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        sendRequest(.get, endpoint: endpoint, parameters: parameters as [String : AnyObject]?, headers: headerDict).responseJSON { response in
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            if ( response.result.isSuccess ) {
                let json = JSON(response.result.value!)
                print("\(json)")
                var uploadId: String?
                if let resultDict = json[0].dictionary {
                    uploadId = resultDict["uploadId"]?.string
                }
                if uploadId != nil {
                    DDLogInfo("Fetched existing dataset: \(uploadId!)")
                } else {
                    // return empty string to signal network request completed ok
                    uploadId = ""
                    DDLogInfo("Fetch of existing dataset returned nil!")
                }
                completion(uploadId)
                // TEST: force failure...
                //completion("")
            } else {
                DDLogInfo("Fetch of existing dataset failed!")
                // return nil to signal failure
                completion(nil)
            }
        }
    }
    
    /// Ask service to create a new upload id. Should only be called after fetchDataSet returns a nil array (no existing upload id).
    /// - parameter userId: Current user id
    /// - parameter completion: Method that accepts an optional String which will be nil if the network request did not complete, an empty string if the create did not result in an uploadId, and the upload id if a new id was successfully created.
    private func createDataset(_ userId: String, _ completion: @escaping (String?) -> (Void)) {
        DDLogInfo("Try creating a new dataset!")

        // Set our endpoint for the dataset create
        // format is: https://api.tidepool.org/v1/users/<user-id-here>/data_sets"
        let endpoint = "v1/users/" + userId + "/data_sets"

        let clientDict = ["name": "org.tidepool.mobile", "version": "1.2.3"]
        let deduplicatorDict = ["name": "org.tidepool.deduplicator.dataset.delete.origin"]
        let headerDict = ["Content-Type":"application/json"]
        let jsonObject = ["client":clientDict, "dataSetType":"continuous", "deduplicator":deduplicatorDict] as [String : Any]
        let body: Data?
        do {
            body = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
        } catch {
            DDLogError("Failed to create body!")
            // return nil to signal failure
            completion(nil)
            return
        }
        
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        postRequest(body!, endpoint: endpoint, headers: headerDict).responseJSON { response in
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            if ( response.result.isSuccess ) {
                let json = JSON(response.result.value!)
                var uploadId: String?
                if let dataDict = json["data"].dictionary {
                    uploadId = dataDict["uploadId"]?.string
                }
                if uploadId != nil {
                    DDLogInfo("Create new dataset success: \(uploadId!)")
                } else {
                    // return empty string to signal network request completed ok
                    uploadId = ""
                    DDLogInfo("Create new dataset returned nil!")
                }
                completion(uploadId)
            } else {
                // return nil to signal network request failure
                DDLogInfo("Create new dataset failed!")
                completion(nil)
            }
        }
    }

    func postTimezoneChangesEvent(_ tzChanges: [(time: String, newTzId: String, oldTzId: String?)], _ completion: @escaping (Bool) -> (Void)) {
        let dataCtrl = TidepoolMobileDataController.sharedInstance
        if let currentUploadId = dataCtrl.currentUploadId {
            let endpoint = "/v1/data_sets/" + currentUploadId + "/data"
            let headerDict = ["Content-Type":"application/json"]
            var changesToUploadDictArray = [[String: AnyObject]]()
            for tzChange in tzChanges {
                var sampleToUploadDict = [String: AnyObject]()
                sampleToUploadDict["time"] = tzChange.time as AnyObject
                sampleToUploadDict["type"] = "deviceEvent" as AnyObject
                sampleToUploadDict["subType"] = "timeChange" as AnyObject
                let toDict = ["timeZoneName": tzChange.newTzId]
                sampleToUploadDict["to"] = toDict as AnyObject
                if let oldTzId = tzChange.oldTzId {
                    let fromDict = ["timeZoneName": oldTzId]
                    sampleToUploadDict["from"] = fromDict as AnyObject
                }
                changesToUploadDictArray.append(sampleToUploadDict)
            }
            let body: Data?
            do {
                body = try JSONSerialization.data(withJSONObject: changesToUploadDictArray, options: [])
            } catch {
                DDLogError("Failed to create body!")
                completion(false)
                return
            }
            
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
            postRequest(body!, endpoint: endpoint, headers: headerDict).responseJSON { response in
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
                if ( response.result.isSuccess ) {
                    DDLogInfo("Timezone change upload succeeded!")
                    completion(true)
                } else {
                    // return nil to signal network request failure
                    DDLogInfo("Timezone change upload failed!")
                    completion(false)
                }
            }
        } else {
            DDLogInfo("Timezone change upload fail: no upload id!")
            completion(false)
        }
    }
    
    func fetchUserSettings(_ userId: String, _ completion: @escaping (Result<JSON>) -> (Void)) {
        // Set our endpoint for the user profile
        // format is like: https://api.tidepool.org/metadata/f934a287c4/settings
        let endpoint = "metadata/" + userId + "/settings"
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        sendRequest(.get, endpoint: endpoint).responseJSON { response in
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            if ( response.result.isSuccess ) {
                let json = JSON(response.result.value!)
                completion(Result.success(json))
            } else {
                // Failure
                if let httpResponse = response.response, httpResponse.statusCode ==  404 {
                    DDLogInfo("No user settings found on service!")
                } else {
                    DDLogInfo("User settings fetched failed with result: \(response.result.error!)")
                }
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
        // Format: https://api.tidepool.org/metrics/thisuser/tidepool-Viewed%20Hamburger%20Menu?source=tidepool&sourceVersion=0%2E8%2E1

        metricsCache.append(metric)
        if !serviceAvailable() || (metricSendInProgress && !flushBuffer) {
            //DDLogInfo("Offline: trackMetric stashed: \(metric)")
            return
        }
        
        let nextMetric = metricsCache.removeFirst()
        let endpoint = "metrics/thisuser/tidepool-" + nextMetric
        let parameters = ["source": "tidepool", "sourceVersion": UIApplication.appVersion()]
        metricSendInProgress = true
        sendRequest(.get, endpoint: endpoint, parameters: parameters as [String : AnyObject]?).responseJSON { response in
            self.metricSendInProgress = false
            if let theResponse = response.response {
                let statusCode = theResponse.statusCode
                if statusCode == 200 {
                    DDLogInfo("Tracked metric: \(nextMetric)")
                    if !self.metricsCache.isEmpty {
                        self.trackMetric(self.metricsCache.removeFirst(), flushBuffer: flushBuffer)
                    }
                } else {
                    DDLogError("Failed status code: \(statusCode) for tracking metric: \(metric)")
                    self.lastNetworkError = statusCode
                    if let error = response.result.error {
                        DDLogError("NSError: \(error)")
                    }
                }
            } else {
                DDLogError("Invalid response for tracking metric: \(response.result.error!)")
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
        TidepoolMobileDataController.sharedInstance.logoutUser()
        completion()
    }
    
    func refreshToken(_ completion: @escaping (_ succeeded: Bool, _ responseStatusCode: Int) -> (Void)) {
        
        let endpoint = "/auth/login"
        
        if self.sessionToken == nil || TidepoolMobileDataController.sharedInstance.currentUserId == nil {
            // We don't have a session token to refresh.
            completion(false, 0)
            return
        }
        
        // Post the request.
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        self.sendRequest(.get, endpoint:endpoint).responseJSON { response in
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            if ( response.result.isSuccess ) {
                DDLogInfo("Session token updated")
                self.sessionToken = response.response!.allHeaderFields[self.kSessionTokenResponseId] as! String?
                completion(true, response.response?.statusCode ?? 0)
            } else {
                if let error = response.result.error {
                    let message = "Refresh token failed, error: \(error)"
                    DDLogError(message)
                    UIApplication.localNotifyMessage(message)

                    // TODO: handle network offline!
                }
                completion(false, response.response?.statusCode ?? 0)
            }
        }
    }
    
    /** For now this method returns the result as a JSON object. The result set can be huge, and we want processing to
     *  happen outside of this method until we have something a little less firehose-y.
     */
    func getUserData(_ completion: @escaping (Result<JSON>) -> (Void)) {
        // Set our endpoint for the user data
        let userId = TidepoolMobileDataController.sharedInstance.currentViewedUser!.userid
        let endpoint = "data/" + userId
        
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
    
    func getReadOnlyUserData(_ startDate: Date? = nil, endDate: Date? = nil, objectTypes: String = "smbg,bolus,cbg,wizard,basal", completion: @escaping (Result<JSON>) -> (Void)) {
        // Set our endpoint for the user data
        // TODO: centralize define of read-only events!
        // request format is like: https://api.tidepool.org/data/f934a287c4?endDate=2015-11-17T08%3A00%3A00%2E000Z&startDate=2015-11-16T12%3A00%3A00%2E000Z&type=smbg%2Cbolus%2Ccbg%2Cwizard%2Cbasal
        let userId = TidepoolMobileDataController.sharedInstance.currentViewedUser!.userid
        let endpoint = "data/" + userId
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        DDLogInfo("getReadOnlyUserData request start")
        // TODO: If there is no data returned, I get a failure case with status code 200, and error FAILURE: Error Domain=NSCocoaErrorDomain Code=3840 "Invalid value around character 0." UserInfo={NSDebugDescription=Invalid value around character 0.} ] Maybe an Alamofire issue?
        var parameters: Dictionary = ["type": objectTypes]
        if let startDate = startDate {
            // NOTE: start date is excluded (i.e., dates > start date)
            parameters.updateValue(TidepoolMobileUtils.dateToJSON(startDate), forKey: "startDate")
        }
        if let endDate = endDate {
            // NOTE: end date is included (i.e., dates <= end date)
            parameters.updateValue(TidepoolMobileUtils.dateToJSON(endDate), forKey: "endDate")
        }
        sendRequest(.get, endpoint: endpoint, parameters: parameters as [String : AnyObject]?).responseJSON { response in
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            DDLogInfo("getReadOnlyUserData request complete")
            if (response.result.isSuccess) {
                let json = JSON(response.result.value!)
                var validResult = true
                if let status = json["status"].number {
                    let statusCode = Int(truncating: status)
                    DDLogInfo("getReadOnlyUserData includes status field: \(statusCode)")
                    // TODO: determine if any status is indicative of failure here! Note that if call was successful, there will be no status field in the json result. The only verified error response is 403 which happens when we pass an invalid token.
                    if statusCode == 401 || statusCode == 403 {
                        validResult = false
                        self.lastNetworkError = statusCode
                        completion(Result.failure(NSError(domain: self.kTidepoolMobileErrorDomain,
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
                        DDLogError("Failure status code: \(statusCode) for getReadOnlyUserData")
                        APIConnector.connector().trackMetric("Tidepool Data Fetch Failure - Code " + String(statusCode))
                    }
                    // Otherwise, just indicates no data were found...
                } else {
                    DDLogError("Invalid response for getReadOnlyUserData metric")
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
    
    // User-agent string, based on that from Alamofire, but common regardless of whether Alamofire library is used
    private func userAgentString() -> String {
        if _userAgentString == nil {
            _userAgentString = {
                if let info = Bundle.main.infoDictionary {
                    let executable = info[kCFBundleExecutableKey as String] as? String ?? "Unknown"
                    let bundle = info[kCFBundleIdentifierKey as String] as? String ?? "Unknown"
                    let appVersion = info["CFBundleShortVersionString"] as? String ?? "Unknown"
                    let appBuild = info[kCFBundleVersionKey as String] as? String ?? "Unknown"
                    
                    let osNameVersion: String = {
                        let version = ProcessInfo.processInfo.operatingSystemVersion
                        let versionString = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
                        
                        let osName: String = {
                            #if os(iOS)
                            return "iOS"
                            #elseif os(watchOS)
                            return "watchOS"
                            #elseif os(tvOS)
                            return "tvOS"
                            #elseif os(macOS)
                            return "OS X"
                            #elseif os(Linux)
                            return "Linux"
                            #else
                            return "Unknown"
                            #endif
                        }()
                        
                        return "\(osName) \(versionString)"
                    }()
                    
                    return "\(executable)/\(appVersion) (\(bundle); build:\(appBuild); \(osNameVersion))"
                }
                
                return "TidepoolMobile"
            }()
        }
        return _userAgentString!
    }
    private var _userAgentString: String?
    
    private func sessionManager() -> SessionManager {
        if _sessionManager == nil {
            // get the default headers
            var alamoHeaders = Alamofire.SessionManager.defaultHTTPHeaders
            // add our custom user-agent
            alamoHeaders["User-Agent"] = self.userAgentString()
            // create a custom session configuration
            let configuration = URLSessionConfiguration.default
            // add the headers
            configuration.httpAdditionalHeaders = alamoHeaders
            // create a session manager with the configuration
            _sessionManager = Alamofire.SessionManager(configuration: configuration)
        }
        return _sessionManager!
    }
    private var _sessionManager: SessionManager?
    
    // Sends a request to the specified endpoint
    private func sendRequest(_ requestType: HTTPMethod? = .get,
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
        DDLogInfo("sendRequest url: \(url), params: \(parameters ?? [:]), headers: \(apiHeaders ?? [:])")
        return self.sessionManager().request(url, method: requestType!, parameters: parameters, headers: apiHeaders).validate()
        //debugPrint(result)
        //return result
    }
    
    func getApiHeaders() -> [String: String]? {
        if ( sessionToken != nil ) {
            return [kSessionTokenHeaderId : sessionToken!]
        }
        return nil
    }
    
    // Sends a request to the specified endpoint
    fileprivate func postRequest(_ data: Data,
                                 endpoint: (String),
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
        
        DDLogInfo("postRequest url: \(url), headers: \(apiHeaders ?? [:])")
        return self.sessionManager().upload(data, to: url, headers: apiHeaders).validate()
    }

    //
    // MARK: - Note fetching and uploading
    //
    // TODO: Taken from BlipNotes, should really use AlamoFire, etc.
    
    
    func getAllViewableUsers(_ fetchWatcher: UsersFetchAPIWatcher) {
        
        let urlExtension = "/access/groups/" + TidepoolMobileDataController.sharedInstance.currentUserId!
        
        let headerDict = [kSessionTokenHeaderId:"\(sessionToken!)"]
        
        let completion = { (response: URLResponse?, data: Data?, error: NSError?) -> Void in
            if let httpResponse = response as? HTTPURLResponse {
                if (httpResponse.statusCode == 200) {
                    DDLogInfo("Found viewable users")
                    let jsonResult: NSDictionary = ((try? JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.mutableContainers)) as? NSDictionary)!
                    var users: [String] = []
                    for key in jsonResult.keyEnumerator() {
                        users.append(key as! String)
                    }
                    fetchWatcher.viewableUsers(users)
                } else {
                    DDLogError("Did not find viewable users - invalid status code \(httpResponse.statusCode)")
                    self.alertWithOkayButton(self.unknownError, message: self.unknownErrorMessage)
                }
            } else {
                DDLogError("Did not find viewable users - response could not be parsed")
                self.alertWithOkayButton(self.unknownError, message: self.unknownErrorMessage)
            }
        }
        
        blipRequest("GET", urlExtension: urlExtension, headerDict: headerDict, body: nil, completion: completion)
    }

    func getNotesForUserInDateRange(_ fetchWatcher: NoteAPIWatcher, userid: String, start: Date?, end: Date?) {
        
        if sessionToken == nil {
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"

        var startString = ""
        if let start = start {
            startString = "?starttime=" + dateFormatter.string(from: start)
        }
        
        var endString = ""
        if let end = end {
            endString = "&endtime="  + dateFormatter.string(from: end)
        }
        
        let urlExtension = "/message/notes/" + userid + startString + endString
        let headerDict = [kSessionTokenHeaderId:"\(sessionToken!)"]
        
        let preRequest = { () -> Void in
            fetchWatcher.loadingNotes(true)
        }
        
        let completion = { (response: URLResponse?, data: Data?, error: NSError?) -> Void in
            
            // End refreshing for refresh control
            fetchWatcher.endRefresh()
            
            if let httpResponse = response as? HTTPURLResponse {
                if (httpResponse.statusCode == 200) {
                    DDLogInfo("Got notes for user (\(userid)) in given date range: \(startString) to \(endString)")
                    var notes: [BlipNote] = []
                    
                    let jsonResult: NSDictionary = ((try? JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.mutableContainers)) as? NSDictionary)!
                    
                    //DDLogInfo("notes: \(JSON(data!))")
                    let messages: NSArray = jsonResult.value(forKey: "messages") as! NSArray
                    
                    let dateFormatter = DateFormatter()
                    
                    for message in messages {
                        let id = (message as AnyObject).value(forKey: "id") as! String
                        let otheruserid = (message as AnyObject).value(forKey: "userid") as! String
                        let groupid = (message as AnyObject).value(forKey: "groupid") as! String
                        
                        
                        var timestamp: Date?
                        let timestampString = (message as AnyObject).value(forKey: "timestamp") as? String
                        if let timestampString = timestampString {
                            timestamp = dateFormatter.dateFromISOString(timestampString)
                        }
                        
                        var createdtime: Date?
                        let createdtimeString = (message as AnyObject).value(forKey: "createdtime") as? String
                        if let createdtimeString = createdtimeString {
                            createdtime = dateFormatter.dateFromISOString(createdtimeString)
                        } else {
                            createdtime = timestamp
                        }

                        if let timestamp = timestamp, let createdtime = createdtime {
                            let messagetext = (message as AnyObject).value(forKey: "messagetext") as! String
                            
                            let otheruser = BlipUser(userid: otheruserid)
                            let userDict = (message as AnyObject).value(forKey: "user") as! NSDictionary
                            otheruser.processUserDict(userDict)
                            
                            let note = BlipNote(id: id, userid: otheruserid, groupid: groupid, timestamp: timestamp, createdtime: createdtime, messagetext: messagetext, user: otheruser)
                            notes.append(note)
                        } else {
                            if timestamp == nil {
                                DDLogError("Ignoring fetched note with invalid format timestamp string: \(String(describing: timestampString))")
                            }
                            if createdtime == nil {
                                DDLogError("Ignoring fetched note with invalid create time string: \(String(describing: createdtimeString))")
                            }
                        }
                    }
                    
                    fetchWatcher.addNotes(notes)
                } else if (httpResponse.statusCode == 404) {
                    DDLogError("No notes retrieved, status code: \(httpResponse.statusCode), userid: \(userid)")
                } else {
                    DDLogError("No notes retrieved - invalid status code \(httpResponse.statusCode)")
                    self.alertWithOkayButton(self.unknownError, message: self.unknownErrorMessage)
                }
                
                fetchWatcher.loadingNotes(false)
                let notification = Notification(name: Notification.Name(rawValue: "doneFetching"), object: nil)
                NotificationCenter.default.post(notification)
            } else {
                // TODO: have seen this... need to dump response and debug!
                DDLogError("No notes retrieved - could not parse response")
                self.alertWithOkayButton(self.unknownError, message: self.unknownErrorMessage)
            }
        }
        
        blipRequest("GET", urlExtension: urlExtension, headerDict: headerDict, body: nil, preRequest: preRequest, completion: completion)
    }

    func getMessageThreadForNote(_ fetchWatcher: NoteAPIWatcher, messageId: String) {
        
        if sessionToken == nil {
            return
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        let urlExtension = "/message/thread/" + messageId
        
        let headerDict = [kSessionTokenHeaderId:"\(sessionToken!)"]
        
        let preRequest = { () -> Void in
            fetchWatcher.loadingNotes(true)
        }
        
        let completion = { (response: URLResponse?, data: Data?, error: NSError?) -> Void in
            
            // End refreshing for refresh control
            fetchWatcher.endRefresh()
            
            if let httpResponse = response as? HTTPURLResponse {
                if (httpResponse.statusCode == 200) {
                    DDLogInfo("Got thread for note \(messageId)")
                    var notes: [BlipNote] = []
                    
                    let jsonResult: NSDictionary = ((try? JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.mutableContainers)) as? NSDictionary)!
                    
                    DDLogInfo("notes: \(jsonResult)")
                    let messages: NSArray = jsonResult.value(forKey: "messages") as! NSArray
                    let dateFormatter = DateFormatter()
                    
                    for message in messages {
                        let id = (message as AnyObject).value(forKey: "id") as! String
                        let parentmessage = (message as AnyObject).value(forKey: "parentmessage") as? String
                        let otheruserid = (message as AnyObject).value(forKey: "userid") as! String
                        let groupid = (message as AnyObject).value(forKey: "groupid") as! String
                        
                        var timestamp: Date?
                        let timestampString = (message as AnyObject).value(forKey: "timestamp") as? String
                        if let timestampString = timestampString {
                            timestamp = dateFormatter.dateFromISOString(timestampString)
                        }

                        var createdtime: Date?
                        let createdtimeString = (message as AnyObject).value(forKey: "createdtime") as? String
                        if let createdtimeString = createdtimeString {
                            createdtime = dateFormatter.dateFromISOString(createdtimeString)
                        } else {
                            createdtime = timestamp
                        }
                        
                        if let timestamp = timestamp, let createdtime = createdtime {
                            let messagetext = (message as AnyObject).value(forKey: "messagetext") as! String
                            
                            let otheruser = BlipUser(userid: otheruserid)
                            let userDict = (message as AnyObject).value(forKey: "user") as! NSDictionary
                            otheruser.processUserDict(userDict)
                            
                            let note = BlipNote(id: id, userid: otheruserid, groupid: groupid, timestamp: timestamp, createdtime: createdtime, messagetext: messagetext, user: otheruser)
                            note.parentmessage = parentmessage
                            notes.append(note)
                        } else {
                            if timestamp == nil {
                                DDLogError("Ignoring fetched comment with invalid format timestamp string: \(String(describing: timestampString))")
                            }
                            if createdtime == nil {
                                DDLogError("Ignoring fetched comment with invalid create time string: \(String(describing: createdtimeString))")
                            }
                        }
                    }
                    
                    fetchWatcher.addComments(notes, messageId: messageId)
                } else if (httpResponse.statusCode == 404) {
                    DDLogError("No notes retrieved, status code: \(httpResponse.statusCode), messageId: \(messageId)")
                } else {
                    DDLogError("No notes retrieved - invalid status code \(httpResponse.statusCode)")
                    self.alertWithOkayButton(self.unknownError, message: self.unknownErrorMessage)
                }
                
                fetchWatcher.loadingNotes(false)
                let notification = Notification(name: Notification.Name(rawValue: "doneFetching"), object: nil)
                NotificationCenter.default.post(notification)
            } else {
                DDLogError("No comments retrieved - could not parse response")
                self.alertWithOkayButton(self.unknownError, message: self.unknownErrorMessage)
            }
        }
        
        blipRequest("GET", urlExtension: urlExtension, headerDict: headerDict, body: nil, preRequest: preRequest, completion: completion)
    }
    
    func doPostWithNote(_ postWatcher: NoteAPIWatcher, note: BlipNote) {
        
        var urlExtension = ""
        if let parentMessage = note.parentmessage {
            // this is a reply
            urlExtension = "/message/reply/" + parentMessage
        } else {
            // this is a note, i.e., start of a thread
            urlExtension = "/message/send/" + note.groupid
        }
        
        let headerDict = [kSessionTokenHeaderId:"\(sessionToken!)", "Content-Type":"application/json"]
        
        let jsonObject = note.dictionaryFromNote()
        let body: Data?
        do {
            body = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
        } catch {
            body = nil
        }
        
        let completion = { (response: URLResponse?, data: Data?, error: NSError?) -> Void in
            if let httpResponse = response as? HTTPURLResponse {
                
                if (httpResponse.statusCode == 201) {
                    DDLogInfo("Sent note for groupid: \(note.groupid)")
                    
                    let jsonResult: NSDictionary = ((try? JSONSerialization.jsonObject(with: data!, options: JSONSerialization.ReadingOptions.mutableContainers)) as? NSDictionary)!
                    
                    note.id = jsonResult.value(forKey: "id") as! String
                    postWatcher.postComplete(note)
                    
                } else {
                    DDLogError("Did not send note for groupid \(note.groupid) - invalid status code \(httpResponse.statusCode)")
                    self.alertWithOkayButton(self.unknownError, message: self.unknownErrorMessage)
                }
            } else {
                DDLogError("Did not send note for groupid \(note.groupid) - could not parse response")
                self.alertWithOkayButton(self.unknownError, message: self.unknownErrorMessage)
            }
        }
        
        blipRequest("POST", urlExtension: urlExtension, headerDict: headerDict, body: body, completion: completion)
    }

    // update note or comment...
    func updateNote(_ updateWatcher: NoteAPIWatcher, editedNote: BlipNote, originalNote: BlipNote) {
        
        let urlExtension = "/message/edit/" + originalNote.id
        
        let headerDict = [kSessionTokenHeaderId:"\(sessionToken!)", "Content-Type":"application/json"]
        
        let jsonObject = editedNote.updatesFromNote()
        let body: Data?
        do {
            body = try JSONSerialization.data(withJSONObject: jsonObject, options: [])
        } catch  {
            body = nil
        }
        
        let completion = { (response: URLResponse?, data: Data?, error: NSError?) -> Void in
            if let httpResponse = response as? HTTPURLResponse {
                if (httpResponse.statusCode == 200) {
                    DDLogInfo("Edited note with id \(originalNote.id)")
                    updateWatcher.updateComplete(originalNote, editedNote: editedNote)
                } else {
                    DDLogError("Did not edit note with id \(originalNote.id) - invalid status code \(httpResponse.statusCode)")
                    self.alertWithOkayButton(self.unknownError, message: self.unknownErrorMessage)
                }
            } else {
                DDLogError("Did not edit note with id \(originalNote.id) - could not parse response")
                self.alertWithOkayButton(self.unknownError, message: self.unknownErrorMessage)
            }
        }
        
        blipRequest("PUT", urlExtension: urlExtension, headerDict: headerDict, body: body, completion: completion)
    }
    
    // delete note or comment...
    func deleteNote(_ deleteWatcher: NoteAPIWatcher, noteToDelete: BlipNote) {
        let urlExtension = "/message/remove/" + noteToDelete.id
        
        let headerDict = [kSessionTokenHeaderId:"\(sessionToken!)"]
        
        let completion = { (response: URLResponse?, data: Data?, error: NSError?) -> Void in
            if let httpResponse = response as? HTTPURLResponse {
                if (httpResponse.statusCode == 202) {
                    DDLogInfo("Deleted note with id \(noteToDelete.id)")
                    deleteWatcher.deleteComplete(noteToDelete)
                } else {
                    DDLogError("Did not delete note with id \(noteToDelete.id) - invalid status code \(httpResponse.statusCode)")
                    self.alertWithOkayButton(self.unknownError, message: self.unknownErrorMessage)
                }
            } else {
                DDLogError("Did not delete note with id \(noteToDelete.id) - could not parse response")
                self.alertWithOkayButton(self.unknownError, message: self.unknownErrorMessage)
            }
        }
        
        blipRequest("DELETE", urlExtension: urlExtension, headerDict: headerDict, body: nil, completion: completion)
    }

    
    let unknownError: String = "Unknown Error Occurred"
    let unknownErrorMessage: String = "An unknown error occurred. We are working hard to resolve this issue."
    private var isShowingAlert = false
    
    private func alertWithOkayButton(_ title: String, message: String) {
        DDLogInfo("title: \(title), message: \(message)")
        if defaultDebugLevel != DDLogLevel.off {
            let callStackSymbols = Thread.callStackSymbols
            DDLogInfo("callStackSymbols: \(callStackSymbols)")
        }
        
        if (!isShowingAlert) {
            isShowingAlert = true
            
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { Void in
                self.isShowingAlert = false
            }))
            presentAlert(alert)
        }
    }

    private func presentAlert(_ alert: UIAlertController) {
        if var topController = UIApplication.shared.keyWindow?.rootViewController {
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
            }
            topController.present(alert, animated: true, completion: nil)
        }
    }
    
    func alertIfNetworkIsUnreachable() -> Bool {
        if APIConnector.connector().serviceAvailable() {
            return false
        }
        let alert = UIAlertController(title: "Not Connected to Network", message: "This application requires a network to access the Tidepool service!", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: { Void in
            return
        }))
        presentAlert(alert)
        return true
    }

    func blipRequest(_ method: String, urlExtension: String, headerDict: [String: String], body: Data?, preRequest: (() -> Void)? = nil, completion: @escaping (_ response: URLResponse?, _ data: Data?, _ error: NSError?) -> Void) {
        
        if (self.isConnectedToNetwork()) {
            preRequest?()
            
            let baseURL = kServers[currentService!]!
            var urlString = baseURL + urlExtension
            urlString = urlString.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!
            let url = URL(string: urlString)
            let request = NSMutableURLRequest(url: url!)
            request.httpMethod = method
            for (field, value) in headerDict {
                request.setValue(value, forHTTPHeaderField: field)
            }
            // make user-agent similar to that from Alamofire
            request.setValue(self.userAgentString(), forHTTPHeaderField: "User-Agent")
            request.httpBody = body
            
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
            let task = URLSession.shared.dataTask(with: request as URLRequest) {
                (data, response, error) -> Void in
                DispatchQueue.main.async(execute: {
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                    completion(response, data, (error as NSError?))
                })
                return
            }
            task.resume()
        } else {
            DDLogInfo("Not connected to network")
        }
    }
    
    private func blipMakeDataUploadRequest(_ httpMethod: String) throws -> URLRequest {
        DDLogVerbose("trace")
        
        var error: NSError?
        
        defer {
            if error != nil {
                DDLogError("Upload failed: \(String(describing: error)), \(String(describing: error?.userInfo))")
            }
        }
        
        guard self.isConnectedToNetwork() else {
            error = NSError(domain: "APIConnect-blipMakeDataUploadRequest", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to upload, not connected to network"])
            throw error!
        }
        
        guard let currentUploadId = TidepoolMobileDataController.sharedInstance.currentUploadId else {
            error = NSError(domain: "APIConnect-blipMakeDataUploadRequest", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unable to upload, no upload id is available"])
            throw error!
        }
        
        guard sessionToken != nil else {
            error = NSError(domain: "APIConnect-blipMakeDataUploadRequest", code: -3, userInfo: [NSLocalizedDescriptionKey: "Unable to upload, no session token exists"])
            throw error!
        }
        
        let urlExtension = "/v1/data_sets/" + currentUploadId + "/data"
        let headerDict = [kSessionTokenHeaderId:"\(sessionToken!)", "Content-Type":"application/json"]
        let baseURL = kServers[currentService!]!
        var urlString = baseURL + urlExtension
        urlString = urlString.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!
        let url = URL(string: urlString)
        let request = NSMutableURLRequest(url: url!)
        request.httpMethod = httpMethod //"POST" or "DELETE"
        for (field, value) in headerDict {
            request.setValue(value, forHTTPHeaderField: field)
        }
        // make user-agent similar to that from Alamofire
        request.setValue(self.userAgentString(), forHTTPHeaderField: "User-Agent")

        return request as URLRequest
    }
 }
