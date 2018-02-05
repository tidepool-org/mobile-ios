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
    
    // Authorization
    static let AuthorizationRequestedForBloodGlucoseSamplesKey = "authorizationRequestedForBloodGlucoseSamples"
    static let AuthorizationRequestedForBloodGlucoseSampleWritesKey = "authorizationRequestedForBloodGlucoseSampleWrites"
    static let AuthorizationRequestedForWorkoutSamplesKey = "authorizationRequestedForWorkoutSamples"
    
    // Workout anchor query
    static let WorkoutQueryAnchorKey = "WorkoutQueryAnchorKey"

    // Other
    static let LastExecutedUploaderVersionKey = "LastExecutedUploaderVersionKey"
    static let TreatAllBloodGlucoseSourceTypesAsDexcomKey = "TreatAllBloodGlucoseSourceTypesAsDexcomKey"

    // Uploads (prefix using prefixedKey helper)
    static let HasPendingUploadsKey = "HasPendingUploadsKey"
    static let Task1IsPendingKey = "Task1IsPendingKey"
    
    // Blood glucose anchor query (prefix using prefixedKey helper)
    static let BloodGlucoseQueryAnchorKey = "BloodGlucoseQueryAnchorKey"
    static let BloodGlucoseQueryAnchorLastKey = "BloodGlucoseQueryAnchorLastKey"
    static let BloodGlucoseQueryStartDateKey = "BloodGlucoseQueryStartDateKey"
    static let BloodGlucoseQueryEndDateKey = "BloodGlucoseQueryEndDateKey"

    // Stats (prefix using prefixedKey helper)
    static let StatsTotalUploadCountKey = "StatsTotalUploadCountKey"
    static let StatsLastUploadAttemptSampleCountKey = "StatsLastUploadAttemptSampleCountKey"
    static let StatsLastUploadAttemptTimeKey = "StatsLastUploadAttemptTimeKey"
    static let StatsLastUploadAttemptEarliestSampleTimeKey = "StatsLastUploadAttemptEarliestSampleTimeKey"
    static let StatsLastUploadAttemptLatestSampleTimeKey = "StatsLastUploadAttemptLatestSampleTimeKey"
    static let StatsLastSuccessfulUploadTimeKey = "StatsLastSuccessfulUploadTimeKey"
    static let StatsLastSuccessfulUploadLatestSampleTimeKey = "StatsLastSuccessfulUploadLatestSampleTimeKey"
    static let StatsLastSuccessfulUploadEarliestSampleTimeKey = "StatsLastSuccessfulUploadEarliestSampleTimeKey"
    static let StatsStartDateHistoricalBloodGlucoseSamplesKey = "StatsStartDateHistoricalBloodGlucoseSamplesKey"
    static let StatsEndDateHistoricalBloodGlucoseSamplesKey = "StatsEndDateHistoricalBloodGlucoseSamplesKey"
    static let StatsTotalDaysHistoricalBloodGlucoseSamplesKey = "StatsTotalDaysHistoricalBloodGlucoseSamplesKey"
    static let StatsCurrentDayHistoricalKey = "StatsCurrentDayHistoricalKey"
    
    // Helper for HealthKitSettings keys that are prefixed with a mode
    class func prefixedKey(prefix: String, key: String) -> String {
        return "\(prefix)-\(key)"
    }
    
}
