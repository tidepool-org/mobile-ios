/*
* Copyright (c) 2018, Tidepool Project
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

class HealthKitSettings {
    // Connect to Health interface
    static let InterfaceEnabledKey = "kHealthKitInterfaceEnabledKey"
    static let InterfaceUserIdKey = "kUserIdForHealthKitInterfaceKey"
    static let InterfaceUserNameKey = "kUserNameForHealthKitInterfaceKey"
    static let HKDataUploadIdKey = "kHKDataUploadIdKey"

    // Authorization
    static let AuthorizationRequestedForUploaderSamplesKey = "authorizationRequestedForUploaderSamples"
    static let AuthorizationRequestedForBloodGlucoseSampleWritesKey = "authorizationRequestedForBloodGlucoseSampleWrites"
    
    // Workout anchor query
    static let WorkoutQueryAnchorKey = "WorkoutQueryAnchorKey"

    // Other
    static let LastExecutedUploaderVersionKey = "LastExecutedUploaderVersionKey"
    static let TreatAllBloodGlucoseSourceTypesAsDexcomKey = "TreatAllBloodGlucoseSourceTypesAsDexcomKey"
    static let HasPresentedSyncUI = "HasPresentedSyncUI"

    // Uploads (prefix using prefixedKey helper)
    static let HasPendingUploadsKey = "HasPendingUploadsKey"
    
    // HK type anchor query (prefix using prefixedKey helper)
    static let UploadQueryAnchorKey = "QueryAnchorKey"
    static let UploadQueryAnchorLastKey = "QueryAnchorLastKey"
    static let UploadQueryStartDateKey = "QueryStartDateKey"
    static let UploadQueryEndDateKey = "QueryEndDateKey"

    // Stats (prefix using prefixedKey helper)
    static let StatsTotalUploadCountKey = "StatsTotalUploadCountKey"
    static let StatsLastUploadAttemptSampleCountKey = "StatsLastUploadAttemptSampleCountKey"
    static let StatsLastUploadAttemptTimeKey = "StatsLastUploadAttemptTimeKey"
    static let StatsLastUploadAttemptEarliestSampleTimeKey = "StatsLastUploadAttemptEarliestSampleTimeKey"
    static let StatsLastUploadAttemptLatestSampleTimeKey = "StatsLastUploadAttemptLatestSampleTimeKey"
    static let StatsLastSuccessfulUploadTimeKey = "StatsLastSuccessfulUploadTimeKey"
    static let StatsLastSuccessfulUploadLatestSampleTimeKey = "StatsLastSuccessfulUploadLatestSampleTimeKey"
    static let StatsLastSuccessfulUploadEarliestSampleTimeKey = "StatsLastSuccessfulUploadEarliestSampleTimeKey"
    static let StatsStartDateHistoricalSamplesKey = "StatsStartDateHistoricalSamplesKey"
    static let StatsEndDateHistoricalSamplesKey = "StatsEndDateHistoricalSamplesKey"
    static let StatsTotalDaysHistoricalSamplesKey = "StatsTotalDaysHistoricalSamplesKey"
    static let StatsCurrentDayHistoricalKey = "StatsCurrentDayHistoricalKey"
    
    // Helper for HealthKitSettings keys that are prefixed with a mode and/or upload type string
    class func prefixedKey(prefix: String, type: String, key: String) -> String {
        let result = "\(prefix)-\(type)\(key)"
        //print("prefixedKey: \(result)")
        return result
    }
    
}
