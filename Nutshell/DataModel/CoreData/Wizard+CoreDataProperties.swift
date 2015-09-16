//
//  Wizard+CoreDataProperties.swift
//  Nutshell
//
//  Created by Brian King on 9/15/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension Wizard {

    @NSManaged var recommendedCarb: NSDecimalNumber?
    @NSManaged var recommendedCorrection: NSDecimalNumber?
    @NSManaged var recommendedNet: NSDecimalNumber?
    @NSManaged var bgInput: NSDecimalNumber?
    @NSManaged var carbInput: NSDecimalNumber?
    @NSManaged var insulinOnBoard: NSDecimalNumber?
    @NSManaged var insulinCarbRatio: NSDecimalNumber?
    @NSManaged var insulinSensitivity: NSDecimalNumber?
    @NSManaged var bgTargetJSON: String?
    @NSManaged var bolus: String?

}
