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

class HealthKitUploadTypeBloodGlucose: HealthKitUploadType {
    init() {
        super.init("BloodGlucose")
    }

    // MARK: Private
    
    internal override func filterSamples(sortedSamples: [HKSample]) -> [HKSample] {
        DDLogVerbose("trace")
        
        // Filter out non-Dexcom data
        var filteredSamples = [HKSample]()
        
        for sample in sortedSamples {
            let sourceRevision = sample.sourceRevision
            let source = sourceRevision.source
            let treatAllBloodGlucoseSourceTypesAsDexcom = UserDefaults.standard.bool(forKey: HealthKitSettings.TreatAllBloodGlucoseSourceTypesAsDexcomKey)
            if source.name.lowercased().range(of: "dexcom") == nil && !treatAllBloodGlucoseSourceTypesAsDexcom {
                DDLogInfo("Ignoring non-Dexcom glucose data from source: \(source.name)")
                continue
            }
            
            filteredSamples.append(sample)
        }
        
        return filteredSamples
    }
    
    // override!
    internal override func typeSpecificMetadata() -> [(metaKey: String, metadatum: AnyObject)] {
        DDLogVerbose("trace")
        var metadata: [(metaKey: String, metadatum: AnyObject)] = []
        metadata.append((metaKey: "deviceTags", metadatum: ["cgm"] as AnyObject))
        metadata.append((metaKey: "deviceManufacturers", metadatum: ["Dexcom"] as AnyObject))
        return metadata
    }
    
    internal override func deviceModelForSourceBundleIdentifier(_ sourceBundleIdentifier: String) -> String {
        var deviceModel = ""
        
        // TODO: uploader - what about G6? others?
        if sourceBundleIdentifier.lowercased().range(of: "com.dexcom.cgm") != nil {
            deviceModel = "DexG5"
        } else if sourceBundleIdentifier.lowercased().range(of: "com.dexcom.share2") != nil {
            deviceModel = "DexG4"
        } else {
            DDLogError("Unknown Dexcom sourceBundleIdentifier: \(sourceBundleIdentifier)")
            deviceModel = "DexUnknown: \(sourceBundleIdentifier)"
        }
        
        return "HealthKit_\(deviceModel)"
    }

    internal override func hkQuantityTypeIdentifier() -> HKQuantityTypeIdentifier {
        return HKQuantityTypeIdentifier.bloodGlucose
    }

}

