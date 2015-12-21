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
            let me = Basal(entity: entityDescription, insertIntoManagedObjectContext: nil)
            
            me.deliveryType = json["deliveryType"].string
            me.value = json["rate"].number
            me.duration = json["duration"].number
            me.insulin = json["insulin"].string
            // TODO: change field name to "scheduledRate"
            me.percent = nil
            
            if let deliveryType = me.deliveryType {
                if deliveryType == "temp" {
                    let suppressedRate: NSNumber? = json["suppressed"]["rate"].number
                    if suppressedRate == nil {
                        NSLog("DATA ERR: No suppressed rate in temp basal!")
                        // TODO: Deal with nested suppressed arrays - need to march up them to find the innermost value. Data may have a temp rate of 0, and multiple suppressions all at zero.
                    } else {
                        me.percent = suppressedRate
                    }
                }
            }
            
            return me
        }
        return nil
    }
}
