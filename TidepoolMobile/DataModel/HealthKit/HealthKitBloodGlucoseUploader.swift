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

// TODO: uploader - we should avoid using file based POSTs when in foreground (probably faster!? and simpler)

class HealthKitBloodGlucoseUploader: NSObject, URLSessionDelegate, URLSessionTaskDelegate {    
    init(mode: HealthKitBloodGlucoseUploadReader.Mode) {
        DDLogVerbose("trace")
        
        self.mode = mode

        super.init()
        
        // Start off assuming background sessions. When app is made active after launch we'll switch to non-background session
        self.ensureUploadSession(background: true)
    }

    fileprivate(set) var mode: HealthKitBloodGlucoseUploadReader.Mode
    fileprivate(set) var isBackgroundUploadSession = false
    weak var delegate: HealthKitBloodGlucoseUploaderDelegate?
    
    func hasPendingUploadTasks() -> Bool {
        return UserDefaults.standard.bool(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.HasPendingUploadsKey))
    }
    
    func ensureUploadSession(background: Bool) {
        DDLogVerbose("ensureUploadSession, isBackgroundSession: \(background)")
        
        if self.uploadSession == nil {
            self.isBackgroundUploadSession = background
            
            var configuration: URLSessionConfiguration?
            if background {
                configuration = URLSessionConfiguration.background(withIdentifier: "\(self.mode)-\(self.backgroundUploadSessionIdentifier)")
            } else {
                configuration = URLSessionConfiguration.default
            }
            configuration?.timeoutIntervalForResource = 60 * 10 // Only allow 10 minutes to complete // TODO: uploader - review this
            self.uploadSession = URLSession(configuration: configuration!, delegate: self, delegateQueue: nil)
            self.uploadSession!.delegateQueue.maxConcurrentOperationCount = 1
            DDLogVerbose("created upload session, background: \(background)")
        } else {
            if background != self.isBackgroundUploadSession {
                self.isBackgroundUploadSession = background
                
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
                self.ensureUploadSession(background: self.isBackgroundUploadSession)
            }
        }
    }
    
    // NOTE: This is called from a query results handler, not on main thread
    func startUploadSessionTasks(with request: URLRequest, data: HealthKitBloodGlucoseUploadData) throws {
        DDLogVerbose("trace")

        // Prepare POST files for upload. Fine to do this on background thread
        let batchMetadataPostBodyURL = try self.createPostBodyFileForBatchMetadataUpload(data: data)
        let batchSamplesPostBodyURL = try createBodyFileForBatchSamplesUpload(data: data)
        
        // Store this for later. We'll create the batch samples task once the metadata task finishes
        UserDefaults.standard.set(request.url, forKey: "\(self.mode)-\(self.uploadSamplesRequestUrlKey)")
        UserDefaults.standard.set(request.allHTTPHeaderFields, forKey: "\(self.mode)-\(self.uploadSamplesRequestAllHTTPHeaderFieldsKey)")
        UserDefaults.standard.set(batchSamplesPostBodyURL, forKey: "\(self.mode)-\(self.uploadSamplesPostDataUrlKey)")
        UserDefaults.standard.synchronize()
        
        DispatchQueue.main.async {
            DDLogInfo("startUploadSessionTasks on main thread")
            
            guard let uploadSession = self.uploadSession else {
                let message = "Unable to start upload tasks, session does not exist, it was probably invalidated"
                let error = NSError(domain: "HealthKitBloodGlucoseUploader", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
                DDLogError(message)
                self.delegate?.bloodGlucoseUploader(uploader: self, didCompleteUploadWithError: error)
                return
            }

            self.setPendingUploadsState(task1IsPending: true, task2IsPending: true)
            
            // Create task 1 of 2
            let task1 = uploadSession.uploadTask(with: request, fromFile: batchMetadataPostBodyURL)
            task1.taskDescription = "\(self.mode) \(self.uploadMetadataTaskDescription)"
            DDLogInfo("Created metadata upload task (1 of 2): \(task1.taskIdentifier)")
            task1.resume()
        }
    }
    
    func cancelTasks() {
        DDLogVerbose("trace")
        
        if let uploadSession = self.uploadSession {
            uploadSession.getTasksWithCompletionHandler { (dataTasks, uploadTasks, downloadTasks) -> Void in
                DDLogInfo("Canceling \(uploadTasks.count) tasks")
                if uploadTasks.count > 0 {
                    for uploadTask in uploadTasks {
                        DDLogInfo("Canceling task: \(uploadTask.taskIdentifier)")
                        uploadTask.cancel()
                    }
                } else {
                    self.setPendingUploadsState(task1IsPending: false, task2IsPending: false)
                }
            }
        } else {
            DDLogError("No upload session, this is unexpected")
            
            self.setPendingUploadsState(task1IsPending: false, task2IsPending: false)
        }
    }
    
    func handleEventsForBackgroundURLSession(with identifier: String, completionHandler: @escaping () -> Void) {
        DDLogVerbose("trace")

        self.uploadSessionHandleEventsCompletionHandler = completionHandler
        
        if let uploadSession = self.uploadSession {
            uploadSession.getTasksWithCompletionHandler { (dataTasks, uploadTasks, downloadTasks) -> Void in
                for uploadTask in uploadTasks {
                    DDLogInfo("Resuming \(String(describing: uploadTask.taskDescription)) task: \(uploadTask.taskIdentifier)")
                    uploadTask.resume()
                }
            }
        } else {
            DDLogError("No upload session, this is unexpected")
        }
    }
    
    // MARK: URLSessionTaskDelegate
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DDLogVerbose("trace")

        var message = ""
        if let error = error {
            message = "Upload task failed: \(task.taskDescription!), with error: \(error), id: \(task.taskIdentifier)"
        } else {
            message = "Upload task completed: \(task.taskDescription!), id: \(task.taskIdentifier)"
        }
        DDLogInfo(message)

        if AppDelegate.testMode {
            let localNotificationMessage = UILocalNotification()
            localNotificationMessage.alertBody = message
            DispatchQueue.main.async {
                UIApplication.shared.presentLocalNotificationNow(localNotificationMessage)
            }
        }
        
        var httpError: NSError?
        if let response = task.response as? HTTPURLResponse {
            if !(200 ... 299 ~= response.statusCode) {
                let message = "HTTP error on upload: \(response.statusCode)"
                DDLogError(message)
                httpError = NSError(domain: "HealthKitBloodGlucoseUploader", code: -2, userInfo: [NSLocalizedDescriptionKey: message])
            }
        }
        
        if let error = error {
            self.setPendingUploadsState(task1IsPending: false, task2IsPending: false)
            self.delegate?.bloodGlucoseUploader(uploader: self, didCompleteUploadWithError: error)
        } else if httpError != nil {
            self.setPendingUploadsState(task1IsPending: false, task2IsPending: false)
            self.delegate?.bloodGlucoseUploader(uploader: self, didCompleteUploadWithError: httpError)
        } else if task.taskDescription == "\(self.mode) \(self.uploadMetadataTaskDescription)" {
            // Create task 2 of 2
            if let task2RequestAllHTTPHeaderFields = UserDefaults.standard.dictionary(forKey: "\(self.mode)-\(self.uploadSamplesRequestAllHTTPHeaderFieldsKey)"),
               let task2RequestUrl = UserDefaults.standard.url(forKey: "\(self.mode)-\(self.uploadSamplesRequestUrlKey)"),
               let batchSamplesPostBodyURL = UserDefaults.standard.url(forKey: "\(self.mode)-\(self.uploadSamplesPostDataUrlKey)")
            {
                setPendingUploadsState(task1IsPending: false, task2IsPending: true)

                let batchSamplesRequest = NSMutableURLRequest(url: task2RequestUrl)
                batchSamplesRequest.httpMethod = "POST"
                for (field, value) in task2RequestAllHTTPHeaderFields {
                    batchSamplesRequest.setValue(value as? String, forHTTPHeaderField: field)
                }
                let task2 = session.uploadTask(with: batchSamplesRequest as URLRequest, fromFile: batchSamplesPostBodyURL)
                task2.taskDescription = "\(self.mode) \(self.uploadSamplesTaskDescription)"
                DDLogInfo("Created samples upload task (2 of 2): \(task2.taskIdentifier)")
                task2.resume()
            } else {
                let message = "Failed to find stored POST body URL or stored request for samples upload"
                let settingsError = NSError(domain: "HealthKitBloodGlucoseUploader", code: -3, userInfo: [NSLocalizedDescriptionKey: message])
                DDLogError(message)
                self.setPendingUploadsState(task1IsPending: false, task2IsPending: false)
                self.delegate?.bloodGlucoseUploader(uploader: self, didCompleteUploadWithError: settingsError)
            }
        } else if task.taskDescription == "\(self.mode) \(self.uploadSamplesTaskDescription)" {
            self.setPendingUploadsState(task1IsPending: false, task2IsPending: false)
            self.delegate?.bloodGlucoseUploader(uploader: self, didCompleteUploadWithError: nil)
        }
    }
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DDLogVerbose("trace")

        let message = ("Did finish handling events for background session: \(session.configuration.identifier!)")
        DDLogInfo(message)
        if AppDelegate.testMode {
            let localNotificationMessage = UILocalNotification()
            localNotificationMessage.alertBody = message
            DispatchQueue.main.async {
                UIApplication.shared.presentLocalNotificationNow(localNotificationMessage)
            }
        }

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
            self.ensureUploadSession(background: self.isBackgroundUploadSession)
        }
    }
    
    // MARK: Private
    
    fileprivate func createPostBodyFileForBatchMetadataUpload(data: HealthKitBloodGlucoseUploadData) throws -> URL {
        DDLogVerbose("trace")
        
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
        for sample in data.filteredSamples {
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
        DDLogVerbose("trace")
        
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
        UserDefaults.standard.set(task1IsPending, forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.Task1IsPendingKey))
        UserDefaults.standard.set(task1IsPending || task2IsPending, forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, key: HealthKitSettings.HasPendingUploadsKey))
        UserDefaults.standard.synchronize()
    }
    
    fileprivate let backgroundUploadSessionIdentifier = "uploadBloodGlucoseSessionId"
    fileprivate let uploadMetadataTaskDescription = "upload metadata"
    fileprivate let uploadSamplesTaskDescription = "upload samples"
    
    fileprivate let uploadSamplesRequestUrlKey = "uploadSamplesRequestUrl"
    fileprivate let uploadSamplesRequestAllHTTPHeaderFieldsKey = "uploadSamplesRequestAllHTTPHeaderFields"
    fileprivate let uploadSamplesPostDataUrlKey = "uploadSamplesPostDataUrl"

    fileprivate var uploadSession: URLSession?
    fileprivate var uploadSessionHandleEventsCompletionHandler: (() -> Void)?
}
