//
//  Bolus+CoreDataProperties.swift
//  
//
//  Created by Larry Kenyon on 12/15/15.
//
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension Bolus {

    @NSManaged var insulin: String?
    @NSManaged var subType: String?
    @NSManaged var value: NSNumber?
    @NSManaged var normal: NSNumber?
    @NSManaged var extended: NSNumber?
    @NSManaged var duration: NSNumber?
    @NSManaged var expectedDuration: NSNumber?
    @NSManaged var expectedExtended: NSNumber?

}
