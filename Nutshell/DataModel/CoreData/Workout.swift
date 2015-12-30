//
//  Workout.swift
//  
//
//  Created by Larry Kenyon on 10/6/15.
//
//

import Foundation
import CoreData


class Workout: EventItem {

// Insert code here to add functionality to your managed object subclass
    // override for eventItems that have location too!
    override func nutEventIdString() -> String {
        if let title = title {
            return "W" + title
        }
        return super.nutEventIdString()
    }

}
