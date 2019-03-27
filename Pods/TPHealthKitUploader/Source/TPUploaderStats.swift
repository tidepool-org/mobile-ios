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
