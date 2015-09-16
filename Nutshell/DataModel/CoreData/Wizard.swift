//
//  Wizard.swift
//  Nutshell
//
//  Created by Brian King on 9/15/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation
import CoreData
import SwiftyJSON

class Wizard: CommonData {
    override class func fromJSON(json: JSON, moc: NSManagedObjectContext) -> Wizard? {
        if let entityDescription = NSEntityDescription.entityForName("Wizard", inManagedObjectContext: moc) {
            let me = NSManagedObject(entity: entityDescription, insertIntoManagedObjectContext: nil) as! Wizard
            
            me.recommendedCarb = NutUtils.decimalFromJSON(json["recommendedCarb"].string)
            me.recommendedCorrection = NutUtils.decimalFromJSON(json["recommendedCorrection"].string)
            me.recommendedNet = NutUtils.decimalFromJSON(json["recommendedNet"].string)
            me.bgInput = NutUtils.decimalFromJSON(json["bgInput"].string)
            me.carbInput = NutUtils.decimalFromJSON(json["carbInput"].string)
            me.insulinOnBoard = NutUtils.decimalFromJSON(json["insulinOnBoard"].string)
            me.insulinCarbRatio = NutUtils.decimalFromJSON(json["insulinCarbRatio"].string)
            me.insulinSensitivity = NutUtils.decimalFromJSON(json["insulinSensitivity"].string)
            me.bgTargetJSON = json["bgTarget"].string
            me.bolus = json["bolus"].string
            
            return me
        }
        
        return nil
    }
}
