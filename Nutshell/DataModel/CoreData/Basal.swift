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
            me.suppressedRate = nil
 
            // Deal with nested suppressed arrays - need to march up them to find the innermost value. Data may have a temp rate of 0, and multiple suppressions all at zero. Only innermost will have a delivery type of 'scheduled'.
            func getScheduledSuppressed(json: [String: JSON]) -> NSNumber? {
                if let devType = json["deliveryType"]?.string {
                    if devType == "scheduled" {
                        return json["rate"]?.number
                    }
                    if let suppressedRec = json["suppressed"]?.dictionary {
                        return getScheduledSuppressed(suppressedRec)
                    }
                }
                return nil
            }

            if let deliveryType = me.deliveryType {
                if deliveryType == "temp" {
                    var suppressedRate: NSNumber?
                    let suppressedRec = json["suppressed"].dictionary
                    if let suppressedRec = suppressedRec {
                        suppressedRate = getScheduledSuppressed(suppressedRec)
                    }
                    if suppressedRate == nil {
                        //NSLog("DATA ERR: No suppressed rate in temp basal!")
                    } else {
                        me.suppressedRate = suppressedRate
                    }
                }
            }
            
            return me
        }
        return nil
    }
}
