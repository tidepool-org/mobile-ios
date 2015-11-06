//
//  Meal+CoreDataProperties.swift
//  
//
//  Created by Larry Kenyon on 11/3/15.
//
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension Meal {

    @NSManaged var location: String?
    @NSManaged var photo: String?
    @NSManaged var photo2: String?
    @NSManaged var photo3: String?

}
