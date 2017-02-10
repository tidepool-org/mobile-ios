//
//  DeviceMetadata.swift
//  Nutshell
//
//  Created by Brian King on 9/15/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation
import CoreData
import SwiftyJSON

class DeviceMetadata: CommonData {
    override class func fromJSON(_ json: JSON, moc: NSManagedObjectContext) -> DeviceMetadata? {
        // This class is really a container for various sub-types. We determine the sub-type much
        // like we determined the type, which is "deviceMeta" for this object.
        var newObject: DeviceMetadata? = nil
        
        if let subType = json["subType"].string {
            switch subType {
                case "alarm": newObject = Alarm.fromJSON(json, moc: moc)
                case "prime": newObject = Prime.fromJSON(json, moc: moc)
                case "reservoirChange": newObject = ReservoirChange.fromJSON(json, moc: moc)
                case "status": newObject = Status.fromJSON(json, moc: moc)
                case "calibration": newObject = Calibration.fromJSON(json, moc: moc)
                case "timeChange": newObject = TimeChange.fromJSON(json, moc: moc)
                default: print("DeviceMetadata: Unknown subType \(subType)")
            }
        }
        
        return newObject
    }
}
