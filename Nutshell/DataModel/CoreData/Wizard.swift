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
            
            me.recommendedCarb = NSDecimalNumber(string: json["recommendedCarb"].string)
            me.recommendedCorrection = NSDecimalNumber(string: json["recommendedCorrection"].string)
            me.recommendedNet = NSDecimalNumber(string: json["recommendedNet"].string)
            me.bgInput = NSDecimalNumber(string: json["bgInput"].string)
            me.carbInput = NSDecimalNumber(string: json["carbInput"].string)
            me.insulinOnBoard = NSDecimalNumber(string: json["insulinOnBoard"].string)
            me.insulinCarbRatio = NSDecimalNumber(string: json["insulinCarbRatio"].string)
            me.insulinSensitivity = NSDecimalNumber(string: json["insulinSensitivity"].string)
            me.bgTargetJSON = json["bgTarget"].string
            me.bolus = json["bolus"].string
            
            return me
        }
        
        return nil
    }
}
