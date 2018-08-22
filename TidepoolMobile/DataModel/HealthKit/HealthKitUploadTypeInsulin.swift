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

//
// MARK: - LoopKit defines
//

/// Defines the scheduled basal insulin rate during the time of the basal delivery sample
let MetadataKeyScheduledBasalRate = "com.loopkit.InsulinKit.MetadataKeyScheduledBasalRate"

/// A crude determination of whether a sample was written by LoopKit, in the case of multiple LoopKit-enabled app versions on the same phone.
let MetadataKeyHasLoopKitOrigin = "HasLoopKitOrigin"

// only in 11.0, not currently found as enum... TODO!
let HKInsulinDeliveryReasonBasal: Int = 1
let HKInsulinDeliveryReasonBolus: Int = 2

//
// MARK: -
//
class HealthKitUploadTypeInsulin: HealthKitUploadType {
    init() {
        super.init("Insulin")
     }

    internal override func hkSampleType() -> HKSampleType? {
        return HKSampleType.quantityType(forIdentifier: HKQuantityTypeIdentifier.insulinDelivery)
    }

    internal override func filterSamples(sortedSamples: [HKSample]) -> [HKSample] {
        DDLogVerbose("trace")
        // For insulin, don't filter anything out yet!
        return sortedSamples
    }
    
    internal override func prepareDataForUpload(_ data: HealthKitUploadData) -> [[String: AnyObject]] {
        DDLogInfo("insulin prepareDataForUpload")
        var samplesToUploadDictArray = [[String: AnyObject]]()
        for sample in data.filteredSamples {
            if let quantitySample = sample as? HKQuantitySample {
                
                var sampleToUploadDict = [String: AnyObject]()

                let reason = sample.metadata?[HKMetadataKeyInsulinDeliveryReason] as? HKInsulinDeliveryReason.RawValue
                if reason == nil {
                    //TODO: report as data error?
                    DDLogError("Skip insulin entry that has no reason!")
                    continue
                }
                let value = quantitySample.quantity.doubleValue(for: .internationalUnit()) as AnyObject?
                
                switch reason {
                case HKInsulinDeliveryReasonBasal:
                    sampleToUploadDict["type"] = "basal" as AnyObject?
                    sampleToUploadDict["rate"] = value
                    DDLogInfo("insulin basal value = \(String(describing: value))")
                    sampleToUploadDict["deliveryType"] = "temp" as AnyObject?
                    let duration = sample.endDate.timeIntervalSince(sample.startDate)*1000 // convert to milliseconds
                    if duration <= 0 {
                        //TODO: report as data error?
                        DDLogError("Skip basal insulin entry with non-positive duration: \(duration)")
                        continue
                    }
                    sampleToUploadDict["duration"] = Int(duration) as AnyObject
                    if let scheduledRate = sample.metadata?[MetadataKeyScheduledBasalRate] as? HKQuantity {
                        let unitsPerHour = HKUnit.internationalUnit().unitDivided(by: .hour())
                        if scheduledRate.is(compatibleWith: unitsPerHour) {
                            let scheduledRateValue = scheduledRate.doubleValue(for: unitsPerHour)
                            let suppressed: [String : Any] = [
                                "type": "basal",
                                "deliveryType": "scheduled",
                                "rate": scheduledRateValue
                            ]
                            sampleToUploadDict["suppressed"] = suppressed as AnyObject?
                        }
                    }

                case HKInsulinDeliveryReasonBolus:
                    sampleToUploadDict["type"] = "bolus" as AnyObject?
                    sampleToUploadDict["subType"] = "normal" as AnyObject?
                    sampleToUploadDict["normal"] = value
                    DDLogInfo("insulin bolus value = \(String(describing: value))")

                default:
                    //TODO: report as data error?
                    DDLogError("Unknown key for insulin reason: \(String(describing: reason))")
                    continue
                }
                
                // Add fields common to all types: guid, deviceId, time, and origin
                super.addCommonFields(sampleToUploadDict: &sampleToUploadDict, sample: sample)

                // Add sample metadata payload props
                if var metadata = sample.metadata {
                    // removeHKMetadataKeyInsulinDeliveryReason from metadata as this is already reflected in the basal vs bolus type
                    //metadata.removeValue(forKey: HKMetadataKeyInsulinDeliveryReason)
                    // remove MetadataKeyScheduledBasalRate if present as this will be in the suppressed block
                    //metadata.removeValue(forKey: MetadataKeyScheduledBasalRate)
                    // add any remaining metadata values as the payload struct
                    addMetadata(&metadata, sampleToUploadDict: &sampleToUploadDict)
                }
                
                // Add sample if valid...
                samplesToUploadDictArray.append(sampleToUploadDict)
            }
        }
        return samplesToUploadDictArray
    }

}
