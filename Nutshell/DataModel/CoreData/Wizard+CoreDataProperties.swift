//
//  Wizard+CoreDataProperties.swift
//  
//
//  Created by Larry Kenyon on 9/24/15.
//
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension Wizard {

    @NSManaged var bgInput: NSNumber?
    @NSManaged var bolus: String?
    @NSManaged var carbInput: NSNumber?
    @NSManaged var insulinOnBoard: NSNumber?
    @NSManaged var insulinSensitivity: NSNumber?
    @NSManaged var recommendedNet: NSNumber?
}
