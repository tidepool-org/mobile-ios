//
//  Wizard.swift
//  TidepoolMobile
//
//  Created by Brian King on 9/15/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation
import CoreData
import SwiftyJSON

class Wizard: CommonData {
    override class func fromJSON(_ json: JSON, moc: NSManagedObjectContext) -> Wizard? {
        if let entityDescription = NSEntityDescription.entity(forEntityName: "Wizard", in: moc) {
            let me = Wizard(entity: entityDescription, insertInto: nil)

            // Note: this is a quick and dirty way of adding food carb visualization - turning a food sample into a wizard that has a carb value but no associated bolus, allowing the graphing of wizard carbs to be leveraged.
            if json["type"].string == "food" {
                guard let carbs = json["nutrition"]["carbohydrate"]["net"].number else {
                    return nil
                }
                me.carbInput = carbs
                return me
            }
            me.bgInput = json["bgInput"].number
            me.carbInput = json["carbInput"].number
            me.insulinOnBoard = json["insulinOnBoard"].number
            me.recommendedNet = json["recommended"]["net"].number
            me.insulinSensitivity = json["insulinSensitivity"].number
            me.bolus = json["bolus"].string
            
            return me
        }
        
        return nil
    }
}
