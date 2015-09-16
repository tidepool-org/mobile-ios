//
//  BloodKetone.swift
//  Nutshell
//
//  Created by Brian King on 9/15/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation
import CoreData
import SwiftyJSON

class BloodKetone: CommonData {
    override class func fromJSON(json: JSON, moc: NSManagedObjectContext) -> BloodKetone? {
        if let entityDescription = NSEntityDescription.entityForName("BloodKetone", inManagedObjectContext: moc) {
            let me = NSManagedObject(entity: entityDescription, insertIntoManagedObjectContext: nil) as! BloodKetone
            
            me.value = NSDecimalNumber(string: json["value"].string)
            
            return me
        }
        return nil
    }
}
