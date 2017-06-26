//
//  Activity.swift
//  TidepoolMobile
//
//  Created by Brian King on 9/15/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation
import CoreData
import SwiftyJSON

class Activity: CommonData {

    override class func fromJSON(_ json: JSON, moc: NSManagedObjectContext) -> Activity? {
        if let entityDescription = NSEntityDescription.entity(forEntityName: "Activity", in: moc) {
            let me = Activity(entity: entityDescription, insertInto: nil) 
            
            me.subType = json["subType"].string
            me.duration = json["duration"].number
            me.intensityMet = TidepoolMobileUtils.decimalFromJSON(json["intensityMet"].string)
            me.intensityBorg = TidepoolMobileUtils.decimalFromJSON(json["intensityBorg"].string)
            me.intensityHr = TidepoolMobileUtils.decimalFromJSON(json["intensityHr"].string)
            me.intensityWatts = TidepoolMobileUtils.decimalFromJSON(json["intensityWatts"].string)
            me.location = json["location"].string
            
            return me
        }
        
        return nil
    }

}
