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

class HealthKitManager {
    
    // MARK: Access, availability, authorization

    static let sharedInstance = HealthKitManager()
    private init() {
        DDLogVerbose("trace")
    }
    
    let healthStore: HKHealthStore? = {
        return HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil
    }()
    
    let isHealthDataAvailable: Bool = {
        return HKHealthStore.isHealthDataAvailable()
    }()
    
    func authorizationRequestedForBloodGlucoseSamples() -> Bool {
        return NSUserDefaults.standardUserDefaults().boolForKey("authorizationRequestedForBloodGlucoseSamples")
    }
    
    func authorizationRequestedForBloodGlucoseSampleWrites() -> Bool {
        return NSUserDefaults.standardUserDefaults().boolForKey("authorizationRequestedForBloodGlucoseSampleWrites")
    }
    
    func authorizationRequestedForWorkoutSamples() -> Bool {
        return NSUserDefaults.standardUserDefaults().boolForKey("authorizationRequestedForWorkoutSamples")
    }
    
    func authorize(shouldAuthorizeBloodGlucoseSampleReads shouldAuthorizeBloodGlucoseSampleReads: Bool, shouldAuthorizeBloodGlucoseSampleWrites: Bool, shouldAuthorizeWorkoutSamples: Bool, completion: ((success:Bool, error:NSError!) -> Void)!)
    {
        DDLogVerbose("trace")
        
        var authorizationSuccess = false
        var authorizationError: NSError?
        
        defer {
            if authorizationError != nil {
                DDLogInfo("authorization error: \(authorizationError)")
                
                if completion != nil {
                    completion(success:authorizationSuccess, error:authorizationError)
                }
            }
        }
        
        guard isHealthDataAvailable else {
            authorizationError = NSError(domain: "HealthKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey:"HealthKit is not available on this device"])
            return
        }
        
        var readTypes: Set<HKSampleType>?
        var writeTypes: Set<HKSampleType>?
        if (shouldAuthorizeBloodGlucoseSampleReads) {
            readTypes = Set<HKSampleType>()
            readTypes!.insert(HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBloodGlucose)!)
        }
        if (shouldAuthorizeBloodGlucoseSampleWrites) {
            writeTypes = Set<HKSampleType>()
            writeTypes!.insert(HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBloodGlucose)!)
        }
        if (shouldAuthorizeWorkoutSamples) {
            if readTypes == nil {
                readTypes = Set<HKSampleType>()
            }
            readTypes!.insert(HKObjectType.workoutType())
        }
        guard readTypes != nil || writeTypes != nil else {
            DDLogVerbose("No health data authorization requested, ignoring")
            return
        }
        
        if (isHealthDataAvailable) {
            healthStore!.requestAuthorizationToShareTypes(writeTypes, readTypes: readTypes) { (success, error) -> Void in
                
                if success {
                    if (shouldAuthorizeBloodGlucoseSampleReads) {
                        NSUserDefaults.standardUserDefaults().setBool(true, forKey: "authorizationRequestedForBloodGlucoseSamples");
                    }
                    if (shouldAuthorizeBloodGlucoseSampleWrites) {
                        NSUserDefaults.standardUserDefaults().setBool(true, forKey: "authorizationRequestedForBloodGlucoseSampleWrites");
                    }
                    if shouldAuthorizeWorkoutSamples {
                        NSUserDefaults.standardUserDefaults().setBool(true, forKey: "authorizationRequestedForWorkoutSamples");
                    }
                    NSUserDefaults.standardUserDefaults().synchronize()
                }
                
                authorizationSuccess = success
                authorizationError = error
                
                DDLogInfo("authorization success: \(authorizationSuccess), error: \(authorizationError)")
                
                if completion != nil {
                    completion(success:authorizationSuccess, error:authorizationError)
                }
            }
        }
    }
    
    // MARK: Observation
    
    func startObservingBloodGlucoseSamples(observationHandler: (NSError?) -> (Void)) {
        DDLogVerbose("trace")

        guard isHealthDataAvailable else {
            DDLogError("Unexpected HealthKitManager call when health data not available")
            return
        }
        
        if bloodGlucoseObservationQuery != nil {
            healthStore?.stopQuery(bloodGlucoseObservationQuery!)
            bloodGlucoseObservationQuery = nil
        }
        
        let sampleType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBloodGlucose)!
        bloodGlucoseObservationQuery = HKObserverQuery(sampleType: sampleType, predicate: nil) {
            (query, observerQueryCompletion, error) in
            
            DDLogVerbose("Observation query called")
            
            if error != nil {
                DDLogError("HealthKit observation error \(error)")
            }

            observationHandler(error)
            
            // Per HealthKit docs: Calling this block tells HealthKit that you have successfully received the background data. If you do not call this block, HealthKit continues to attempt to launch your app using a back off algorithm. If your app fails to respond three times, HealthKit assumes that your app cannot receive data, and stops sending you background updates            
            observerQueryCompletion()
        }
        healthStore?.executeQuery(bloodGlucoseObservationQuery!)
    }
    
    func stopObservingBloodGlucoseSamples() {
        DDLogVerbose("trace")

        guard isHealthDataAvailable else {
            DDLogError("Unexpected HealthKitManager call when health data not available")
            return
        }
        
        if bloodGlucoseObservationQuery != nil {
            healthStore?.stopQuery(bloodGlucoseObservationQuery!)
            bloodGlucoseObservationQuery = nil
        }
    }
    
    // NOTE: resultsHandler is called on a separate process queue!
    func startObservingWorkoutSamples(resultsHandler: (([HKSample]?, [HKDeletedObject]?, NSError?) -> Void)!) {
        DDLogVerbose("trace")

        guard isHealthDataAvailable else {
            DDLogError("Unexpected HealthKitManager call when health data not available")
            return
        }
        
        if !workoutsObservationSuccessful {
            if workoutsObservationQuery != nil {
                healthStore?.stopQuery(workoutsObservationQuery!)
            }
            
            let sampleType = HKObjectType.workoutType()
            workoutsObservationQuery = HKObserverQuery(sampleType: sampleType, predicate: nil) {
                [unowned self](query, observerQueryCompletion, error) in
                if error == nil {
                    self.workoutsObservationSuccessful = true
                    self.readWorkoutSamples(resultsHandler)
                } else {
                    DDLogError("HealthKit observation error \(error), \(error!.userInfo)")
                    if resultsHandler != nil {
                        resultsHandler(nil, nil, error);
                    }
                }
                
                observerQueryCompletion()
            }
            healthStore?.executeQuery(workoutsObservationQuery!)
        }
    }
    
    func stopObservingWorkoutSamples() {
        DDLogVerbose("trace")

        guard isHealthDataAvailable else {
            DDLogError("Unexpected HealthKitManager call when health data not available")
            return
        }
        
        if workoutsObservationSuccessful {
            if workoutsObservationQuery != nil {
                healthStore?.stopQuery(workoutsObservationQuery!)
                workoutsObservationQuery = nil
            }
            workoutsObservationSuccessful = false
        }
    }
    
    // MARK: Background delivery
    
    func enableBackgroundDeliveryBloodGlucoseSamples() {
        DDLogVerbose("trace")

        guard isHealthDataAvailable else {
            DDLogError("Unexpected HealthKitManager call when health data not available")
            return
        }
        
        if !bloodGlucoseBackgroundDeliveryEnabled {
            healthStore?.enableBackgroundDeliveryForType(
                HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBloodGlucose)!,
                frequency: HKUpdateFrequency.Immediate) {
                    success, error -> Void in
                    if error == nil {
                        self.bloodGlucoseBackgroundDeliveryEnabled = true
                        DDLogError("Enabled background delivery of health data")
                    } else {
                        DDLogError("Error enabling background delivery of health data \(error), \(error!.userInfo)")
                    }
            }
        }
    }
    
    func disableBackgroundDeliveryBloodGlucoseSamples() {
        DDLogVerbose("trace")

        guard isHealthDataAvailable else {
            DDLogError("Unexpected HealthKitManager call when health data not available")
            return
        }
        
        if bloodGlucoseBackgroundDeliveryEnabled {
            healthStore?.disableBackgroundDeliveryForType(HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBloodGlucose)!) {
                success, error -> Void in
                if error == nil {
                    self.bloodGlucoseBackgroundDeliveryEnabled = false
                    DDLogError("Disabled background delivery of health data")
                } else {
                    DDLogError("Error disabling background delivery of health data \(error), \(error!.userInfo)")
                }
            }
        }
    }
    
    func enableBackgroundDeliveryWorkoutSamples() {
        DDLogVerbose("trace")

        guard isHealthDataAvailable else {
            DDLogError("Unexpected HealthKitManager call when health data not available")
            return
        }
        
        if !workoutsBackgroundDeliveryEnabled {
            healthStore?.enableBackgroundDeliveryForType(
                HKObjectType.workoutType(),
                frequency: HKUpdateFrequency.Immediate) {
                    success, error -> Void in
                    if error == nil {
                        self.workoutsBackgroundDeliveryEnabled = true
                        DDLogError("Enabled background delivery of health data")
                    } else {
                        DDLogError("Error enabling background delivery of health data \(error), \(error!.userInfo)")
                    }
            }
        }
    }
    
    func disableBackgroundDeliveryWorkoutSamples() {
        DDLogVerbose("trace")

        guard isHealthDataAvailable else {
            DDLogError("Unexpected HealthKitManager call when health data not available")
            return
        }
        
        if workoutsBackgroundDeliveryEnabled {
            healthStore?.disableBackgroundDeliveryForType(HKObjectType.workoutType()) {
                success, error -> Void in
                if error == nil {
                    self.workoutsBackgroundDeliveryEnabled = false
                    DDLogError("Disabled background delivery of health data")
                } else {
                    DDLogError("Error disabling background delivery of health data \(error), \(error!.userInfo)")
                }
            }
        }
    }
    
    func readBloodGlucoseSamplesFromAnchor(resultsHandler: ((NSError?, [HKSample]?, completion: (NSError?) -> (Void)) -> Void)!)
    {
        DDLogVerbose("trace")
        
        guard isHealthDataAvailable else {
            DDLogError("Unexpected HealthKitManager call when health data not available")
            return
        }
        
        var queryAnchor: HKQueryAnchor?
        let queryAnchorData = NSUserDefaults.standardUserDefaults().objectForKey("bloodGlucoseQueryAnchor")
        if queryAnchorData != nil {
            queryAnchor = NSKeyedUnarchiver.unarchiveObjectWithData(queryAnchorData as! NSData) as? HKQueryAnchor
        }
        
        let sampleType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBloodGlucose)!
        let sampleQuery = HKAnchoredObjectQuery(type: sampleType,
            predicate: nil, // TODO: my - We should probably use a LIKE predicate with wildcard to have the query filter Dexcom samples rather than filtering results as we receive them
            anchor: queryAnchor,
            limit: 288) { // Limit to 288 samples (about one day of samples at 5 minute intervals)
                (query, newSamples, deletedSamples, newAnchor, error) -> Void in

                if error != nil {
                    DDLogError("Error reading samples: \(error)")
                }
                
                resultsHandler(error, newSamples) {
                    (error: NSError?) in
                    
                    if error == nil && newAnchor != nil {
                        let queryAnchorData = NSKeyedArchiver.archivedDataWithRootObject(newAnchor!)
                        NSUserDefaults.standardUserDefaults().setObject(queryAnchorData, forKey: "bloodGlucoseQueryAnchor")
                        NSUserDefaults.standardUserDefaults().synchronize()
                    }
                }
        }
        healthStore?.executeQuery(sampleQuery)
    }
    
    func readBloodGlucoseSamples(startDate startDate: NSDate, endDate: NSDate, limit: Int, resultsHandler: ((NSError?, [HKSample]?, completion: (NSError?) -> (Void)) -> Void)!)
    {
        DDLogInfo("readBloodGlucoseSamples startDate: \(startDate), endDate: \(endDate), limit: \(limit)")
        
        guard isHealthDataAvailable else {
            DDLogError("Unexpected HealthKitManager call when health data not available")
            return
        }
        
        let predicate = HKQuery.predicateForSamplesWithStartDate(startDate, endDate: endDate, options: [.StrictEndDate, .StrictEndDate])
        let sortDescriptor = NSSortDescriptor(key:HKSampleSortIdentifierStartDate, ascending: false)
        
        let sampleType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBloodGlucose)!
        let sampleQuery = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: limit, sortDescriptors: [sortDescriptor]) {
            (query, newSamples, error) -> Void in
            
            if error != nil {
                DDLogError("Error reading samples: \(error)")
            }
            
            resultsHandler(error, newSamples) {
                (error: NSError?) in
                // Nothing to do
            }
        }
        healthStore?.executeQuery(sampleQuery)
    }
    
    func countBloodGlucoseSamples(completion: (error: NSError?, totalSamplesCount: Int, totalDexcomSamplesCount: Int) -> (Void)) {
        let sampleType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBloodGlucose)!
        let sampleQuery = HKSampleQuery(sampleType: sampleType, predicate: nil, limit: HKObjectQueryNoLimit, sortDescriptors: nil) {
            (query, newSamples, error) -> Void in
            
            var totalSamplesCount = 0
            var totalDexcomSamplesCount = 0
            if newSamples != nil {
                for sample in newSamples! {
                    let sourceRevision = sample.sourceRevision
                    let source = sourceRevision.source
                    totalSamplesCount += 1
                    if source.name.lowercaseString.rangeOfString("dexcom") != nil {
                        totalDexcomSamplesCount += 1
                    }
                }
            }
            
            completion(error: error, totalSamplesCount: totalSamplesCount, totalDexcomSamplesCount: totalDexcomSamplesCount)
        }
        healthStore?.executeQuery(sampleQuery)
    }
    
    func findSampleDateRange(sampleType sampleType: HKSampleType, completion: (error: NSError?, startDate: NSDate?, endDate: NSDate?) -> Void)
    {
        DDLogVerbose("trace")

        var startDate: NSDate? = nil
        var endDate: NSDate? = nil
        
        let predicate = HKQuery.predicateForSamplesWithStartDate(NSDate.distantPast(), endDate: NSDate.distantFuture(), options: [])
        let startDateSortDescriptor = NSSortDescriptor(key:HKSampleSortIdentifierStartDate, ascending: true)
        let endDateSortDescriptor = NSSortDescriptor(key:HKSampleSortIdentifierStartDate, ascending: false)

        // Kick of query to find startDate
        let startDateSampleQuery = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: 1, sortDescriptors: [startDateSortDescriptor]) {
            (query: HKSampleQuery, samples: [HKSample]?, error: NSError?) -> Void in
            
            if error == nil && samples != nil {
                // Get startDate of oldest sample
                if samples?.count > 0 {
                    startDate = samples![0].startDate
                }

                // Kick of query to find endDate
                let endDateSampleQuery = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: 1, sortDescriptors: [endDateSortDescriptor]) {
                    (query: HKSampleQuery, samples: [HKSample]?, error: NSError?) -> Void in

                    if error == nil && samples?.count > 0 {
                        endDate = samples![0].endDate
                    }
                    
                    completion(error: error, startDate: startDate, endDate: endDate)
                }
                self.healthStore?.executeQuery(endDateSampleQuery)
            } else {
                completion(error: error, startDate: startDate, endDate: endDate)
            }
        }
        healthStore?.executeQuery(startDateSampleQuery)
    }
    
    func readWorkoutSamples(resultsHandler: (([HKSample]?, [HKDeletedObject]?, NSError?) -> Void)!)
    {
        DDLogVerbose("trace")
        
        guard isHealthDataAvailable else {
            DDLogError("Unexpected HealthKitManager call when health data not available")
            return
        }
        
        var queryAnchor: HKQueryAnchor?
        let queryAnchorData = NSUserDefaults.standardUserDefaults().objectForKey("workoutQueryAnchor")
        if queryAnchorData != nil {
            queryAnchor = NSKeyedUnarchiver.unarchiveObjectWithData(queryAnchorData as! NSData) as? HKQueryAnchor
        }
        
        let sampleType = HKObjectType.workoutType()
        let sampleQuery = HKAnchoredObjectQuery(type: sampleType,
            predicate: nil,
            anchor: queryAnchor,
            limit: Int(HKObjectQueryNoLimit /* 100 */)) { // TODO: need to limit to like 100 or so once clients are properly handling the "more" case like we do for observing/caching blood glucose data
                
                (query, newSamples, deletedSamples, newAnchor, error) -> Void in
                
                if resultsHandler != nil {
                    resultsHandler(newSamples, deletedSamples, error)
                    
                    if error == nil && newAnchor != nil {
                        let queryAnchorData = NSKeyedArchiver.archivedDataWithRootObject(newAnchor!)
                        NSUserDefaults.standardUserDefaults().setObject(queryAnchorData, forKey: "workoutQueryAnchor")
                        NSUserDefaults.standardUserDefaults().synchronize()
                    }
                }
        }
        healthStore?.executeQuery(sampleQuery)
    }
    
    // MARK: Private
    
    private var bloodGlucoseObservationQuery: HKObserverQuery?
    private var bloodGlucoseBackgroundDeliveryEnabled = false
    private var bloodGlucoseQueryAnchor = Int(HKAnchoredObjectQueryNoAnchor)

    private var workoutsObservationSuccessful = false
    private var workoutsObservationQuery: HKObserverQuery?
    private var workoutsBackgroundDeliveryEnabled = false
    private var workoutsQueryAnchor = Int(HKAnchoredObjectQueryNoAnchor)
}
