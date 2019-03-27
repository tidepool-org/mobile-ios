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
        DDLogInfo("\(#function) - TPUploaderConfigInfo protocol, returning: \(result)")
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

    //
    // MARK: - Utilities used by client
    //
    
    // TODO: move to uploader framework?
    
    func lastHistoricalUpload() -> (current: Int?, total: Int?) {
        let historicalStats = uploader().historicalUploadStats()
        var current: Int?
        var total: Int?
        var lastUpload: Date?
        for stat in historicalStats {
            // For now just show stats for the last type uploaded...
            if stat.hasSuccessfullyUploaded {
                
                if current == nil || total == nil || lastUpload == nil {
                    current = stat.currentDayHistorical
                    total = stat.totalDaysHistorical
                    lastUpload = stat.lastSuccessfulUploadTime
                } else {
                    if lastUpload!.compare(stat.lastSuccessfulUploadTime) == .orderedAscending {
                        current = stat.currentDayHistorical
                        total = stat.totalDaysHistorical
                        lastUpload = stat.lastSuccessfulUploadTime
                    }
                }
            }
        }
        return (current: current, total: total)
    }
}
