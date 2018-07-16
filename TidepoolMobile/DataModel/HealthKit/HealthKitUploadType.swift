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

import Foundation
import CocoaLumberjack
import HealthKit

class HealthKitUploadType {
    private(set) var typeName: String
    init(_ typeName: String) {
        self.typeName = typeName
    }

    //
    //  MARK: - Public data used by HealthKitManager
    //
    
    // Note: might want to keep this data with HealthKitManager, but this does make it clear that there will only be one observation and one query per type at a time...
    var sampleObservationQuery: HKObserverQuery?
    var sampleBackgroundDeliveryEnabled = false
    var sampleQueryAnchor = Int(HKAnchoredObjectQueryNoAnchor)
    
    //
    //  MARK: - Override these methods!
    //
  
    // override!
    internal func hkQuantityTypeIdentifier() -> HKQuantityTypeIdentifier? {
        return nil
    }

    // override!
    internal func filterSamples(sortedSamples: [HKSample]) -> [HKSample] {
        return sortedSamples
    }
    
    // override!
    internal func deviceModelForSourceBundleIdentifier(_ sourceBundleIdentifier: String) -> String {
        return ""
    }
    
    // override!
    internal func typeSpecificMetadata() -> [(metaKey: String, metadatum: AnyObject)] {
        return []
    }
    
    // override!
    internal func prepareDataForUpload(_ data: HealthKitUploadData) -> [[String: AnyObject]] {
        return [[String: AnyObject]]()
    }
    
}

