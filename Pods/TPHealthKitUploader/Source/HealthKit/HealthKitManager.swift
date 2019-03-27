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

class HealthKitManager {
    
    // MARK: Access, availability, authorization

    static let sharedInstance = HealthKitManager()
    fileprivate init() {
        DDLogVerbose("\(#function)")
    }
    
    let settings = GlobalSettings.sharedInstance
    
    let healthStore: HKHealthStore? = {
        return HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil
    }()
    
    let isHealthDataAvailable: Bool = {
        return HKHealthStore.isHealthDataAvailable()
    }()
    
    func authorizationRequestedForUploaderSamples() -> Bool {
        return settings.boolForKey(.authorizationRequestedForUploaderSamplesKey)
    }
    
    func authorize(completion: @escaping (_ success:Bool, _ error:NSError?) -> Void = {(_, _) in })
    {
        DDLogVerbose("\(#function)")
        
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
        
        var readTypes = Set<HKObjectType>()
        for uploadType in HealthKitConfiguration.sharedInstance!.healthKitUploadTypes {
            readTypes.insert(uploadType.hkSampleType()!)
        }
        let biologicalSex = HKObjectType.characteristicType(forIdentifier: .biologicalSex)
        readTypes.insert(biologicalSex!)
        
        if (isHealthDataAvailable) {
            healthStore!.requestAuthorization(toShare: nil, read: readTypes) { (success, error) -> Void in
                if success {
                    self.settings.updateBoolForKey(.authorizationRequestedForUploaderSamplesKey, value: true)
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
        DDLogVerbose("\(#function)")

        guard isHealthDataAvailable else {
            DDLogError("Unexpected HealthKitManager call when health data not available")
            return
        }
        
        if uploadType.sampleObservationQuery != nil {
            healthStore?.stop(uploadType.sampleObservationQuery!)
            uploadType.sampleObservationQuery = nil
        }
        
        let sampleType = uploadType.hkSampleType()!
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
        DDLogVerbose("\(#function)")

        guard isHealthDataAvailable else {
            DDLogError("Unexpected HealthKitManager call when health data not available")
            return
        }
        
        if uploadType.sampleObservationQuery != nil {
            healthStore?.stop(uploadType.sampleObservationQuery!)
            uploadType.sampleObservationQuery = nil
        }
    }
    
    // MARK: Background delivery
    
    func enableBackgroundDeliverySamplesForType(_ uploadType: HealthKitUploadType) {
        DDLogVerbose("\(#function)")

        guard isHealthDataAvailable else {
            DDLogError("Unexpected HealthKitManager call when health data not available")
            return
        }
        
        if !uploadType.sampleBackgroundDeliveryEnabled {
            healthStore?.enableBackgroundDelivery(
                for: uploadType.hkSampleType()!,
                frequency: HKUpdateFrequency.immediate) {
                    success, error -> Void in
                    if error == nil {
                        uploadType.sampleBackgroundDeliveryEnabled = true
                        DDLogInfo("Enabled background delivery of health data")
                    } else {
                        DDLogError("Error enabling background delivery of health data \(String(describing: error))")
                    }
            }
        }
    }
    
    func disableBackgroundDeliverySamplesForType(_ uploadType: HealthKitUploadType) {
        DDLogVerbose("\(#function)")

        guard isHealthDataAvailable else {
            DDLogError("Unexpected HealthKitManager call when health data not available")
            return
        }
        
        if uploadType.sampleBackgroundDeliveryEnabled {
            healthStore?.disableBackgroundDelivery(for: uploadType.hkSampleType()!) {
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
    
    func readSamplesFromAnchorForType(_ uploadType: HealthKitUploadType, predicate: NSPredicate?, anchor: HKQueryAnchor?, limit: Int, resultsHandler: @escaping ((NSError?, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?) -> Void))
    {
        DDLogVerbose("\(#function)")
        
        guard isHealthDataAvailable else {
            DDLogError("Unexpected HealthKitManager call when health data not available")
            return
        }
        
        let sampleType = uploadType.hkSampleType()!
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
        DDLogInfo("uploadType: \(uploadType.typeName) startDate: \(startDate), endDate: \(endDate), limit: \(limit)")
        
        guard isHealthDataAvailable else {
            DDLogError("Unexpected HealthKitManager call when health data not available")
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [.strictStartDate, .strictEndDate])
        let sortDescriptor = NSSortDescriptor(key:HKSampleSortIdentifierStartDate, ascending: false)
        
        let sampleType = uploadType.hkSampleType()!
        let sampleQuery = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: limit, sortDescriptors: [sortDescriptor]) {
            (query, newSamples, error) -> Void in
            
            if error != nil {
                DDLogError("Error reading samples: \(String(describing: error))")
            }
            
            resultsHandler(error as NSError?, newSamples, nil)
        }
        healthStore?.execute(sampleQuery)
    }
    
    func findSampleDateRange(sampleType: HKSampleType, completion: @escaping (_ error: NSError?, _ startDate: Date?, _ endDate: Date?) -> Void)
    {
        DDLogVerbose("\(#function)")

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
}
