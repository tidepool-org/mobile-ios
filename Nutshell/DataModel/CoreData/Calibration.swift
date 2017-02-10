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
    override class func fromJSON(_ json: JSON, moc: NSManagedObjectContext) -> Calibration? {
        if let entityDescription = NSEntityDescription.entity(forEntityName: "Calibration", in: moc) {
            let me = Calibration(entity: entityDescription, insertInto: nil)
            
            me.value = NutUtils.decimalFromJSON(json["value"].string)
            
            return me
        }
        
        return nil
    }
}
