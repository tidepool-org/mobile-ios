//
//  Basal.swift
//  Nutshell
//
//  Created by Brian King on 9/15/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation
import CoreData
import SwiftyJSON

class Basal: CommonData {

    override class func fromJSON(json: JSON, moc: NSManagedObjectContext) -> Basal? {
        if let entityDescription = NSEntityDescription.entityForName("Basal", inManagedObjectContext: moc) {
            let me = NSManagedObject(entity: entityDescription, insertIntoManagedObjectContext: nil) as! Basal
            
            me.deliveryType = json["deliveryType"].string
            me.value = NSDecimalNumber(string: json["value"].string)
            me.duration = json["duration"].number
            me.insulin = json["insulin"].string
            
            return me
        }
        return nil
    }
}
