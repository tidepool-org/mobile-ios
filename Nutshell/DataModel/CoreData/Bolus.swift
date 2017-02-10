//
//  Bolus.swift
//  Nutshell
//
//  Created by Brian King on 9/15/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation
import CoreData
import SwiftyJSON

class Bolus: CommonData {

    override class func fromJSON(_ json: JSON, moc: NSManagedObjectContext) -> Bolus? {
        if let entityDescription = NSEntityDescription.entity(forEntityName: "Bolus", in: moc) {
            let me = Bolus(entity: entityDescription, insertInto: nil)
            
            me.normal = json["normal"].number
            me.extended = json["extended"].number
            me.duration = json["duration"].number
            // for an interrupted bolus, expectedNormal will exist
            me.expectedNormal = json["expectedNormal"].number
            // for an interrupted extended bolus, these two fields will exist
            me.expectedExtended = json["expectedExtended"].number
            me.expectedDuration = json["expectedDuration"].number
            
            var value: Float = 0.0
            if let normal = me.normal {
                value = value + Float(normal)
            }
            if let extended = me.extended {
                value = value + Float(extended)
            }
            me.value = NSNumber(value: value as Float)
            // The following are unused...
            me.subType = json["subType"].string
            me.insulin = json["insulin"].string
            
            return me
        }
        
        return nil
    }
}
