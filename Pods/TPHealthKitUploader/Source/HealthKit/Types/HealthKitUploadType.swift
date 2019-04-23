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

// NOTE: should be false when checked in!!!
let kDebugTurnOffSampleChecks = false

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
    //  MARK: - Public methods
    //
    
    // override!
    internal func hkSampleType() -> HKSampleType? {
        return nil
    }
    
    // override!
    internal func prepareDataForUpload(_ sample: HKSample) -> [String: AnyObject]? {
        return [String: AnyObject]()
    }

    internal func prepareDataForDelete(_ deletedSample: HKDeletedObject) -> [String: AnyObject] {
        var sampleToDeleteDict = [String: AnyObject]()
        let origin: [String: AnyObject] = [
            "id": deletedSample.uuid.uuidString as AnyObject
        ]
        sampleToDeleteDict["origin"] = origin as AnyObject
        return sampleToDeleteDict
    }

    //
    //  MARK: - Subclass utility functions
    //
    internal let dateFormatter = DateFormatter()
    internal let iso8601dateZuluTime: String = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"

    internal func addCommonFields(sampleToUploadDict: inout [String: AnyObject], sample: HKSample) {
        sampleToUploadDict["time"] = dateFormatter.isoStringFromDate(sample.startDate, zone: TimeZone(secondsFromGMT: 0), dateFormat: iso8601dateZuluTime) as AnyObject?
        
        // add optional application origin
        if let origin = sampleOrigin(sample) {
            // Don't let invalid json crash the app during later serialization!
            if JSONSerialization.isValidJSONObject(origin) {
                // Add metadata values as the payload struct
                sampleToUploadDict["origin"] = origin as AnyObject
            } else {
                DDLogError("Invalid origin failed to serialize: \(String(describing:origin)), for type: \(typeName), guid: \(sampleToUploadDict["guid"] ?? "no guid" as AnyObject)")
            }
        }
    }
    
    internal func addMetadata(_ metadata: inout [String: Any], sampleToUploadDict: inout [String: AnyObject]) {
        
        if metadata.isEmpty {
            return
        }
        for (key, value) in metadata {
            // TODO: document this time format adjust!
            if let dateValue = value as? Date {
                metadata[key] = dateFormatter.isoStringFromDate(dateValue, zone: TimeZone(secondsFromGMT: 0), dateFormat: iso8601dateZuluTime)
            }
            // HKQuantity values won't serialize as json, so convert to string here...
            if let quantityValue = value as? HKQuantity {
                metadata[key] = String(describing: quantityValue)
            }
        }
        
        // Don't let invalid json crash the app during later serialization!
        if JSONSerialization.isValidJSONObject(metadata) {
            // Add metadata values as the payload struct
            sampleToUploadDict["payload"] = metadata as AnyObject?
        } else {
            DDLogError("Invalid metadata failed to serialize: \(String(describing:metadata)), for type: \(typeName), guid: \(sampleToUploadDict["guid"] ?? "no guid" as AnyObject)")
        }

    }
    
    internal func sampleOrigin(_ sample: HKSample) -> [String: AnyObject]? {
        
        var origin: [String: AnyObject] = [
            "id": sample.uuid.uuidString as AnyObject,
            "name": "com.apple.HealthKit" as AnyObject,
            "type": "service" as AnyObject
        ]

        if let userEntered = sample.metadata?[HKMetadataKeyWasUserEntered] as? Bool {
            if userEntered {
                origin["type"] = "service" as AnyObject
            }
        }
        
        var payloadDict = [String: AnyObject]()
        
        //let sourceBundleName = sample.sourceRevision.source.bundleIdentifier.lowercased()
        //TODO: sync syntax check with service!
        //if isValidReverseDomain(sourceBundleName) {
        //    payloadDict["sourceRevision"] = sourceBundleName as AnyObject
        //}
        
        var sourceRevisionDict = [String: AnyObject]()
        var sourceRevSrcDict = [String: String]()
        sourceRevSrcDict["bundleIdentifier"] = sample.sourceRevision.source.bundleIdentifier
        sourceRevSrcDict["name"] = sample.sourceRevision.source.name
        sourceRevisionDict["source"] = sourceRevSrcDict as AnyObject
        if let version = sample.sourceRevision.version {
            sourceRevisionDict["version"] = version as AnyObject
        }
        if let productType = sample.sourceRevision.productType {
            sourceRevisionDict["productType"] = productType as AnyObject
        }
        let version = sample.sourceRevision.operatingSystemVersion
        let versionString = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        sourceRevisionDict["operatingSystemVersion"] = versionString as AnyObject
        payloadDict["sourceRevision"] = sourceRevisionDict as AnyObject
        
        if let device = sample.device {
            var deviceDict = [String: String]()
            if let name = device.name {
                deviceDict["name"] = name
            }
            if let model = device.model {
                deviceDict["model"] = model
            }
            if let manufacturer = device.manufacturer {
                deviceDict["manufacturer"] = manufacturer
            }
            if let udiDeviceIdentifier = device.udiDeviceIdentifier {
                deviceDict["udiDeviceIdentifier"] = udiDeviceIdentifier
            }
            if let localIdentifier = device.localIdentifier {
                deviceDict["localIdentifier"] = localIdentifier
            }
            if let firmwareVersion = device.firmwareVersion {
                deviceDict["firmwareVersion"] = firmwareVersion
            }
            if let hardwareVersion = device.hardwareVersion {
                deviceDict["hardwareVersion"] = hardwareVersion
            }
            if let softwareVersion = device.softwareVersion {
                deviceDict["softwareVersion"] = softwareVersion
            }
            if !deviceDict.isEmpty {
                payloadDict["device"] = deviceDict as AnyObject
            }
        }
        
        if !payloadDict.isEmpty {
            origin["payload"] = payloadDict as AnyObject
        }
        
        return origin
    }
    
}

