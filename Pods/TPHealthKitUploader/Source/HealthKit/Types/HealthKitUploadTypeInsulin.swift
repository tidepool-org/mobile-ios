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

    override func prepareDataForUpload(_ sample: HKSample) -> [String: AnyObject]? {
        DDLogInfo("insulin prepareDataForUpload")
            if let quantitySample = sample as? HKQuantitySample {
                
                var sampleToUploadDict = [String: AnyObject]()

                let reason = sample.metadata?[HKMetadataKeyInsulinDeliveryReason] as? HKInsulinDeliveryReason.RawValue
                if reason == nil {
                    //TODO: report as data error?
                    DDLogError("Skip insulin entry that has no reason!")
                    return nil
                }
                let value = quantitySample.quantity.doubleValue(for: .internationalUnit())
                switch reason {
                case HKInsulinDeliveryReasonBasal:
                    sampleToUploadDict["type"] = "basal" as AnyObject?
                    let seconds = sample.endDate.timeIntervalSince(sample.startDate) // duration in seconds
                    let durationInMS = seconds*1000 // convert to milliseconds
                    // service syntax check: [required; 0 <= duration <= 86400000]
                    if durationInMS <= 0 {
                        //TODO: report as data error?
                        DDLogError("Skip basal insulin entry with non-positive duration: \(durationInMS)")
                        if !kDebugTurnOffSampleChecks {
                            return nil
                        }
                    }
                    // 7 days max!
                    if durationInMS > 604800000 {
                        DDLogError("Skip basal insulin entry with > 7-day duration: \(durationInMS)")
                        if !kDebugTurnOffSampleChecks {
                            return nil
                        }
                    }
                    sampleToUploadDict["duration"] = Int(durationInMS) as AnyObject
 
                    let hours = seconds/3600.0
                    let rate = value/hours
                    // service syntax check: [required; 0.0 <= rate <= 100.0 - note docs wrongly spec'ed 20.0]
                    if rate < 0.0 || rate > 100.0 {
                        DDLogError("Skip basal insulin entry with out-of-range rate: \(rate)")
                        if !kDebugTurnOffSampleChecks {
                            return nil
                        }
                    }
                    sampleToUploadDict["rate"] = rate as AnyObject
                    DDLogInfo("insulin basal value = \(String(describing: value))")
                    sampleToUploadDict["deliveryType"] = "temp" as AnyObject?
                    if let scheduledRate = sample.metadata?[MetadataKeyScheduledBasalRate] as? HKQuantity {
                        let unitsPerHour = HKUnit.internationalUnit().unitDivided(by: .hour())
                        if scheduledRate.is(compatibleWith: unitsPerHour) {
                            let scheduledRateValue = scheduledRate.doubleValue(for: unitsPerHour)
                            // service syntax check: [required; 0.0 <= rate <= 20.0]
                            if value >= 0.0 && value <= 100.0 {
                                let suppressed: [String : Any] = [
                                    "type": "basal",
                                    "deliveryType": "scheduled",
                                    "rate": scheduledRateValue
                                ]
                                sampleToUploadDict["suppressed"] = suppressed as AnyObject?
                            }
                        }
                    }

                case HKInsulinDeliveryReasonBolus:
                    // service syntax check: [required; 0.0 <= normal <= 100.0]
                    if value < 0.0 || value > 100.0 {
                        DDLogError("Skip bolus insulin entry with out-of-range normal: \(value)")
                        if !kDebugTurnOffSampleChecks {
                            return nil
                        }
                    }
                    sampleToUploadDict["type"] = "bolus" as AnyObject?
                    sampleToUploadDict["subType"] = "normal" as AnyObject?
                    sampleToUploadDict["normal"] = value as AnyObject
                    DDLogInfo("insulin bolus value = \(String(describing: value))")

                default:
                    //TODO: report as data error?
                    DDLogError("Skip insulin entry with unknown key for reason: \(String(describing: reason))")
                    return nil
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
                
                // return sample if valid...
                return(sampleToUploadDict)
            } else {
                DDLogError("Encountered HKSample that was not an HKQuantitySample!")
                return nil
            }
    }

}
