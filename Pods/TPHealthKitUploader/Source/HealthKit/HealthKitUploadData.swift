/*
 * Copyright (c) 2018, Tidepool Project
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

class HealthKitUploadData: NSObject {
    var uploadType: HealthKitUploadType
    
    init(_ uploadType: HealthKitUploadType, newSamples: [HKSample]?, deletedSamples: [HKDeletedObject]?, currentUserId: String) {
        DDLogVerbose("\(#function)")
        self.uploadType = uploadType
        super.init()
        
        self.currentUserId = currentUserId
        
        if let newSamples = newSamples {
            updateSamples(samples: newSamples)
            if newSamples.count > 0 {
                self.newOrDeletedSamplesWereDelivered = true
            }
        }
        
        if deletedSamples != nil && deletedSamples!.count > 0 {
            self.newOrDeletedSamplesWereDelivered = true
            self.deletedSamples = deletedSamples!
        }
    }

    private(set) var filteredSamples = [HKSample]()
    private(set) var earliestSampleTime = Date.distantFuture
    private(set) var latestSampleTime = Date.distantPast
    private(set) var newOrDeletedSamplesWereDelivered = false
    private(set) var deletedSamples = [HKDeletedObject]()
    
    private func updateSamples(samples: [HKSample]) {
        DDLogVerbose("type: \(uploadType.typeName)")
        
        // Sort by sample date
        let sortedSamples = samples.sorted(by: {x, y in
            return x.startDate.compare(y.startDate) == .orderedAscending
        })
        
        self.filteredSamples = uploadType.filterSamples(sortedSamples: sortedSamples)
        
        var earliestSampleTime = Date.distantFuture
        var latestSampleTime = Date.distantPast
        for sample in self.filteredSamples {
            if sample.startDate.compare(earliestSampleTime) == .orderedAscending {
                earliestSampleTime = sample.startDate
            }
            
            if sample.startDate.compare(latestSampleTime) == .orderedDescending {
                latestSampleTime = sample.startDate
            }
        }
        
        self.earliestSampleTime = earliestSampleTime
        self.latestSampleTime = latestSampleTime
    }
    
    private var currentUserId = ""
}

