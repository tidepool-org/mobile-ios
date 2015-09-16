//
//  Settings+CoreDataProperties.swift
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

extension Settings {

    @NSManaged var activeSchedule: String?
    @NSManaged var unitsCarb: String?
    @NSManaged var unitsBG: String?
    @NSManaged var basalSchedulesJSON: String?
    @NSManaged var carbRatioJSON: String?
    @NSManaged var carbRatiosJSON: String?
    @NSManaged var insulinSensitivityJSON: String?
    @NSManaged var insulinSensitivitiesJSON: String?
    @NSManaged var bgTargetJSON: String?
    @NSManaged var bgTargetsJSON: String?

}
