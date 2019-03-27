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
import HealthKit

class HealthKitUploadTypeCarb: HealthKitUploadType {
    init() {
        super.init("Carb")
    }

    internal override func hkSampleType() -> HKSampleType? {
        return HKSampleType.quantityType(forIdentifier: HKQuantityTypeIdentifier.dietaryCarbohydrates)
    }    

    internal override func filterSamples(sortedSamples: [HKSample]) -> [HKSample] {
        DDLogVerbose("\(#function)")
        // For carbs, don't filter anything out yet!
        return sortedSamples
    }
    
    // Service validation parameters
    private let CarbohydrateNetGramsMaximum: Double  = 1000.0
    private let CarbohydrateNetGramsMinimum: Double  = 0.0
    private let NameLengthMaximum: Int = 100

    internal override func prepareDataForUpload(_ data: HealthKitUploadData) -> [[String: AnyObject]] {
        DDLogInfo("carb prepareDataForUpload")
        var samplesToUploadDictArray = [[String: AnyObject]]()
        for sample in data.filteredSamples {
            var sampleToUploadDict = [String: AnyObject]()
            sampleToUploadDict["type"] = "food" as AnyObject?
            // Add fields common to all types: guid, deviceId, time, and origin
            super.addCommonFields(sampleToUploadDict: &sampleToUploadDict, sample: sample)

            if let quantitySample = sample as? HKQuantitySample {
                let unit = HKUnit(from: "g")
                let value = quantitySample.quantity.doubleValue(for: unit)
                DDLogInfo("carb value: \(String(describing: value))")
                // service syntax check for carb net in optional nutrition field: [float64; required; 0.0 <= x <= 1000.0]
                if value >= CarbohydrateNetGramsMinimum && value <= CarbohydrateNetGramsMaximum {
                    var nutrition = [String: AnyObject]()
                    let carbs = [
                        "net": value,
                        "units": "grams"
                        ] as [String : Any]
                    nutrition["carbohydrate"] = carbs as AnyObject?
                    sampleToUploadDict["nutrition"] = nutrition as AnyObject?
                } else {
                    //TODO: log this some more obvious way? Should entire sample be skipped?
                    DDLogError("Carb sample with out-of-range value: \(value), skipping nutrition field!")
                }
                
                // Add sample metadata payload props
                if var metadata = sample.metadata {
                    if let foodType = metadata[HKMetadataKeyFoodType] as? String {
                        // service syntax for name: [string; optional; 0 < len <= 100]
                        if !foodType.isEmpty {
                            sampleToUploadDict["name"] = foodType.prefix(NameLengthMaximum) as AnyObject
                            metadata.removeValue(forKey: HKMetadataKeyFoodType)
                        }
                    }
                    // Add metadata values as the payload struct
                    addMetadata(&metadata, sampleToUploadDict: &sampleToUploadDict)
                }

                // Add sample if valid...
                samplesToUploadDictArray.append(sampleToUploadDict)
            }
            
        }
        return samplesToUploadDictArray
    }
}

