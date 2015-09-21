//
//  Workout+CoreDataProperties.swift
//  
//
//  Created by Larry Kenyon on 9/21/15.
//
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension Workout {

    @NSManaged var subType: String?
    @NSManaged var duration: NSNumber?
    @NSManaged var calories: NSNumber?
    @NSManaged var distance: NSNumber?
    @NSManaged var source: String?
    @NSManaged var appleHealthDate: NSDate?

}
