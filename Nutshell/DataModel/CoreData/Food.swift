//
//  Food.swift
//  Nutshell
//
//  Created by Brian King on 9/15/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation
import CoreData
import SwiftyJSON

class Food: CommonData {
    override class func fromJSON(_ json: JSON, moc: NSManagedObjectContext) -> Food? {
        if let entityDescription = NSEntityDescription.entity(forEntityName: "Food", in: moc) {
            let me = Food(entity: entityDescription, insertInto: nil) 
            
            me.carbs = NutUtils.decimalFromJSON(json["carbs"].string)
            me.protein = NutUtils.decimalFromJSON(json["protein"].string)
            me.fat = NutUtils.decimalFromJSON(json["fat"].string)
            me.location = json["location"].string
            me.name = json["name"].string
            
            return me
        }
        
        return nil
    }
}
