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
    
    let settings = HKGlobalSettings.sharedInstance
    
    let healthStore: HKHealthStore? = {
        return HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil
    }()
    
    let isHealthDataAvailable: Bool = {
        return HKHealthStore.isHealthDataAvailable()
    }()
    
    func authorizationRequestedForUploaderSamples() -> Bool {
        return settings.authorizationRequestedForUploaderSamples.value
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
                    self.settings.authorizationRequestedForUploaderSamples.value = true
                 }
                
                authorizationSuccess = success
                authorizationError = error as NSError?
                
                DDLogInfo("authorization success: \(authorizationSuccess), error: \(String(describing: authorizationError))")
                
                completion(authorizationSuccess, authorizationError)
            }
        }
    }
    
}
