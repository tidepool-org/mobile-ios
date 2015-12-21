//
//  Calibration.swift
//  Nutshell
//
//  Created by Brian King on 9/15/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation
import CoreData
import SwiftyJSON

class Calibration: DeviceMetadata {
    override class func fromJSON(json: JSON, moc: NSManagedObjectContext) -> Calibration? {
        if let entityDescription = NSEntityDescription.entityForName("Calibration", inManagedObjectContext: moc) {
            let me = Calibration(entity: entityDescription, insertIntoManagedObjectContext: nil)
            
            me.value = NutUtils.decimalFromJSON(json["value"].string)
            
            return me
        }
        
        return nil
    }
}
