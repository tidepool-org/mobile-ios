//
//  TPUploaderAPI.swift
//
//  Copyright © 2019 Tidepool. All rights reserved.
//

import Foundation
import CocoaLumberjack
import TPHealthKitUploader

/// The singleton of this class, accessed and initialized via TidepoolMobileUploaderAPI.connector(), initializes the uploader interface and provides it with the necessary callback functions.
class TPUploaderAPI: TPUploaderConfigInfo {
        
    static var _connector: TPUploaderAPI?
    /// Supports a singleton for the application.
    class func connector() -> TPUploaderAPI {
        if _connector == nil {
            let connector = TPUploaderAPI.init()
            connector.configure()
            _connector = connector
        }
        return _connector!
    }

    /// Use this to call various framework api's
    private var _uploader: TPUploader?
    func uploader() -> TPUploader {
        return _uploader!
    }
    
    private init() {
        service = APIConnector.connector()
        dataCtrl = TidepoolMobileDataController.sharedInstance
    }
    private func configure() {
        _uploader = TPUploader(self)
    }

    private let service: APIConnector
    private let dataCtrl: TidepoolMobileDataController

    //
    // MARK: - TPUploaderConfigInfo protocol
    //
    
    //
    // Service API functions
    //
    func isConnectedToNetwork() -> Bool {
        let result = service.isConnectedToNetwork()
        DDLogInfo("\(#function) - TPUploaderConfigInfo protocol, returning: \(result)")
        return result
    }
    
    func sessionToken() -> String? {
        let result = service.sessionToken
        DDLogInfo("\(#function) - TPUploaderConfigInfo protocol, returning: \(result ?? "nil")")
        return result
    }
    
    // token expired? Log out to force token refresh, but should probably just do a refresh!
    // TODO: add a call to refresh!
    func authorizationErrorReceived() {
        service.logout() {
             let notification = Notification(name: Notification.Name(rawValue: "serviceLoggedOut"), object: nil)
             NotificationCenter.default.post(notification)
        }
     }

    func baseUrlString() -> String? {
        let result = service.baseUrlString
        DDLogInfo("\(#function) - TPUploaderConfigInfo protocol, returning: \(result ?? "nil")")
        return result
    }

    func trackMetric(_ metric: String) {
        DDLogInfo("\(#function) - TPUploaderConfigInfo protocol")
        service.trackMetric(metric)
    }
    
    func currentUserId() -> String? {
        let result = dataCtrl.currentLoggedInUser?.userid
        DDLogInfo("\(#function) - TPUploaderConfigInfo protocol, returning: \(result ?? "nil")")
        return result
    }
    
    var currentUserName: String? {
        get {
            let result = dataCtrl.currentLoggedInUser?.fullName
            DDLogInfo("\(#function) - TPUploaderConfigInfo protocol, returning: \(result ?? "nil")")
            return result
        }
    }

    func isDSAUser() -> Bool {
        let result = dataCtrl.currentLoggedInUser?.isDSAUser
        DDLogInfo("\(#function) - TPUploaderConfigInfo protocol, returning: \(String(describing: result))")
        return result == nil ? false : result!
    }
    
    var bioSex: String? {
        get {
            return dataCtrl.currentLoggedInUser?.biologicalSex
        }
        set {
            dataCtrl.currentLoggedInUser?.biologicalSex = newValue
        }
    }
    
    func onTurnOnInterface() {
    }
    
    func onTurnOffInterface() {
    }
    
    let uploadFrameWork: StaticString = "uploader"
    func logVerbose(_ str: String) {
        DDLogVerbose(str, file: uploadFrameWork, function: uploadFrameWork)
    }
    
    func logError(_ str: String) {
        DDLogError(str, file: uploadFrameWork, function: uploadFrameWork)
    }
    
    func logInfo(_ str: String) {
        DDLogInfo(str, file: uploadFrameWork, function: uploadFrameWork)
    }
    
    func logDebug(_ str: String) {
        DDLogDebug(str, file: uploadFrameWork, function: uploadFrameWork)
    }

}
