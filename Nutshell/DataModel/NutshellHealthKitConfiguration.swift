/*
 * Copyright (c) 2015, Tidepool Project
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the associated License, which is identical to the BSD 2-Clause
 * License as published by the Open Source Initiative at opensource.org.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE. See the License for more details.
 *
 * You should have received a copy of the License along with this program; if
 * not, you can obtain one from Tidepool Project at tidepool.org.
 */

import HealthKit
import CocoaLumberjack
import CoreData

class NutshellHealthKitConfiguration: HealthKitConfiguration
{
    
    // Override to load workout events and sync smbg events from Tidepool service...
    override func turnOnInterface() {
        monitorForWorkoutData(true)
        HealthKitDataPusher.sharedInstance.enablePushToHealthKit(true)
    }

    override func turnOffInterface() {
        monitorForWorkoutData(false)
        HealthKitDataPusher.sharedInstance.enablePushToHealthKit(false)
    }

    //
    // MARK: - Loading workout events from Healthkit
    //
    
    func monitorForWorkoutData(monitor: Bool) {
        // Set up HealthKit observation and background query.
        if (HealthKitManager.sharedInstance.isHealthDataAvailable) {
            if monitor {
                HealthKitManager.sharedInstance.startObservingWorkoutSamples() {
                    (newSamples: [HKSample]?, deletedSamples: [HKDeletedObject]?, error: NSError?) in
                    
                    if (newSamples != nil) {
                        NSLog("********* PROCESSING \(newSamples!.count) new workout samples ********* ")
                        dispatch_async(dispatch_get_main_queue()) {
                            self.processWorkoutEvents(newSamples!)
                        }
                    }
                    
                    if (deletedSamples != nil) {
                        NSLog("********* PROCESSING \(deletedSamples!.count) deleted workout samples ********* ")
                        dispatch_async(dispatch_get_main_queue()) {
                            self.processDeleteWorkoutEvents(deletedSamples!)
                        }
                    }
                }
            } else {
                HealthKitManager.sharedInstance.stopObservingWorkoutSamples()
            }
        }
    }
    
    private func processWorkoutEvents(workouts: [HKSample]) {
        let moc = NutDataController.controller().mocForNutEvents()!
        if let entityDescription = NSEntityDescription.entityForName("Workout", inManagedObjectContext: moc) {
            for event in workouts {
                if let workout = event as? HKWorkout {
                    NSLog("*** processing workout id: \(event.UUID.UUIDString)")
                    if let metadata = workout.metadata {
                        NSLog(" metadata: \(metadata)")
                    }
                    if let wkoutEvents = workout.workoutEvents {
                        if !wkoutEvents.isEmpty {
                            NSLog(" workout events: \(wkoutEvents)")
                        }
                    }
                    let we = NSManagedObject(entity: entityDescription, insertIntoManagedObjectContext: nil) as! Workout
                    
                    // Workout fields
                    we.appleHealthDate = workout.startDate
                    we.calories = workout.totalEnergyBurned?.doubleValueForUnit(HKUnit.kilocalorieUnit())
                    we.distance = workout.totalDistance?.doubleValueForUnit(HKUnit.mileUnit())
                    we.duration = workout.duration
                    we.source = workout.sourceRevision.source.name
                    // NOTE: use the Open mHealth enum string here!
                    we.subType = Workout.enumStringForHKWorkoutActivityType(workout.workoutActivityType)
                    
                    // EventItem fields
                    // Default title format: "Run - 4.2 miles"
                    var title: String = Workout.userStringForHKWorkoutActivityTypeEnumString(we.subType!)
                    if let miles = we.distance {
                        let floatMiles = Float(miles)
                        title = title + " - " + String(format: "%.2f",floatMiles) + " miles"
                    }
                    we.title = title
                    // Default notes string is the application name sourcing the event
                    we.notes = we.source
                    
                    // Common fields
                    we.time = workout.startDate
                    we.type = "workout"
                    we.id = event.UUID.UUIDString
                    we.userid = NutDataController.controller().currentUserId
                    let now = NSDate()
                    we.createdTime = now
                    we.modifiedTime = now
                    // TODO: we set a time zone offset for this event, ASSUMING the workout was done in the same time zone location. We do adjust for times in a different daylight savings zone offset. Should we just leave this field nil unless we can be reasonably clear about the time zone (e.g., events very recently created)?
                    let dstAdjust = NutUtils.dayLightSavingsAdjust(workout.startDate)
                    we.timezoneOffset = (NSCalendar.currentCalendar().timeZone.secondsFromGMT + dstAdjust)/60
                    
                    // Check to see if we already have this one, with possibly a different id
                    if let time = we.time, userId = we.userid {
                        let request = NSFetchRequest(entityName: "Workout")
                        request.predicate = NSPredicate(format: "(time == %@) AND (userid = %@)", time, userId)
                        do {
                            let existingWorkouts = try moc.executeFetchRequest(request) as! [Workout]
                            for workout: Workout in existingWorkouts {
                                if workout.duration == we.duration &&
                                    workout.title == we.title &&
                                    workout.notes == we.notes {
                                    NSLog("Deleting existing workout of same time and duration: \(workout)")
                                    moc.deleteObject(workout)
                                }
                            }
                        } catch {
                            NSLog("Workout dupe query failed!")
                        }
                    }
                    
                    moc.insertObject(we)
                    NSLog("added workout: \(we)")
                } else {
                    NSLog("ERROR: \(#function): Expected HKWorkout!")
                }
            }
        }
        DatabaseUtils.databaseSave(moc)
        
    }
    
    private func processDeleteWorkoutEvents(workouts: [HKDeletedObject]) {
        let moc = NutDataController.controller().mocForNutEvents()!
        for workout in workouts {
            NSLog("Processing deleted workout sample with UUID: \(workout.UUID)");
            let id = workout.UUID.UUIDString
            let request = NSFetchRequest(entityName: "Workout")
            // Note: look for any workout with this id, regardless of current user - we should only see it for one user, but multiple user operation is not yet completely defined.
            request.predicate = NSPredicate(format: "(id == %@)", id)
            do {
                let existingWorkouts = try moc.executeFetchRequest(request) as! [Workout]
                for workout: Workout in existingWorkouts {
                    NSLog("Deleting workout: \(workout)")
                    moc.deleteObject(workout)
                }
                DatabaseUtils.databaseSave(moc)
            } catch {
                NSLog("Existing workout query failed!")
            }
        }
    }

    
}