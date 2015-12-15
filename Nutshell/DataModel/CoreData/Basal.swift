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
            me.value = json["rate"].number
            me.duration = json["duration"].number
            me.insulin = json["insulin"].string
            me.percent = nil
            
            if let deliveryType = me.deliveryType {
                if deliveryType == "temp" {
                    me.percent = json["percent"].number
                    if me.percent == nil {
                        NSLog("DATA ERR: No percent field in temp basal!")
                    }
                    // just checking...
                    let suppressedRate = json["suppressed"]["rate"]
                    if suppressedRate == nil {
                        NSLog("DATA ERR: No suppressed rate in temp basal!")
                    }
                }
            }
            
            return me
        }
        return nil
    }
}
