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

// Note: Code for future processing of local workout events from HealthKit

class TidepoolMobileHealthKitConfiguration: HealthKitConfiguration
{
    
    // Override to load workout events and sync smbg events from Tidepool service in addition to pushing up Dexcom blood glucose monitoring events
    override func turnOnInterface() {
        super.turnOnInterface()
        // TODO: turn off workout data for now...
        //monitorForWorkoutData(true)
        //HealthKitBloodGlucosePusher.sharedInstance.enablePushToHealthKit(true)
    }

    override func turnOffInterface() {
        super.turnOffInterface()
        // TODO: turn off workout data for now...
        //monitorForWorkoutData(false)
        //HealthKitBloodGlucosePusher.sharedInstance.enablePushToHealthKit(false)
    }

    //
    // MARK: - Loading workout events from Healthkit
    //
    
    func monitorForWorkoutData(_ monitor: Bool) {
        // Set up HealthKit observation and background query.
        if (HealthKitManager.sharedInstance.isHealthDataAvailable) {
            if monitor {
                HealthKitManager.sharedInstance.startObservingWorkoutSamples() {
                    (newSamples: [HKSample]?, deletedSamples: [HKDeletedObject]?, error: NSError?) in
                    
                    if (newSamples != nil) {
                        DDLogInfo("********* PROCESSING \(newSamples!.count) new workout samples ********* ")
                        DispatchQueue.main.async {
                            self.processWorkoutEvents(newSamples!)
                        }
                    }
                    
                    if (deletedSamples != nil) {
                        DDLogInfo("********* PROCESSING \(deletedSamples!.count) deleted workout samples ********* ")
                        DispatchQueue.main.async {
                            self.processDeleteWorkoutEvents(deletedSamples!)
                        }
                    }
                }
            } else {
                HealthKitManager.sharedInstance.stopObservingWorkoutSamples()
            }
        }
    }
    
    fileprivate func processWorkoutEvents(_ workouts: [HKSample]) {
        let moc = TidepoolMobileDataController.sharedInstance.mocForLocalEvents()!
        if let entityDescription = NSEntityDescription.entity(forEntityName: "Workout", in: moc) {
            for event in workouts {
                if let workout = event as? HKWorkout {
                    DDLogInfo("*** processing workout id: \(event.uuid.uuidString)")
                    if let metadata = workout.metadata {
                        DDLogInfo(" metadata: \(metadata)")
                    }
                    if let wkoutEvents = workout.workoutEvents {
                        if !wkoutEvents.isEmpty {
                            DDLogInfo(" workout events: \(wkoutEvents)")
                        }
                    }
                    let we = NSManagedObject(entity: entityDescription, insertInto: nil) as! Workout
                    
                    // Workout fields
                    we.appleHealthDate = workout.startDate
                    we.calories = workout.totalEnergyBurned?.doubleValue(for: HKUnit.kilocalorie()) as NSNumber?
                    we.distance = workout.totalDistance?.doubleValue(for: HKUnit.mile()) as NSNumber?
                    we.duration = workout.duration as NSNumber?
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
                    we.id = event.uuid.uuidString as NSString?
                    we.userid = TidepoolMobileDataController.sharedInstance.currentUserId
                    let now = Date()
                    we.createdTime = now
                    we.modifiedTime = now
                    // TODO: we set a time zone offset for this event, ASSUMING the workout was done in the same time zone location. We do adjust for times in a different daylight savings zone offset. Should we just leave this field nil unless we can be reasonably clear about the time zone (e.g., events very recently created)?
                    let dstAdjust = TidepoolMobileUtils.dayLightSavingsAdjust(workout.startDate)
                    we.timezoneOffset = NSNumber(value:(NSCalendar.current.timeZone.secondsFromGMT() + dstAdjust)/60)
                    
                    // Check to see if we already have this one, with possibly a different id
                    if let time = we.time, let userId = we.userid {
                        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Workout")
                        request.predicate = NSPredicate(format: "(time == %@) AND (userid = %@)", time as CVarArg, userId)
                        do {
                            let existingWorkouts = try moc.fetch(request) as! [Workout]
                            for workout: Workout in existingWorkouts {
                                if workout.duration == we.duration &&
                                    workout.title == we.title &&
                                    workout.notes == we.notes {
                                    DDLogInfo("Deleting existing workout of same time and duration: \(workout)")
                                    moc.delete(workout)
                                }
                            }
                        } catch {
                            DDLogError("Workout dupe query failed!")
                        }
                    }
                    
                    moc.insert(we)
                    DDLogInfo("added workout: \(we)")
                } else {
                    DDLogError("ERROR: \(#function): Expected HKWorkout!")
                }
            }
        }
        _ = DatabaseUtils.databaseSave(moc)
        
    }
    
    fileprivate func processDeleteWorkoutEvents(_ workouts: [HKDeletedObject]) {
        let moc = TidepoolMobileDataController.sharedInstance.mocForLocalEvents()!
        for workout in workouts {
            DDLogInfo("Processing deleted workout sample with UUID: \(workout.uuid)");
            let id = workout.uuid.uuidString
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: "Workout")
            // Note: look for any workout with this id, regardless of current user - we should only see it for one user, but multiple user operation is not yet completely defined.
            request.predicate = NSPredicate(format: "(id == %@)", id)
            do {
                let existingWorkouts = try moc.fetch(request) as! [Workout]
                for workout: Workout in existingWorkouts {
                    DDLogInfo("Deleting workout: \(workout)")
                    moc.delete(workout)
                }
                _ = DatabaseUtils.databaseSave(moc)
            } catch {
                DDLogError("Existing workout query failed!")
            }
        }
    }

    
}
