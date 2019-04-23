/*
 * Copyright (c) 2019, Tidepool Project
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

public class TPUploaderServiceAPI {
    
    static var connector: TPUploaderServiceAPI?
    private let HKDataUploadIdKey = "kHKDataUploadIdKey"
    private let kSessionTokenHeaderId = "X-Tidepool-Session-Token"

    init(_ config: TPUploaderConfigInfo) {
        self.config = config
        TPUploaderServiceAPI.connector = self
    }
    
    private var config: TPUploaderConfigInfo
    private var defaults = UserDefaults.standard

    /// Used for filling out a health data upload request...
    ///
    /// Read only - returns nil string if no user or uploadId is available.
    var currentUploadId: String? {
        get {
            if _currentUploadId == nil {
                _currentUploadId = defaults.string(forKey: HKDataUploadIdKey)
            }
            return _currentUploadId
        }
        set {
            defaults.setValue(newValue, forKey: HKDataUploadIdKey)
            _currentUploadId = newValue
        }
    }
    private var _currentUploadId: String?

    /// Use passed in configuration protocol object for connectivity
    func isConnectedToNetwork() -> Bool {
        return config.isConnectedToNetwork()
    }
    
    // MARK: - Profile updating with Bio-sex
    
    /// Fill in Tidepool biological sex of patient if it is missing, and we can get it from HealthKit.
    func updateProfileBioSexCheck() {
        // Fetch user sex in case it is needed for profile
        DDLogInfo("\(#function)")
        if let healthStore = HealthKitManager.sharedInstance.healthStore {
            if config.bioSex == nil {
                do {
                    let sex = try healthStore.biologicalSex()
                    let bioSexString = sex.biologicalSex.stringRepresentation
                    guard sex.biologicalSex != .notSet else {
                        DDLogInfo("biological sex not set in HK!")
                        return
                    }
                    DDLogInfo("biologicalSex is \(bioSexString)")
                    if let userId = config.currentUserId() {
                        self.updateProfile(userId, biologicalSex: bioSexString) {
                            updateOk in
                            DDLogInfo("Result of profile update: \(updateOk)")
                            self.config.bioSex = bioSexString
                        }
                    }
                } catch {
                    DDLogInfo("throw from call for biologicalSex: not authorized?")
                }
            }
        }
    }
    
    func fetchProfile(_ userId: String, _ completion: @escaping (_ response: SendRequestResponse) -> (Void)) {
        // Set our endpoint for the user profile
        // format is like: https://api.tidepool.org/metadata/f934a287c4/profile
        let urlExtension = "/metadata/" + userId + "/profile"
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        DDLogInfo("fetchProfile endpoint: \(urlExtension)")
        sendRequest("GET", urlExtension: urlExtension, contentType: nil, completion: completion)
    }
    
    func updateProfile(_ userId: String, biologicalSex: String, _ completion: @escaping (Bool) -> (Void)) {
        DDLogInfo("Try updating user profile with biological sex: \(biologicalSex)")
        
        func mergeBioSexWithProfile(_ profile: inout JSON) -> Data? {
            let bioSexDict: [String: Any] = ["patient": [
                "biologicalSex": biologicalSex
                ]
            ]
            var result: Data?
            do {
                let bioSexJsonData = try JSONSerialization.data(withJSONObject: bioSexDict, options: [])
                try profile.merge(with: JSON(bioSexJsonData))
                let mergedData = try profile.rawData()
                result = mergedData
                if let mergedDataStr = String(data: mergedData, encoding: .utf8) {
                    result = mergedData
                    DDLogDebug("merged profile json: \(mergedDataStr)")
                } else {
                    DDLogError("Merged doesn't print!")
                }
            } catch {
                DDLogError("Serialization errors merging json!")
            }
            return result
        }
        
        fetchProfile(userId) {
            (result: SendRequestResponse) -> (Void) in
            DDLogInfo("checkRestoreCurrentViewedUser profile fetch result: \(result)")
            guard result.error == nil else {
                DDLogError("Failed to fetch profile!")
                completion(false)
                return
            }
            guard result.data != nil else {
                DDLogError("Error in fetched profile json!")
                completion(false)
                return
            }
            var profileJson = JSON(result.data!)
            let patient = profileJson["patient"]
            guard profileJson["patient"] != JSON.null else {
                DDLogError("No patient record in the fetched profile, not a DSA user!")
                completion(false)
                return
            }
            if let currentBioSex = patient["biologicalSex"].string, currentBioSex.lowercased() != "unknown" {
                DDLogError("biological sex '\(currentBioSex)' already set in Tidepool, should not update!")
                completion(false)
                return
            }
            guard let body = mergeBioSexWithProfile(&profileJson) else {
                DDLogError("Serialization errors merging json!")
                completion(false)
                return
            }
            // then repost!
            let urlExtension = "/metadata/" + userId + "/profile"
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
            self.sendRequest("POST", urlExtension: urlExtension, contentType: .json, body: body) {
                (result: SendRequestResponse) -> (Void) in
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
                if (result.isSuccess()) {
                    DDLogInfo("Posted updated profile successfully!")
                    completion(true)
                } else {
                    // return nil to signal network request failure
                    DDLogInfo("Post of updated profile failed!")
                    completion(false)
                }
            }
        }
    }
    
    /// Call this after fetching user profile, as part of configureHealthKitInterface, to ensure we have a dataset id for health data uploads (if so enabled).
    /// - parameter completion: Method that will be called when this async operation has completed. If successful, currentUploadId in TidepoolMobileDataController will be set; if not, it will still be nil.
    func configureUploadId(_ completion: @escaping () -> (Void)) {
        if let userId = config.currentUserId() {
            // if we don't have an uploadId, first try fetching one from the server...
            if config.isDSAUser() && currentUploadId == nil {
                self.fetchDataset(userId) {
                    (result: String?) -> (Void) in
                    if result != nil && !result!.isEmpty {
                        DDLogInfo("Dataset fetched existing: \(result!)")
                        self.currentUploadId = result
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
                    self.createDataset(userId) {
                        (result: String?) -> (Void) in
                        if result != nil && !result!.isEmpty {
                            DDLogInfo("New dataset created: \(result!)")
                            self.currentUploadId = result!
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
        let urlExtension = "/v1/users/" + userId + "/data_sets?client.name=org.tidepool.mobile&size=1"
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        sendRequest("GET", urlExtension: urlExtension, contentType: .urlEncoded) {
            (result: SendRequestResponse) -> (Void) in
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            if (result.isSuccess()) {
                let json = JSON(result.data!)
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
                DDLogError("Fetch of existing dataset failed!")
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
        let urlExtension = "v1/users/" + userId + "/data_sets"
        
        let clientDict = ["name": "org.tidepool.mobile", "version": UIApplication.appVersion()]
        let deduplicatorDict = ["name": "org.tidepool.deduplicator.dataset.delete.origin"]
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
        sendRequest("POST", urlExtension: urlExtension, contentType: .json, body: body) {
            (result: SendRequestResponse) -> (Void) in
            UIApplication.shared.isNetworkActivityIndicatorVisible = false
            if (result.isSuccess()) {
                let json = JSON(result.data!)
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
    
    /// Returns last timezone id uploaded on success, otherwise nil
    func postTimezoneChangesEvent(_ tzChanges: [(time: String, newTzId: String, oldTzId: String?)], _ completion: @escaping (String?) -> (Void)) {
        if let currentUploadId = self.currentUploadId {
            let urlExtension = "/v1/data_sets/" + currentUploadId + "/data"
            var changesToUploadDictArray = [[String: AnyObject]]()
            var lastTzUploaded: String?
            for tzChange in tzChanges {
                var sampleToUploadDict = [String: AnyObject]()
                sampleToUploadDict["time"] = tzChange.time as AnyObject
                sampleToUploadDict["type"] = "deviceEvent" as AnyObject
                sampleToUploadDict["subType"] = "timeChange" as AnyObject
                let toDict = ["timeZoneName": tzChange.newTzId]
                lastTzUploaded = tzChange.newTzId
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
                if let postBodyJson = String(data: body!, encoding: .utf8) {
                    DDLogInfo("Posting json for timechange: \(postBodyJson)")
                }
            } catch {
                DDLogError("Failed to create body!")
                completion(nil)
                return
            }
            
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
            sendRequest("POST", urlExtension: urlExtension, contentType: .json, body: body) {
               (result: SendRequestResponse) -> (Void) in UIApplication.shared.isNetworkActivityIndicatorVisible = false
                if (result.isSuccess()) {
                    DDLogInfo("Timezone change upload succeeded!")
                    completion(lastTzUploaded)
                } else {
                    // return nil to signal network request failure
                    DDLogInfo("Timezone change upload failed!")
                    completion(nil)
                }
            }
        } else {
            DDLogInfo("Timezone change upload fail: no upload id!")
            completion(nil)
        }
    }

    //
    // MARK: - Lower-level networking methods
    //
    class SendRequestResponse {
        let request: URLRequest?
        var response: URLResponse?
        var data: Data?
        var error: NSError?
        var httpResponse: HTTPURLResponse? {
            return response as? HTTPURLResponse
        }
        init(
            request: URLRequest? = nil,
            response: HTTPURLResponse? = nil,
            data: Data? = nil,
            error: NSError? = nil)
        {
            self.request = request
            self.response = response
            self.data = data
            self.error = error
        }
        
        func isSuccess() -> Bool {
            if let status = httpResponse?.statusCode {
                if status == 200 || status == 201 {
                    return true
                }
            }
            return false
        }
    }

    enum ContentType {
        case json
        case urlEncoded
    }
    
    func sendRequest(_ method: String, urlExtension: String, contentType: ContentType? = nil, body: Data? = nil, completion: @escaping (_ response: SendRequestResponse) -> Void) {
        
        if (config.isConnectedToNetwork()) {
            guard let baseURL = config.baseUrlString() else {
                DDLogError("Not logged in!")
                let error = NSError(domain: "TidepoolHKUploader service API", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not logged in!"])
                let sendResponse = SendRequestResponse(error: error)
                completion(sendResponse)
                return
            }
            var urlString = baseURL + urlExtension
            urlString = urlString.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed)!
            let url = URL(string: urlString)
            var request = URLRequest(url: url!)
            let sendResponse = SendRequestResponse(request: request)
            request.httpMethod = method
            
            if let contentType = contentType {
                let contentTypeStr = contentType == .json ? "application/json" : "application/x-www-form-urlencoded; charset=utf-8"
                request.setValue(contentTypeStr, forHTTPHeaderField: "Content-Type")
           }

            guard let token = config.sessionToken() else {
                let error = NSError(domain: "TidepoolHKUploader service API", code: -1, userInfo: [NSLocalizedDescriptionKey: "No session token exists, \(method) failed to endpoint \(urlExtension)"])
                sendResponse.error = error
                completion(sendResponse)
                return
            }
            request.setValue("\(token)", forHTTPHeaderField: kSessionTokenHeaderId)
            request.httpBody = body

            // make user-agent similar to that from Alamofire
            request.setValue(self.userAgentString(), forHTTPHeaderField: "User-Agent")
            
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
            let task = URLSession.shared.dataTask(with: request as URLRequest) {
                (data, response, error) -> Void in
                DispatchQueue.main.async(execute: {
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                    sendResponse.response = response
                    sendResponse.data = data
                    sendResponse.error = error as NSError?
                    completion(sendResponse)
                })
                return
            }
            task.resume()
        } else {
            DDLogError("Not connected to network")
            let error = NSError(domain: "TidepoolHKUploader service API", code: -1, userInfo: [NSLocalizedDescriptionKey: "Not connected to network"])
            let sendResponse = SendRequestResponse(error: error)
            completion(sendResponse)
            return
        }
    }
    
    public func makeDataUploadRequest(_ httpMethod: String) throws -> URLRequest {
        DDLogVerbose("\(#function)")
        
        var error: NSError?
        
        defer {
            if error != nil {
                config.logError("Upload failed: \(String(describing: error)), \(String(describing: error?.userInfo))")
            }
        }
        
        guard config.isConnectedToNetwork() else {
            error = NSError(domain: "APIConnect-makeDataUploadRequest", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to upload, not connected to network"])
            throw error!
        }
        
        guard let uploadId = currentUploadId else {
            error = NSError(domain: "APIConnect-makeDataUploadRequest", code: -2, userInfo: [NSLocalizedDescriptionKey: "Unable to upload, no upload id is available"])
            throw error!
        }
        
        guard let token = config.sessionToken() else {
            error = NSError(domain: "APIConnect-makeDataUploadRequest", code: -3, userInfo: [NSLocalizedDescriptionKey: "Unable to upload, no session token exists"])
            throw error!
        }
        
        let urlExtension = "/v1/data_sets/" + uploadId + "/data"
        let headerDict = [kSessionTokenHeaderId:"\(token)", "Content-Type":"application/json"]
        let baseURL = config.baseUrlString()!
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
 
 }
