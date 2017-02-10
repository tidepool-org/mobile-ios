//
//  Settings.swift
//  Nutshell
//
//  Created by Brian King on 9/15/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation
import CoreData
import SwiftyJSON

class Settings: CommonData {
    override class func fromJSON(_ json: JSON, moc: NSManagedObjectContext) -> Settings? {
        if let entityDescription = NSEntityDescription.entity(forEntityName: "Settings", in: moc) {
            let me = Settings(entity: entityDescription, insertInto: nil)
            
            me.activeSchedule = json["activeSchedule"].string
            me.unitsCarb = json["unitsCarb"].string
            me.unitsBG = json["unitsBG"].string
            me.basalSchedulesJSON = json["basalSchedules"].string
            me.carbRatioJSON = json["carbRatio"].string
            me.carbRatiosJSON = json["carbRatios"].string
            me.insulinSensitivityJSON = json["insulinSensitivity"].string
            me.insulinSensitivitiesJSON = json["insulinSensitivities"].string
            me.bgTargetJSON = json["bgTarget"].string
            me.bgTargetsJSON = json["bgTargets"].string
            
            return me
        }
        
        return nil
    }
}
