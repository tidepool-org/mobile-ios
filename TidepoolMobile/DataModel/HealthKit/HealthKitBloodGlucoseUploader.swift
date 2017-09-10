/*
* Copyright (c) 2016, Tidepool Project
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
import CryptoSwift

protocol HealthKitBloodGlucoseUploaderDelegate: class {
    func bloodGlucoseUploaderDidCreateSession(uploader: HealthKitBloodGlucoseUploader)
    func bloodGlucoseUploader(uploader: HealthKitBloodGlucoseUploader, didCompleteUploadWithError error: Error?)
}

class HealthKitBloodGlucoseUploader: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    override init() {
        DDLogVerbose("trace")
        
        super.init()
        
        // Start off assuming background sessions. When app is made active after launch we'll switch to non-background session
        self.ensureUploadSession(background: true)
    }

    weak var delegate: HealthKitBloodGlucoseUploaderDelegate?
    
    func hasPendingUploadTasks() -> Bool {
        return UserDefaults.standard.bool(forKey: "hasPendingUploads")
    }
    
    func ensureUploadSession(background: Bool) {
        DDLogVerbose("trace")
        
        if self.uploadSession == nil {
            self.uploadSessionIsBackground = background
            
            var configuration: URLSessionConfiguration?
            if background {
                configuration = URLSessionConfiguration.background(withIdentifier: self.backgroundUploadSessionIdentifier)
            } else {
                configuration = URLSessionConfiguration.default
            }
            configuration?.timeoutIntervalForResource = 60 * 5 // Only allow 5 minutes to complete
            self.uploadSession = URLSession(configuration: configuration!, delegate: self, delegateQueue: nil)
            self.uploadSession!.delegateQueue.maxConcurrentOperationCount = 1
            DDLogVerbose("created upload session, background: \(background)")
        } else {
            if background != self.uploadSessionIsBackground {
                self.uploadSessionIsBackground = background
                
                self.resetUploadSession()
            }
        }
        
        self.delegate?.bloodGlucoseUploaderDidCreateSession(uploader: self)
    }
    
    func resetUploadSession() {
        DDLogVerbose("trace")

        self.setPendingUploadsState(task1IsPending: false, task2IsPending: false)

        if self.uploadSession != nil {
            DDLogVerbose("Invalidating upload session")
            self.uploadSession!.invalidateAndCancel()
            self.uploadSession = nil
        } else {
            DispatchQueue.main.async {
                DDLogInfo("didBecomeInvalidWithError on main thread")
                
                // Ensure it again
                self.ensureUploadSession(background: self.uploadSessionIsBackground)
            }
        }
    }
    
    // NOTE: This is called from a query results handler, not on main thread
    func startUploadSessionTasks(with request: URLRequest, data: HealthKitBloodGlucoseUploadData) throws {
        DDLogVerbose("trace")
        
        // Prepare POST files for upload. Fine to do this on background thread
        let batchMetadataPostBodyURL = try self.createPostBodyFileForBatchMetadataUpload(data: data)
        let batchSamplesPostBodyURL = try createBodyFileForBatchSamplesUpload(data: data)
        
        DispatchQueue.main.async {
            DDLogInfo("startUploadSessionTasks on main thread")
            
            guard let uploadSession = self.uploadSession else {
                DDLogError("Unable to upload, session does not exist, it was probably invalidated, will try again next time we are notified of new samples, or after delay")
                return
            }

            self.setPendingUploadsState(task1IsPending: true, task2IsPending: true)
            
            // Create task1
            let task1 = uploadSession.uploadTask(with: request, fromFile: batchMetadataPostBodyURL)
            task1.taskDescription = self.task1IdentifierKey
            DDLogInfo("Created metadata upload task (1 of 2): \(task1.taskIdentifier)")
            task1.resume()

            // Create task2
            let task2 = uploadSession.uploadTask(with: request, fromFile: batchSamplesPostBodyURL)
            task2.taskDescription = "task2"
            task2.taskDescription = self.task2IdentifierKey
            DDLogInfo("Created samples upload task (2 of 2): \(task2.taskIdentifier)")
            task2.resume()
            
            // Suspend task2 until task1 completes. 
            // NOTE: It has to be resumed first, though, then suspended, else it's "lost" in the session and 
            // can't be iterated via getTasksWithCompletionHandler
            task2.suspend()

        }
    }
    
    func cancelTasks() {
        DDLogVerbose("trace")
        
        self.setPendingUploadsState(task1IsPending: false, task2IsPending: false)
        
        if let uploadSession = self.uploadSession {
            uploadSession.getTasksWithCompletionHandler { (dataTasks, uploadTasks, downloadTasks) -> Void in
                DDLogInfo("Canceling \(uploadTasks.count) tasks")
                for uploadTask in uploadTasks {
                    DDLogInfo("Canceling task: \(uploadTask.taskIdentifier)")
                    uploadTask.cancel()
                }
            }
        } else {
            DDLogError("No upload session, this is unexpected")
        }
    }
    
    func handleEventsForBackgroundURLSession(with identifier: String, completionHandler: @escaping () -> Void) {
        DDLogVerbose("trace")

        self.uploadSessionHandleEventsCompletionHandler = completionHandler
        
        if let uploadSession = self.uploadSession {
            uploadSession.getTasksWithCompletionHandler { (dataTasks, uploadTasks, downloadTasks) -> Void in
                var task1: URLSessionUploadTask?
                var task2: URLSessionUploadTask?
                for uploadTask in uploadTasks {
                    if uploadTask.taskDescription == self.task1IdentifierKey {
                        task1 = uploadTask
                    } else if uploadTask.taskDescription == self.task2IdentifierKey {
                        task2 = uploadTask
                    } else {
                        DDLogError("Found upload task that we weren't tracking: \(uploadTask.taskIdentifier), this is unexpected")
                    }
                    uploadTask.resume()
                }
                // If the first task has not completed yet, suspend second task
                if task1 != nil && task1?.state != .completed {
                    task2?.suspend()
                }
            }
        } else {
            DDLogError("No upload session, this is unexpected")
        }
    }
    
    // MARK: URLSessionTaskDelegate
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DDLogVerbose("trace")

        if let error = error {
            DDLogError("task completed: \(String(describing: task.taskDescription)), with error: \(error), id: \(task.taskIdentifier)")
        } else {
            DDLogInfo("task completed: \(String(describing: task.taskDescription)), id: \(task.taskIdentifier)")
        }
        
        var httpError: NSError?
        if let response = task.response as? HTTPURLResponse {
            if !(200 ... 299 ~= response.statusCode) {
                let message = "HTTP error on upload: \(response.statusCode)"
                DDLogError(message)
                httpError = NSError(domain: "HealthKitBloodGlucoseUploader", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
            }
        }
        
        if let error = error {
            self.setPendingUploadsState(task1IsPending: false, task2IsPending: false)
            self.delegate?.bloodGlucoseUploader(uploader: self, didCompleteUploadWithError: error)
        } else if httpError != nil {
            self.setPendingUploadsState(task1IsPending: false, task2IsPending: false)
            self.delegate?.bloodGlucoseUploader(uploader: self, didCompleteUploadWithError: httpError)
        } else if task.taskDescription == self.task1IdentifierKey {
            setPendingUploadsState(task1IsPending: false, task2IsPending: true)
            session.getTasksWithCompletionHandler { (dataTasks, uploadTasks, downloadTasks) -> Void in
                var task2Found = false
                for uploadTask in uploadTasks {
                    DDLogInfo("Upload task exists: \(uploadTask.taskIdentifier), with state: \(uploadTask.state.rawValue)")
                    if uploadTask.taskDescription == self.task2IdentifierKey {
                        task2Found = true
                        DDLogInfo("Resuming task 2")
                        uploadTask.resume()
                    }
                }
                if !task2Found {
                    self.setPendingUploadsState(task1IsPending: false, task2IsPending: false)
                    let message = "Task 2 was not found to resume, this is unexpected"
                    let error = NSError(domain: "HealthKitBloodGlucoseUploader", code: -2, userInfo: [NSLocalizedDescriptionKey: message])
                    DDLogInfo(message)
                    self.delegate?.bloodGlucoseUploader(uploader: self, didCompleteUploadWithError: error)
                }
            }
        } else if task.taskDescription == self.task2IdentifierKey {
            if !UserDefaults.standard.bool(forKey: "task1IsPending") {
                self.setPendingUploadsState(task1IsPending: false, task2IsPending: false)
                DDLogInfo("Both upload tasks have completed")
                self.delegate?.bloodGlucoseUploader(uploader: self, didCompleteUploadWithError: nil)
            } else {
                self.setPendingUploadsState(task1IsPending: false, task2IsPending: false)
                let message = "Task 2 completed, but task 1 appeared to be pending, this is unexpected."
                DDLogInfo(message)
                let error = NSError(domain: "HealthKitBloodGlucoseUploader", code: -3, userInfo: [NSLocalizedDescriptionKey: message])
                self.delegate?.bloodGlucoseUploader(uploader: self, didCompleteUploadWithError: error)
            }
        }
    }
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DDLogVerbose("trace")

        if let uploadSessionHandleEventsCompletionHandler = self.uploadSessionHandleEventsCompletionHandler {
            uploadSessionHandleEventsCompletionHandler()
        }
    }
    
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        DDLogVerbose("trace")

        self.uploadSession = nil

        DispatchQueue.main.async {
            DDLogInfo("didBecomeInvalidWithError on main thread")

            // Ensure it again
            self.ensureUploadSession(background: self.uploadSessionIsBackground)
        }
    }
    
    // MARK: Private
    
    fileprivate func createPostBodyFileForBatchMetadataUpload(data: HealthKitBloodGlucoseUploadData) throws -> URL {
        let postBody = try JSONSerialization.data(withJSONObject: data.batchMetadata)
        if defaultDebugLevel != DDLogLevel.off {
            let postBodyString = NSString(data: postBody, encoding: String.Encoding.utf8.rawValue)! as String
            DDLogVerbose("Start batch upload JSON: \(postBodyString)")
        }
        return try self.savePostBodyForUpload(body: postBody, identifier: "uploadBatchMetadata.data")
    }
    
    fileprivate func createBodyFileForBatchSamplesUpload(data: HealthKitBloodGlucoseUploadData) throws -> URL {
        DDLogVerbose("trace")

        // Prepare upload post body
        let dateFormatter = DateFormatter()
        var samplesToUploadDictArray = [[String: AnyObject]]()
        for sample in data.samples {
            var sampleToUploadDict = [String: AnyObject]()
            
            sampleToUploadDict["uploadId"] = data.batchMetadata["uploadId"]
            sampleToUploadDict["type"] = "cbg" as AnyObject?
            sampleToUploadDict["deviceId"] = data.batchMetadata["deviceId"]
            sampleToUploadDict["guid"] = sample.uuid.uuidString as AnyObject?
            sampleToUploadDict["time"] = dateFormatter.isoStringFromDate(sample.startDate, zone: TimeZone(secondsFromGMT: 0), dateFormat: iso8601dateZuluTime) as AnyObject?
            
            if let quantitySample = sample as? HKQuantitySample {
                let units = "mg/dL"
                sampleToUploadDict["units"] = units as AnyObject?
                let unit = HKUnit(from: units)
                let value = quantitySample.quantity.doubleValue(for: unit)
                sampleToUploadDict["value"] = value as AnyObject?
                
                // Add out-of-range annotation if needed
                var annotationCode: String?
                var annotationValue: String?
                var annotationThreshold = 0
                if (value < 40) {
                    annotationCode = "bg/out-of-range"
                    annotationValue = "low"
                    annotationThreshold = 40
                } else if (value > 400) {
                    annotationCode = "bg/out-of-range"
                    annotationValue = "high"
                    annotationThreshold = 400
                }
                if let annotationCode = annotationCode,
                       let annotationValue = annotationValue {
                    let annotations = [
                        [
                            "code": annotationCode,
                            "value": annotationValue,
                            "threshold": annotationThreshold
                        ]
                    ]
                    sampleToUploadDict["annotations"] = annotations as AnyObject?
                }
            }
            
            // Add sample metadata payload props
            if var metadata = sample.metadata {
                for (key, value) in metadata {
                    if let dateValue = value as? Date {
                        if key == "Receiver Display Time" {
                            metadata[key] = dateFormatter.isoStringFromDate(dateValue, zone: TimeZone(secondsFromGMT: 0), dateFormat: iso8601dateNoTimeZone)
                            
                        } else {
                            metadata[key] = dateFormatter.isoStringFromDate(dateValue, zone: TimeZone(secondsFromGMT: 0), dateFormat: iso8601dateZuluTime)
                        }
                    }
                }
                
                // If "Receiver Display Time" exists, use that as deviceTime and remove from metadata payload
                if let receiverDisplayTime = metadata["Receiver Display Time"] {
                    sampleToUploadDict["deviceTime"] = receiverDisplayTime as AnyObject?
                    metadata.removeValue(forKey: "Receiver Display Time")
                }
                sampleToUploadDict["payload"] = metadata as AnyObject?
            }
            
            // Add sample
            samplesToUploadDictArray.append(sampleToUploadDict)
        }

        let postBody = try JSONSerialization.data(withJSONObject: samplesToUploadDictArray)
        return try self.savePostBodyForUpload(body: postBody, identifier: "uploadBatchSamples.data")
    }
    
    fileprivate func savePostBodyForUpload(body: Data, identifier: String) throws -> URL {
        let postBodyURL = getUploadURLForIdentifier(with: identifier)
        try body.write(to: postBodyURL, options: .atomic)
        return postBodyURL
    }
    
    fileprivate func getUploadURLForIdentifier(with identifier: String) -> URL {
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let postBodyURL = cachesDirectory.appendingPathComponent(identifier)
        return postBodyURL
    }
    
    fileprivate func setPendingUploadsState(task1IsPending: Bool, task2IsPending: Bool) {
        UserDefaults.standard.set(task1IsPending, forKey: "task1IsPending")
        UserDefaults.standard.set(task1IsPending || task2IsPending, forKey: "hasPendingUploads")
        UserDefaults.standard.synchronize()
    }
    
    fileprivate let backgroundUploadSessionIdentifier = "uploadBloodGlucoseSessionId"
    fileprivate let task1IdentifierKey = "task1Identifier"
    fileprivate let task2IdentifierKey = "task2Identifier"

    fileprivate var uploadSession: URLSession?
    fileprivate var uploadSessionIsBackground = false
    fileprivate var uploadSessionHandleEventsCompletionHandler: (() -> Void)?
}
