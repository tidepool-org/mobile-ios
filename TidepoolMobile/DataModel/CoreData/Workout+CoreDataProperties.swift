//
//  Workout+CoreDataProperties.swift
//  
//
//  Created by Larry Kenyon on 10/6/15.
//
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension Workout {

    @NSManaged var appleHealthDate: Date?
    @NSManaged var calories: NSNumber?
    @NSManaged var distance: NSNumber?
    @NSManaged var duration: NSNumber?
    @NSManaged var source: String?
    @NSManaged var subType: String?

}
