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
            let me = NSManagedObject(entity: entityDescription, insertIntoManagedObjectContext: nil) as! SelfMonitoringGlucose
            
            me.subType = json["subType"].string
            me.value = json["value"].number
            
            return me
        }
        
        return nil
    }
}
