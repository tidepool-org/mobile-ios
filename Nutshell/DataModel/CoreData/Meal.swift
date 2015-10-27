//
//  Meal.swift
//  
//
//  Created by Larry Kenyon on 10/6/15.
//
//

import Foundation
import CoreData


class Meal: EventItem {

    // override for eventItems that have location too!
    override func nutEventIdString() -> String {
        if let title = title,  location = location {
            return title + location
        }
        return super.nutEventIdString()
    }

}
