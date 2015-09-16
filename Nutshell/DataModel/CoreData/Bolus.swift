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

    override class func fromJSON(json: JSON, moc: NSManagedObjectContext) -> Bolus? {
        if let entityDescription = NSEntityDescription.entityForName("Bolus", inManagedObjectContext: moc) {
            let me = NSManagedObject(entity: entityDescription, insertIntoManagedObjectContext: nil) as! Bolus
            
            me.subType = json["subType"].string
            me.value = NutUtils.decimalFromJSON(json["value"].string)
            me.insulin = json["insulin"].string
            
            return me
        }
        
        return nil
    }
}
