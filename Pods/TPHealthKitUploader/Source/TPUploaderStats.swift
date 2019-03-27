//
//  TPUploaderStats.swift
//  TPHealthKitUploader
//
//  Created by Larry Kenyon on 3/6/19.
//  Copyright © 2019 Tidepool. All rights reserved.
//

import Foundation

public struct TPUploaderStats {
    init(typeName: String, mode: TPUploader.Mode) {
        self.typeName = typeName
        self.mode = mode
    }
    
    public let typeName: String
    public let mode: TPUploader.Mode
    
    // Used in menu:
    public var hasSuccessfullyUploaded = false
    public var lastSuccessfulUploadTime = Date.distantPast
    
    // Used in uploadUI & menu:
    public var totalDaysHistorical = 0
    public var currentDayHistorical = 0

    // Currently unused in UI...
    public var lastUploadAttemptTime = Date.distantPast
    public var lastUploadAttemptSampleCount = 0
    public var lastSuccessfulUploadEarliestSampleTime = Date.distantPast
    public var lastSuccessfulUploadLatestSampleTime = Date.distantPast
    
    public var startDateHistoricalSamples = Date.distantPast
    public var endDateHistoricalSamples = Date.distantPast
    
    public var totalUploadCount = 0
    public var lastUploadAttemptEarliestSampleTime = Date.distantPast
    public var lastUploadAttemptLatestSampleTime = Date.distantPast
}
