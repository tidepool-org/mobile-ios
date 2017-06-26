//
//  Food+CoreDataProperties.swift
//  TidepoolMobile
//
//  Created by Brian King on 9/15/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension Food {

    @NSManaged var carbs: NSDecimalNumber?
    @NSManaged var protein: NSDecimalNumber?
    @NSManaged var fat: NSDecimalNumber?
    @NSManaged var location: String?
    @NSManaged var name: String?

}
