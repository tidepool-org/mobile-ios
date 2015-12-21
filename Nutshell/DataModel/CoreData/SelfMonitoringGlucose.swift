//
//  SelfMonitoringGlucose.swift
//  Nutshell
//
//  Created by Brian King on 9/15/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation
import CoreData
import SwiftyJSON

class SelfMonitoringGlucose: CommonData {
    override class func fromJSON(json: JSON, moc: NSManagedObjectContext) -> SelfMonitoringGlucose? {
        if let entityDescription = NSEntityDescription.entityForName("SelfMonitoringGlucose", inManagedObjectContext: moc) {
            let me = SelfMonitoringGlucose(entity: entityDescription, insertIntoManagedObjectContext: nil)
            
            me.subType = json["subType"].string
            
            if let value = json["value"].number {
                me.value = value
            } else {
                print("smbg record with missing value skipped")
                return nil
            }
            
            if let units = json["units"].string {
                if units != "mmol/L" {
                    print("smbg record with incorrect units skipped: \(units)")
                    return nil
                }
            } else {
                print("smbg record with no units field, assuming mmol/L - value: \(me.value)")
            }
            
            return me
        }
        
        return nil
    }
}
