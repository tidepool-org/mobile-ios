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

public struct TPUploaderStats {
    init(typeName: String, mode: TPUploader.Mode) {
        self.typeName = typeName
        self.mode = mode
    }
    
    public let typeName: String
    public let mode: TPUploader.Mode
    
    // Used in menu:
    public var hasSuccessfullyUploaded = false
    public var lastSuccessfulUploadTime: Date? = nil
    
    // Used in uploadUI & menu:
    public var totalDaysHistorical = 0
    public var currentDayHistorical = 0

    // Currently unused in UI...
    public var lastSuccessfulUploadEarliestSampleTime: Date? = nil
    public var lastSuccessfulUploadLatestSampleTime: Date? = nil

    public var startDateHistoricalSamples: Date? = nil
    public var endDateHistoricalSamples: Date? = nil
    
    public var totalUploadCount = 0
    
    // Not persisted... used privately
    var lastUploadAttemptEarliestSampleTime: Date? = nil
    var lastUploadAttemptLatestSampleTime: Date? = nil
    var lastUploadAttemptTime : Date? = nil
    var lastUploadAttemptSampleCount = 0
    
}
