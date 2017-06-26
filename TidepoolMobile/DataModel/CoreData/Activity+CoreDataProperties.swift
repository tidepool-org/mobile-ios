//
//  Activity+CoreDataProperties.swift
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

extension Activity {

    @NSManaged var subType: String?
    @NSManaged var duration: NSNumber?
    @NSManaged var intensityMet: NSDecimalNumber?
    @NSManaged var intensityBorg: NSDecimalNumber?
    @NSManaged var intensityHr: NSDecimalNumber?
    @NSManaged var intensityWatts: NSDecimalNumber?
    @NSManaged var location: String?

}
