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
    fileprivate init() {
        DDLogVerbose("trace")
    }
    
    let healthStore: HKHealthStore? = {
        return HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil
    }()
    
    let isHealthDataAvailable: Bool = {
        return HKHealthStore.isHealthDataAvailable()
    }()
    
    func authorizationRequestedForUploaderSamples() -> Bool {
        return UserDefaults.standard.bool(forKey: HealthKitSettings.AuthorizationRequestedForUploaderSamplesKey)
    }
    
    func authorizationRequestedForBloodGlucoseSampleWrites() -> Bool {
        return UserDefaults.standard.bool(forKey: HealthKitSettings.AuthorizationRequestedForBloodGlucoseSampleWritesKey)
    }
    
    func authorizationRequestedForWorkoutSamples() -> Bool {
        return UserDefaults.standard.bool(forKey: HealthKitSettings.AuthorizationRequestedForWorkoutSamplesKey)
    }
    
    func authorize(shouldAuthorizeUploaderSampleReads: Bool, shouldAuthorizeBloodGlucoseSampleWrites: Bool, shouldAuthorizeWorkoutSamples: Bool, completion: @escaping (_ success:Bool, _ error:NSError?) -> Void = {(_, _) in })
    {
        DDLogVerbose("trace")
        
        var authorizationSuccess = false
        var authorizationError: NSError?
        
        defer {
            if authorizationError != nil {
                DDLogError("authorization error: \(String(describing: authorizationError))")
                
                completion(authorizationSuccess, authorizationError)
            }
        }
        
        guard isHealthDataAvailable else {
            authorizationError = NSError(domain: "HealthKitManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "HealthKit is not available on this device"])
            return
        }
        
        var readTypes: Set<HKSampleType>?
        var writeTypes: Set<HKSampleType>?
        if (shouldAuthorizeUploaderSampleReads) {
            readTypes = Set<HKSampleType>()
            for uploadType in appHealthKitConfiguration.healthKitUploadTypes {
                readTypes!.insert(HKObjectType.quantityType(forIdentifier: uploadType.hkQuantityTypeIdentifier()!)!)
            }
        }
        if (shouldAuthorizeBloodGlucoseSampleWrites) {
            writeTypes = Set<HKSampleType>()
            writeTypes!.insert(HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodGlucose)!)
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
            healthStore!.requestAuthorization(toShare: writeTypes, read: readTypes) { (success, error) -> Void in
                if success {
                    if (shouldAuthorizeUploaderSampleReads) {
                        UserDefaults.standard.set(true, forKey: HealthKitSettings.AuthorizationRequestedForUploaderSamplesKey)
                    }
                    if (shouldAuthorizeBloodGlucoseSampleWrites) {
                        UserDefaults.standard.set(true, forKey: HealthKitSettings.AuthorizationRequestedForBloodGlucoseSampleWritesKey)
                    }
                    if shouldAuthorizeWorkoutSamples {
                        UserDefaults.standard.set(true, forKey: HealthKitSettings.AuthorizationRequestedForWorkoutSamplesKey)
                    }
                    UserDefaults.standard.synchronize()
                }
                
                authorizationSuccess = success
                authorizationError = error as NSError?
                
                DDLogInfo("authorization success: \(authorizationSuccess), error: \(String(describing: authorizationError))")
                
                completion(authorizationSuccess, authorizationError)
            }
        }
    }
    
    // MARK: Observation
    
    func startObservingSamplesForType(_ uploadType: HealthKitUploadType, _ observationHandler: @escaping (NSError?) -> (Void)) {
        DDLogVerbose("trace")

        guard isHealthDataAvailable else {
            DDLogError("Unexpected HealthKitManager call when health data not available")
            return
        }
        
        if uploadType.sampleObservationQuery != nil {
            healthStore?.stop(uploadType.sampleObservationQuery!)
            uploadType.sampleObservationQuery = nil
        }
        
        let sampleType = HKObjectType.quantityType(forIdentifier: uploadType.hkQuantityTypeIdentifier()!)!
        uploadType.sampleObservationQuery = HKObserverQuery(sampleType: sampleType, predicate: nil) {
            (query, observerQueryCompletion, error) in
            
            DDLogVerbose("Observation query called")
            
            if error != nil {
                DDLogError("HealthKit observation error \(String(describing: error))")
            }

            observationHandler(error as NSError?)
            
            // Per HealthKit docs: Calling this block tells HealthKit that you have successfully received the background data. If you do not call this block, HealthKit continues to attempt to launch your app using a back off algorithm. If your app fails to respond three times, HealthKit assumes that your app cannot receive data, and stops sending you background updates            
            observerQueryCompletion()
        }
        healthStore?.execute(uploadType.sampleObservationQuery!)
    }
    
    func stopObservingSamplesForType(_ uploadType: HealthKitUploadType) {
        DDLogVerbose("trace")

        guard isHealthDataAvailable else {
            DDLogError("Unexpected HealthKitManager call when health data not available")
            return
        }
        
        if uploadType.sampleObservationQuery != nil {
            healthStore?.stop(uploadType.sampleObservationQuery!)
            uploadType.sampleObservationQuery = nil
        }
    }
    
    // NOTE: resultsHandler is called on a separate process queue!
    func startObservingWorkoutSamples(_ resultsHandler: (([HKSample]?, [HKDeletedObject]?, NSError?) -> Void)!) {
        DDLogVerbose("trace")

        guard isHealthDataAvailable else {
            DDLogError("Unexpected HealthKitManager call when health data not available")
            return
        }
        
        if !workoutsObservationSuccessful {
            if workoutsObservationQuery != nil {
                healthStore?.stop(workoutsObservationQuery!)
            }
            
            let sampleType = HKObjectType.workoutType()
            workoutsObservationQuery = HKObserverQuery(sampleType: sampleType, predicate: nil) {
                [unowned self](query, observerQueryCompletion, error) in
                if error == nil {
                    self.workoutsObservationSuccessful = true
                    self.readWorkoutSamples(resultsHandler)
                } else {
                    DDLogError("HealthKit observation error \(String(describing: error))")
                    resultsHandler?(nil, nil, error as NSError?)
                }
                
                observerQueryCompletion()
            }
            healthStore?.execute(workoutsObservationQuery!)
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
                healthStore?.stop(workoutsObservationQuery!)
                workoutsObservationQuery = nil
            }
            workoutsObservationSuccessful = false
        }
    }
    
    // MARK: Background delivery
    
    func enableBackgroundDeliverySamplesForType(_ uploadType: HealthKitUploadType) {
        DDLogVerbose("trace")

        guard isHealthDataAvailable else {
            DDLogError("Unexpected HealthKitManager call when health data not available")
            return
        }
        
        if !uploadType.sampleBackgroundDeliveryEnabled {
            healthStore?.enableBackgroundDelivery(
                for: HKObjectType.quantityType(forIdentifier: uploadType.hkQuantityTypeIdentifier()!)!,
                frequency: HKUpdateFrequency.immediate) {
                    success, error -> Void in
                    if error == nil {
                        uploadType.sampleBackgroundDeliveryEnabled = true
                        DDLogError("Enabled background delivery of health data")
                    } else {
                        DDLogError("Error enabling background delivery of health data \(String(describing: error))")
                    }
            }
        }
    }
    
    func disableBackgroundDeliverySamplesForType(_ uploadType: HealthKitUploadType) {
        DDLogVerbose("trace")

        guard isHealthDataAvailable else {
            DDLogError("Unexpected HealthKitManager call when health data not available")
            return
        }
        
        if uploadType.sampleBackgroundDeliveryEnabled {
            healthStore?.disableBackgroundDelivery(for: HKObjectType.quantityType(forIdentifier: uploadType.hkQuantityTypeIdentifier()!)!) {
                success, error -> Void in
                if error == nil {
                    uploadType.sampleBackgroundDeliveryEnabled = false
                    DDLogError("Disabled background delivery of health data")
                } else {
                    DDLogError("Error disabling background delivery of health data \(String(describing: error)), \(String(describing: error!._userInfo))")
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
            healthStore?.enableBackgroundDelivery(
                for: HKObjectType.workoutType(),
                frequency: HKUpdateFrequency.immediate) {
                    success, error -> Void in
                    if error == nil {
                        self.workoutsBackgroundDeliveryEnabled = true
                        DDLogError("Enabled background delivery of health data")
                    } else {
                        DDLogError("Error enabling background delivery of health data \(String(describing: error))")
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
            healthStore?.disableBackgroundDelivery(for: HKObjectType.workoutType()) {
                success, error -> Void in
                if error == nil {
                    self.workoutsBackgroundDeliveryEnabled = false
                    DDLogError("Disabled background delivery of health data")
                } else {
                    DDLogError("Error disabling background delivery of health data \(String(describing: error)), \((error! as NSError).userInfo)")
                }
            }
        }
    }
    
    func readSamplesFromAnchorForType(_ uploadType: HealthKitUploadType, predicate: NSPredicate?, anchor: HKQueryAnchor?, limit: Int, resultsHandler: @escaping ((NSError?, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?) -> Void))
    {
        DDLogVerbose("trace")
        
        guard isHealthDataAvailable else {
            DDLogError("Unexpected HealthKitManager call when health data not available")
            return
        }
        
        let sampleType = HKObjectType.quantityType(forIdentifier: uploadType.hkQuantityTypeIdentifier()!)!
        let sampleQuery = HKAnchoredObjectQuery(type: sampleType,
            predicate: predicate,
            anchor: anchor,
            limit: limit) {
                (query, newSamples, deletedSamples, newAnchor, error) -> Void in

                if error != nil {
                    DDLogError("Error reading samples: \(String(describing: error))")
                }
                
                resultsHandler((error as NSError?), newSamples, deletedSamples, newAnchor)
        }
        healthStore?.execute(sampleQuery)
    }

    func readSamplesForType(_ uploadType: HealthKitUploadType, startDate: Date, endDate: Date, limit: Int, resultsHandler: @escaping (((NSError?, [HKSample]?, HKQueryAnchor?) -> Void)))
    {
        DDLogInfo("readSamplesForType uploadType: \(uploadType.typeName) startDate: \(startDate), endDate: \(endDate), limit: \(limit)")
        
        guard isHealthDataAvailable else {
            DDLogError("Unexpected HealthKitManager call when health data not available")
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [.strictStartDate, .strictEndDate])
        let sortDescriptor = NSSortDescriptor(key:HKSampleSortIdentifierStartDate, ascending: false)
        
        let sampleType = HKObjectType.quantityType(forIdentifier: uploadType.hkQuantityTypeIdentifier()!)!
        let sampleQuery = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: limit, sortDescriptors: [sortDescriptor]) {
            (query, newSamples, error) -> Void in
            
            if error != nil {
                DDLogError("Error reading samples: \(String(describing: error))")
            }
            
            resultsHandler(error as NSError?, newSamples, nil)
        }
        healthStore?.execute(sampleQuery)
    }
    
    // Debug function, not currently called!
    func countBloodGlucoseSamples(_ completion: @escaping (_ error: NSError?, _ totalSamplesCount: Int, _ totalDexcomSamplesCount: Int) -> (Void)) {
        DDLogVerbose("trace")
        
        let sampleType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodGlucose)!
        let sampleQuery = HKSampleQuery(sampleType: sampleType, predicate: nil, limit: HKObjectQueryNoLimit, sortDescriptors: nil) {
            (query, newSamples, error) -> Void in
            
            var totalSamplesCount = 0
            var totalDexcomSamplesCount = 0
            if newSamples != nil {
                for sample in newSamples! {
                    let sourceRevision = sample.sourceRevision
                    let source = sourceRevision.source
                    totalSamplesCount += 1
                    let treatAllBloodGlucoseSourceTypesAsDexcom = UserDefaults.standard.bool(forKey: HealthKitSettings.TreatAllBloodGlucoseSourceTypesAsDexcomKey)
                    if source.name.lowercased().range(of: "dexcom") != nil || !treatAllBloodGlucoseSourceTypesAsDexcom {
                        totalDexcomSamplesCount += 1
                    }
                }
            }
            
            completion(error as NSError?, totalSamplesCount, totalDexcomSamplesCount)
        }
        healthStore?.execute(sampleQuery)
    }
    
    func findSampleDateRange(sampleType: HKSampleType, completion: @escaping (_ error: NSError?, _ startDate: Date?, _ endDate: Date?) -> Void)
    {
        DDLogVerbose("trace")

        var startDate: Date? = nil
        var endDate: Date? = nil
        
        let predicate = HKQuery.predicateForSamples(withStart: Date.distantPast, end: Date.distantFuture, options: [])
        let startDateSortDescriptor = NSSortDescriptor(key:HKSampleSortIdentifierStartDate, ascending: true)
        let endDateSortDescriptor = NSSortDescriptor(key:HKSampleSortIdentifierStartDate, ascending: false)

        // Kick of query to find startDate
        let startDateSampleQuery = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: 1, sortDescriptors: [startDateSortDescriptor]) {
            (query: HKSampleQuery, samples: [HKSample]?, error: Error?) -> Void in
            
            if error == nil && samples != nil {
                // Get startDate of oldest sample
                if samples!.count > 0 {
                    startDate = samples![0].startDate
                }

                // Kick of query to find endDate
                let endDateSampleQuery = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: 1, sortDescriptors: [endDateSortDescriptor]) {
                    (query: HKSampleQuery, samples: [HKSample]?, error: Error?) -> Void in

                    if error == nil && samples != nil && samples!.count > 0 {
                        endDate = samples![0].endDate
                    }
                    
                    completion((error as NSError?), startDate, endDate)
                }
                self.healthStore?.execute(endDateSampleQuery)
            } else {
                completion((error as NSError?), startDate, endDate)
            }
        }
        healthStore?.execute(startDateSampleQuery)
    }
    
    func readWorkoutSamples(_ resultsHandler: @escaping (([HKSample]?, [HKDeletedObject]?, NSError?) -> Void) = {(_, _, _) in })
    {
        DDLogVerbose("trace")
        
        guard isHealthDataAvailable else {
            DDLogError("Unexpected HealthKitManager call when health data not available")
            return
        }
        
        var queryAnchor: HKQueryAnchor?
        let queryAnchorData = UserDefaults.standard.object(forKey: HealthKitSettings.WorkoutQueryAnchorKey)
        if queryAnchorData != nil {
            queryAnchor = NSKeyedUnarchiver.unarchiveObject(with: queryAnchorData as! Data) as? HKQueryAnchor
        }
        
        let sampleType = HKObjectType.workoutType()
        let sampleQuery = HKAnchoredObjectQuery(type: sampleType,
            predicate: nil,
            anchor: queryAnchor,
            limit: Int(HKObjectQueryNoLimit /* 100 */)) { // TODO: need to limit to like 100 or so once clients are properly handling the "more" case like we do for observing/caching blood glucose data
                
                (query, newSamples, deletedSamples, newAnchor, error) -> Void in
                
                resultsHandler(newSamples, deletedSamples, (error as NSError?))
                
                if error == nil && newAnchor != nil {
                    let queryAnchorData = NSKeyedArchiver.archivedData(withRootObject: newAnchor!)
                    UserDefaults.standard.set(queryAnchorData, forKey: HealthKitSettings.WorkoutQueryAnchorKey)
                    UserDefaults.standard.synchronize()
                }
        }
        healthStore?.execute(sampleQuery)
    }
    
    // MARK: Private
    
    private var workoutsObservationSuccessful = false
    private var workoutsObservationQuery: HKObserverQuery?
    private var workoutsBackgroundDeliveryEnabled = false
    private var workoutsQueryAnchor = Int(HKAnchoredObjectQueryNoAnchor)
}
