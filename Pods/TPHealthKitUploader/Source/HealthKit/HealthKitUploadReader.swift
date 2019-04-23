/*
* Copyright (c) 2017-2018, Tidepool Project
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

enum ReaderStoppedReason {
    case error
    case turnedOff
    case withNoNewResults
    case withResults
}

// NOTE: These delegate methods are usually called indirectly from HealthKit or a URLSession delegate, on a background queue, not on main thread
protocol HealthKitUploadReaderDelegate: class {
    func uploadReader(reader: HealthKitUploadReader, didStop result: ReaderStoppedReason)
    func uploadReader(reader: HealthKitUploadReader, didUpdateSampleRange startDate: Date, endDate: Date)
}

/// There can be an instance of this class for each mode for each type of upload object.
class HealthKitUploadReader: NSObject {
    
    init(type: HealthKitUploadType, mode: TPUploader.Mode) {
        DDLogVerbose("HealthKitUploadReader (\(type.typeName),\(mode))")

        self.uploadType = type
        self.mode = mode
        self.readerSettings = HKTypeModeSettings(mode: mode, typeName: type.typeName)
        self.queryAnchor = readerSettings.queryAnchor.value
        super.init()
    }
    
    weak var delegate: HealthKitUploadReaderDelegate?
    let readerSettings: HKTypeModeSettings
    var queryAnchor: HKQueryAnchor?
    let kSampleReadLimit = 500
    
    private(set) var uploadType: HealthKitUploadType
    private(set) var mode: TPUploader.Mode
    private(set) var isReading = false
    // Reader may be stopped externally by turning off the interface. Also will stop after each read finishes, when there are no results
    private(set) var stoppedReason: ReaderStoppedReason?

    var currentUserId: String?

    private(set) var sortedSamples: [HKSample] = []
    private(set) var earliestSampleTime = Date.distantFuture
    private(set) var latestSampleTime = Date.distantPast
    private(set) var newOrDeletedSamplesWereDelivered = false
    private(set) var deletedSamples = [HKDeletedObject]()
    private(set) var earliestUploadSampleTime: Date?    // only needed for stats reporting
    private(set) var latestUploadSampleTime: Date?      // also needed for historical query range determination
    private(set) var uploadSampleCount = 0
    private(set) var uploadDeleteCount = 0
    
    func popNextSample() -> HKSample? {
        if let sample = sortedSamples.popLast() {
            if earliestUploadSampleTime == nil {
                // first sample sets both dates
                earliestUploadSampleTime = sample.startDate
                latestUploadSampleTime = sample.startDate
            } else {
                // for historical, we are going backwards chronologically...
                earliestUploadSampleTime = sample.startDate
            }
            return sample
        }
        return nil
    }

    func nextSampleDate() -> Date? {
        return sortedSamples.last?.startDate
    }

    func sampleToUploadDict(_ sample: HKSample) -> [String: AnyObject]? {
        let sampleToDict = uploadType.prepareDataForUpload(sample)
        if sampleToDict != nil {
            uploadSampleCount += 1
        }
        return sampleToDict
    }
    
    func resetUploadStats() {
        DDLogVerbose("HealthKitUploadReader (\(self.uploadType.typeName),\(self.mode))")
        earliestUploadSampleTime = nil
        latestUploadSampleTime = nil
        uploadSampleCount = 0
        uploadDeleteCount = 0
        readerSettings.resetAttemptStats()
    }
    
    func reportNextUploadStatsAtTime(_ uploadTime: Date) {
        guard let earliestSample = earliestUploadSampleTime, let latestSample = latestUploadSampleTime else {
            return
        }
        readerSettings.updateForUploadAttempt(sampleCount: uploadSampleCount, uploadAttemptTime: uploadTime, earliestSampleTime: earliestSample, latestSampleTime: latestSample)
    }
    
    func updateForSuccessfulUpload(_ uploadTime: Date) {
        DDLogVerbose("HealthKitUploadReader (\(self.uploadType.typeName),\(self.mode))")
        readerSettings.updateForSuccessfulUpload(lastSuccessfulUploadTime: uploadTime)
        if mode == .Current {
            // Note: only persist query anchor when all queried samples have been successfully uploaded! Otherwise, if app quits with buffered samples, it will miss those on a new query. This does mean that in this case the same samples may be uploaded to the service, but they will be handled by the service's de-duplication logic.
            if sortedSamples.count == 0 {
                 self.persistQueryAnchor()
            }
       } else {
            // .HistoricalAll
            let lastUploadSampleDate = readerSettings.lastSuccessfulUploadEarliestSampleTime.value
            let currentEndDate = readerSettings.queryEndDate.value
            readerSettings.queryEndDate.value = lastUploadSampleDate
            DDLogInfo("updated query end date from \(String(describing: currentEndDate)) to \(String(describing: lastUploadSampleDate))")
        }
    }
    
    func moreToRead() -> Bool {
        if let stoppedReason = self.stoppedReason {
            return stoppedReason == ReaderStoppedReason.withResults
        }
        return false
    }
    
    func nextDeletedSampleDict() -> [String: AnyObject]? {
        if let nextDelete = deletedSamples.popLast() {
            uploadDeleteCount += 1
            return uploadType.prepareDataForDelete(nextDelete)
        }
        return nil
    }
    
    func handleNewSamples(_ newSamples: [HKSample]?, deletedSamples: [HKDeletedObject]?) {
        DDLogVerbose("newSamples: \(String(describing: newSamples?.count)), deletedSamples: \(String(describing: deletedSamples?.count)) (\(self.uploadType.typeName),\(self.mode))")
        self.newOrDeletedSamplesWereDelivered = false
        self.earliestSampleTime = Date.distantFuture
        self.latestSampleTime = Date.distantPast
        
        if let newSamples = newSamples, newSamples.count > 0 {
            var unsortedSamples = self.sortedSamples
            unsortedSamples.append(contentsOf: newSamples)
            // Sort by sample date
            self.sortedSamples = unsortedSamples.sorted(by: {x, y in
                return x.startDate.compare(y.startDate) == .orderedAscending
            })
            if let firstSample = sortedSamples.first {
                self.earliestSampleTime = firstSample.startDate
            }
            if let lastSample = sortedSamples.last {
                self.latestSampleTime = lastSample.startDate
            }
            if newSamples.count > 0 {
                self.newOrDeletedSamplesWereDelivered = true
            }
        }
        
        if deletedSamples != nil && deletedSamples!.count > 0 {
            self.newOrDeletedSamplesWereDelivered = true
            self.deletedSamples.insert(contentsOf: deletedSamples!, at: self.deletedSamples.endIndex)
        }
    }
    
    func isResumable() -> Bool {
        var isResumable = false
        if self.mode == TPUploader.Mode.Current {
            isResumable = true
        } else {
            let globalSettings = HKGlobalSettings.sharedInstance
            if let firstSampleDate = readerSettings.startDateHistoricalSamples.value, let lastQueryDate = globalSettings.historicalFenceDate.value {
                // resumable if there are more
                isResumable = firstSampleDate.compare(lastQueryDate) == .orderedAscending
            } else {
                isResumable = false
            }
        }
        DDLogVerbose("(\(uploadType.typeName), \(mode.rawValue)): \(isResumable)")
        return isResumable
    }
    
    func isFreshHistoricalUpload() -> Bool {
        var result = false
        if mode == TPUploader.Mode.HistoricalAll {
            if readerSettings.startDateHistoricalSamples.value == nil {
                result = true
            }
        }
        DDLogVerbose("HealthKitUploadReader result: \(result) (\(self.uploadType.typeName),\(self.mode))")
        return result
    }
    
    func resetPersistentState() {
        DDLogVerbose("HealthKitUploadReader (\(uploadType.typeName), \(mode.rawValue))")
        readerSettings.resetAllReaderKeys()
        readerSettings.startDateHistoricalSamples.value = nil
        readerSettings.endDateHistoricalSamples.value = nil
        self.lastHistoricalReadCount = nil
    }

    func startReading() {
        DDLogVerbose("HealthKitUploadReader (\(self.uploadType.typeName),\(self.mode))")
        
        guard !self.isReading else {
            DDLogVerbose("Ignoring request to start reading samples, already reading samples")
            return
        }
        
        self.isReading = true
        self.stoppedReason = nil
        
        if isFreshHistoricalUpload() {
            // for historical upload, we first need to figure out the earliest and latest samples
            self.updateHistoricalSamplesDateRangeFromHealthKitAsync()
        } else {
            self.mode == .Current ? self.readMoreCurrent() : self.readMoreHistorical()
        }
    }
    
    private func persistQueryAnchor() {
        DDLogVerbose("HealthKitUploadReader (\(self.uploadType.typeName),\(self.mode))")
        readerSettings.queryAnchor.value = self.queryAnchor
    }
    
    func stopReading() {
        DDLogVerbose("HealthKitUploadReader (\(self.uploadType.typeName),\(self.mode))")

        guard self.isReading else {
            DDLogInfo("Not currently reading, ignoring. Mode: \(self.mode)")
            return
        }
        self.stopReading(.turnedOff)
    }
    
    private func stopReading(_ reason: ReaderStoppedReason) {
        DDLogVerbose("HealthKitUploadReader reason: \(reason)) (\(self.uploadType.typeName),\(self.mode))")
        guard self.isReading else {
            DDLogInfo("Currently turned off, ignoring. Mode: \(self.mode)")
            return
        }
        self.stoppedReason = reason
        self.isReading = false
        // always notify delegate when stopping, except when interface has been turned off (external call)
        if reason != .turnedOff {
            self.delegate?.uploadReader(reader: self, didStop: reason)
        }
    }
    
    private func readMoreCurrent() {
        DDLogInfo("(\(uploadType.typeName), \(mode.rawValue))")
        
        // if we have buffered samples and last upload didn't use any, we are done...
        let bufferedSamplesCount = sortedSamples.count
        if bufferedSamplesCount > 0 {
            if bufferedSamplesCount >= kSampleReadLimit {
                // we still have kSampleReadLimit or more samples, so no need to read more...
                self.stopReading(.withResults)
                return
            }
        }
        
        // note the anchor
        DDLogVerbose("anchor: \(String(describing: self.queryAnchor))")

        let globalSettings = HKGlobalSettings.sharedInstance
        guard var startDate = globalSettings.currentStartDate.value else {
            self.stopReading(.error)
            DDLogError("Missing global start date!!!")
            return
        }
        
        // Note: readerSettings.queryStartDate and queryEndDate are not needed for current; queryEndDate is used for historical. However, readerSettings.queryStartDate might be set from a previous release, and could therefore be used to continue an anchor query without redundant uploads. If an historical query is re-run, everything can be reset.
        
        if let queryStart = readerSettings.queryStartDate.value {
            // this handles compatibility from previous software release, so a current query will continue to work with that previous anchor.
            startDate = queryStart
        }
        
        DDLogInfo("using query start: \(startDate), end: \(Date.distantFuture)")
        self.readSamplesFromAnchorForType(self.uploadType, start: startDate, end: Date.distantFuture, anchor: self.queryAnchor, limit: kSampleReadLimit, resultsHandler: self.currentReadResultsHandler)
    }

    private func readMoreHistorical() {
        DDLogInfo("(\(uploadType.typeName), \(mode.rawValue))")
        
        // Get the fence date for the predicate
        let globalSettings = HKGlobalSettings.sharedInstance
        var fenceDate = globalSettings.historicalFenceDate.value
        guard fenceDate != nil else {
            DDLogError("Err: missing historicalFenceDate!")
            self.stopReading(.withNoNewResults)
            return
        }
        
        // If we have buffered samples, we want to start the query where we left off rather than the historical fence date..
        let bufferedSamplesCount = sortedSamples.count
        if bufferedSamplesCount > 0 {
            if bufferedSamplesCount == kSampleReadLimit {
                // last upload didn't take any of our samples, so no need to read more...
                // always let our delegate know we've finished with the latest read, error or not!
                self.stopReading(.withResults)
                return
            }
            // we have buffered samples, so the read fence for this read should be just before the last sample we read
            let earliestSampleRead = sortedSamples[0]
            fenceDate = earliestSampleRead.startDate.addingTimeInterval(-1.0)
        }
        
        if let lastReadCount = self.lastHistoricalReadCount {
            if lastReadCount < kSampleReadLimit {
                // our last read returned less than the limit, so we fetched all the data...
                
                self.stopReading(.withNoNewResults)
                return
            }
        }
        
        DDLogInfo("using query end: \(fenceDate!)")
        // .HistoricalAll
        self.readHistoricalSamplesForType(self.uploadType, endDate: fenceDate!, limit: kSampleReadLimit, resultsHandler: self.historicalReadResultsHandler)
    }
    
    // MARK: Private
    
    func updateHistoricalSamplesDateRangeFromHealthKitAsync() {
        DDLogVerbose("HealthKitUploadReader (\(self.uploadType.typeName),\(self.mode))")

        let sampleType = uploadType.hkSampleType()!
        self.findSampleDateRange(sampleType: sampleType) {
            (error: NSError?, startDate: Date?, endDate: Date?) in
            
            DispatchQueue.main.async {
                DDLogVerbose("HealthKitUploadReader [Main] error: \(String(describing: error)) start: \(String(describing: startDate)) end: \(String(describing: endDate)) (\(self.uploadType.typeName),\(self.mode))")
                if error == nil, let startDate = startDate, let endDate = endDate {
                    self.readerSettings.updateForHistoricalSampleRange(startDate: startDate, endDate: endDate)
                    self.readerSettings.startDateHistoricalSamples.value = startDate
                    self.readerSettings.endDateHistoricalSamples.value = endDate
                    // let delegate know we have determined our sample date range...
                    self.delegate?.uploadReader(reader: self, didUpdateSampleRange: startDate, endDate: endDate)
                    // now we have goalposts, see if we can read.
                   self.readMoreHistorical()
                } else {
                    if let error = error {
                        DDLogError("Failed to update historical samples date range, error: \(error)")
                    } else {
                        DDLogVerbose("no historical samples found !")
                    }
                    
                    // set start and end to current date, to mark that findSampleDateRange has been run, and show that no historical samples are available for this type.
                    let noSamplesDate = Date.distantFuture
                    self.readerSettings.updateForHistoricalSampleRange(startDate: noSamplesDate, endDate: noSamplesDate)
                    self.readerSettings.startDateHistoricalSamples.value = noSamplesDate
                    self.readerSettings.endDateHistoricalSamples.value = noSamplesDate
                    self.stopReading(.withNoNewResults)
                    // now we have goalposts, see if we can read.
                }
            }
        }
    }
    
    // NOTE: This is a HealthKit results handler, not called on main thread
    private func currentReadResultsHandler(_ error: NSError?, newSamples: [HKSample]?, deletedSamples: [HKDeletedObject]?, newAnchor: HKQueryAnchor?) {
        DispatchQueue.main.async {
            
            var debugStr = ""
            if let newSamples = newSamples {
                debugStr = "newSamples: \(newSamples.count)"
            }
            if let deletedSamples = deletedSamples {
                debugStr += " deletedSamples: \(deletedSamples.count)"
            }
            DDLogVerbose("(\(self.uploadType.typeName), \(self.mode.rawValue)) \(debugStr)")
            if error != nil {
                DDLogError("Error: \(String(describing: error!))")
            }
            
            guard self.isReading else {
                DDLogInfo("Not currently reading, ignoring")
                return
            }
            
            guard let _ = self.currentUserId else {
                DDLogInfo("No logged in user, unable to upload")
                return
            }
            
            var stoppedReason: ReaderStoppedReason = .withResults
            if error == nil {
                // update our anchor after a successful read. It will be persisted after all samples have been uploaded...
                self.queryAnchor = newAnchor
                self.handleNewSamples(newSamples, deletedSamples: deletedSamples)
                if !self.newOrDeletedSamplesWereDelivered {
                    DDLogVerbose("stop due to no results!")
                    stoppedReason = .withNoNewResults
                }
            } else {
                stoppedReason = .error
                DDLogError("(\(self.uploadType.typeName), mode: \(self.mode.rawValue)) Error reading most recent samples: \(String(describing: error))")
            }
            // enter appropriate stopped state
            self.stopReading(stoppedReason)
        }
    }
    
    // NOTE: This is a HealthKit results handler, not called on main thread
    private var lastHistoricalReadCount: Int?
    private func historicalReadResultsHandler(_ error: NSError?, newSamples: [HKSample]?) {
        
        DispatchQueue.main.async {
            var debugStr = ""
            if let newSamples = newSamples {
                debugStr = "newSamples: \(newSamples.count)"
            }
            DDLogVerbose("(\(self.uploadType.typeName), \(self.mode.rawValue)) \(debugStr)")
            if error != nil {
                DDLogError("Error: \(String(describing: error!))")
            }
            
            guard self.isReading else {
                DDLogInfo("Not currently reading, ignoring")
                return
            }
            
            guard let _ = self.currentUserId else {
                DDLogInfo("No logged in user, unable to upload")
                return
            }
            
            var stoppedReason: ReaderStoppedReason = .withResults
            if error == nil {
                self.lastHistoricalReadCount = newSamples?.count
                self.handleNewSamples(newSamples, deletedSamples: nil)
                if !self.newOrDeletedSamplesWereDelivered {
                    stoppedReason = .withNoNewResults
                }
            } else {
                stoppedReason = .error
                DDLogError("(\(self.uploadType.typeName), mode: \(self.mode.rawValue)) Error reading most recent samples: \(String(describing: error))")
            }
            // enter appropriate stopped state
            self.stopReading(stoppedReason)
        }
    }

    
    //
    // MARK: - Health Store reading methods
    //
    
    /// Uses an HKAnchoredObjectQuery to get current samples starting at a fence start date and going to the far future.
    func readSamplesFromAnchorForType(_ uploadType: HealthKitUploadType, start: Date, end: Date, anchor: HKQueryAnchor?, limit: Int, resultsHandler: @escaping ((NSError?, [HKSample]?, [HKDeletedObject]?, HKQueryAnchor?) -> Void))
    {
        DDLogVerbose("HealthKitUploadReader (\(self.uploadType.typeName),\(self.mode))")
        let hkManager = HealthKitManager.sharedInstance
         guard hkManager.isHealthDataAvailable else {
            DDLogError("Unexpected HealthKitManager call when health data not available")
            return
        }
 
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [.strictStartDate])
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
        hkManager.healthStore?.execute(sampleQuery)
    }
    
    /// Uses an HKSampleQuery to get historical samples starting at a fence end date and working back in time.
    func readHistoricalSamplesForType(_ uploadType: HealthKitUploadType, endDate: Date, limit: Int, resultsHandler: @escaping (((NSError?, [HKSample]?) -> Void)))
    {
        DDLogInfo("HealthKitUploadReader endDate: \(endDate), limit: \(limit) (\(self.uploadType.typeName),\(self.mode))")
        let hkManager = HealthKitManager.sharedInstance

        guard hkManager.isHealthDataAvailable else {
            DDLogError("Unexpected HealthKitManager call when health data not available")
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: Date.distantPast, end: endDate, options: [.strictStartDate])
        let sortDescriptor = NSSortDescriptor(key:HKSampleSortIdentifierStartDate, ascending: false)
        
        let sampleType = uploadType.hkSampleType()!
        let sampleQuery = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: limit, sortDescriptors: [sortDescriptor]) {
            (query, newSamples, error) -> Void in
            
            if error != nil {
                DDLogError("Error reading samples: \(String(describing: error))")
            }
            
            resultsHandler(error as NSError?, newSamples)
        }
        hkManager.healthStore?.execute(sampleQuery)
    }
    
    func findSampleDateRange(sampleType: HKSampleType, completion: @escaping (_ error: NSError?, _ startDate: Date?, _ endDate: Date?) -> Void)
    {
        DDLogVerbose("HealthKitUploadReader (\(self.uploadType.typeName),\(self.mode))")
        let hkManager = HealthKitManager.sharedInstance

        var earliestSampleDate: Date? = nil
        var latestSampleDate: Date? = nil
        
        let globalSettings = HKGlobalSettings.sharedInstance
        var endDate = Date.distantFuture
        if let fenceDate = globalSettings.currentStartDate.value {
            endDate = fenceDate
            DDLogVerbose("search end date: \(fenceDate)")
        } else {
            DDLogError("Fence date should already be set!")
        }

        let predicate = HKQuery.predicateForSamples(withStart: Date.distantPast, end: endDate, options: [])
        let startDateSortDescriptor = NSSortDescriptor(key:HKSampleSortIdentifierStartDate, ascending: true)
        let endDateSortDescriptor = NSSortDescriptor(key:HKSampleSortIdentifierStartDate, ascending: false)
        
        // Kick off query to find startDate
        let startDateSampleQuery = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: 1, sortDescriptors: [startDateSortDescriptor]) {
            (query: HKSampleQuery, samples: [HKSample]?, error: Error?) -> Void in
            
            DDLogVerbose("startDateSampleQuery: error: \(String(describing: error)) sample count: \(String(describing: samples?.count)) (\(self.uploadType.typeName),\(self.mode))")
            if error == nil && samples != nil {
                // Get date of oldest sample
                if samples!.count > 0 {
                    earliestSampleDate = samples![0].startDate
                }
                
                // Kick off query to find endDate
                let endDateSampleQuery = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: 1, sortDescriptors: [endDateSortDescriptor]) {
                    (query: HKSampleQuery, samples: [HKSample]?, error: Error?) -> Void in
                    
                    DDLogVerbose("endDateSampleQuery: error: \(String(describing: error)) sample count: \(String(describing: samples?.count)) (\(self.uploadType.typeName),\(self.mode))")
                    if error == nil && samples != nil && samples!.count > 0 {
                        latestSampleDate = samples![0].startDate
                        DDLogInfo("HealthKitUploadReader complete for \(self.uploadType.typeName): \(String(describing: earliestSampleDate))) to \(String(describing: latestSampleDate))")
                    }
                    
                    completion((error as NSError?), earliestSampleDate, latestSampleDate)
                }
                hkManager.self.healthStore?.execute(endDateSampleQuery)
            } else {
                completion((error as NSError?), earliestSampleDate, latestSampleDate)
            }
        }
        hkManager.healthStore?.execute(startDateSampleQuery)
    }
    
    // MARK: Observation
    
    func startObservingSamples() {
        DDLogVerbose("HealthKitUploadReader (\(self.uploadType.typeName),\(self.mode))")
        let hkManager = HealthKitManager.sharedInstance
        guard hkManager.isHealthDataAvailable else {
            DDLogError("Unexpected HealthKitManager call when health data not available")
            return
        }
        
        if uploadType.sampleObservationQuery != nil {
            hkManager.healthStore?.stop(uploadType.sampleObservationQuery!)
            uploadType.sampleObservationQuery = nil
        }
        
        let sampleType = uploadType.hkSampleType()!
        uploadType.sampleObservationQuery = HKObserverQuery(sampleType: sampleType, predicate: nil) {
            (query, observerQueryCompletion, error) in
            
            DDLogVerbose("Observation query called (\(self.uploadType.typeName), \(self.mode.rawValue))")
            
            if error != nil {
                DDLogError("HealthKit observation error \(String(describing: error))")
            }

            // Per HealthKit docs: Calling this block tells HealthKit that you have successfully received the background data. If you do not call this block, HealthKit continues to attempt to launch your app using a back off algorithm. If your app fails to respond three times, HealthKit assumes that your app cannot receive data, and stops sending you background updates
            DDLogVerbose("observerQueryCompletion called (\(self.uploadType.typeName), \(self.mode.rawValue)) ")
            observerQueryCompletion()

            // TODO: moved this after the observerQueryCompletion call, at least during debugging, so system doesn't turn off calls...
            self.sampleObservationHandler(error as NSError?)
            
        }
        hkManager.healthStore?.execute(uploadType.sampleObservationQuery!)
    }
    
    // NOTE: This is a query observer handler called from HealthKit, not on main thread
    private func sampleObservationHandler(_ error: NSError?) {
        DDLogVerbose("HealthKitUploadReader error: \(String(describing: error)) (\(self.uploadType.typeName), \(self.mode.rawValue))")
        
        DispatchQueue.main.async {
            DDLogInfo("HealthKitUploadReader [Main] (\(self.uploadType.typeName), \(self.mode.rawValue))")
            
            guard self.mode == .Current else {
                DDLogError("uploadObservationHandler called on historical reader!")
                return
            }
            
            guard !self.isReading else {
                DDLogInfo("currently reading, ignore observer query!")
                return
            }
            
            guard error == nil else {
                DDLogError("sampleObservationQuery error: \(String(describing: error))")
                return
            }
            
            // kick off a read to get the new samples...
            // TODO: but not if we haven't reached the end of initial .Current upload?
            self.startReading()
            
        }
    }

    func stopObservingSamples() {
        DDLogVerbose("HealthKitUploadReader (\(self.uploadType.typeName),\(self.mode))")

        let hkManager = HealthKitManager.sharedInstance
        guard hkManager.isHealthDataAvailable else {
            DDLogError("Unexpected HealthKitManager call when health data not available")
            return
        }
        
        if uploadType.sampleObservationQuery != nil {
            hkManager.healthStore?.stop(uploadType.sampleObservationQuery!)
            uploadType.sampleObservationQuery = nil
        }
    }
    
    // MARK: Background delivery
    
    // Note: this only works on a device; on the simulator, the app will not be called while it is in the background.
    func enableBackgroundDeliverySamples() {
        DDLogVerbose("HealthKitUploadReader (\(self.uploadType.typeName),\(self.mode))")

        let hkManager = HealthKitManager.sharedInstance
        guard hkManager.isHealthDataAvailable else {
            DDLogError("Unexpected HealthKitManager call when health data not available")
            return
        }
        
        if !uploadType.sampleBackgroundDeliveryEnabled {
            hkManager.healthStore?.enableBackgroundDelivery(
                for: uploadType.hkSampleType()!,
                frequency: HKUpdateFrequency.immediate) {
                    success, error -> Void in
                    if error == nil {
                        self.uploadType.sampleBackgroundDeliveryEnabled = true
                        DDLogInfo("Enabled (\(self.uploadType.typeName), \(self.mode.rawValue))")
                    } else {
                        DDLogError("Error enabling background delivery: \(String(describing: error)) (\(self.uploadType.typeName), \(self.mode.rawValue))")
                    }
            }
        }
    }
}
