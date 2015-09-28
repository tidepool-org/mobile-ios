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
            var valueType: String?
            if let subtype = me.subType {
                switch subtype {
                case "normal": valueType = "normal"
                case "square": valueType = "extended"
                case "dual/square": valueType = "extended"
                case "injected": valueType = "value"
                default: print("Bolus subtype: Unknown type \(me.subType)")
                }
            }
            if (valueType != nil) {
                me.value = json[valueType!].number
            }
            me.insulin = json["insulin"].string
            
            return me
        }
        
        return nil
    }
}
