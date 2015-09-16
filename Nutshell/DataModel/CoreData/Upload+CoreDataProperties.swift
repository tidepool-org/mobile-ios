//
//  Upload+CoreDataProperties.swift
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

extension Upload {

    @NSManaged var timezone: String?
    @NSManaged var version: String?
    @NSManaged var byUser: String?
    @NSManaged var deviceTagsJSON: String?
    @NSManaged var deviceManufacturersJSON: String?
    @NSManaged var deviceModel: String?
    @NSManaged var deviceSerialNumber: String?

}
