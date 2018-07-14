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

protocol HealthKitSampleUploaderDelegate: class {
    func sampleUploader(uploader: HealthKitUploader, didCompleteUploadWithError error: Error?)
}

// TODO: uploader - we should avoid using file based POSTs when in foreground (probably faster!? and simpler)

class HealthKitUploader: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    init(mode: HealthKitUploadReader.Mode, uploadType: HealthKitUploadType) {
        DDLogVerbose("trace")
        
        self.mode = mode
        self.typeString = uploadType.typeName

        super.init()

        self.ensureUploadSession(isBackground: false)
        self.ensureUploadSession(isBackground: true)
    }

    private(set) var mode: HealthKitUploadReader.Mode
    private(set) var typeString: String
    weak var delegate: HealthKitSampleUploaderDelegate?
    
    func hasPendingUploadTasks() -> Bool {
        return UserDefaults.standard.bool(forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: typeString, key: HealthKitSettings.HasPendingUploadsKey))
    }
    
    // NOTE: This is called from a query results handler, not on main thread
    func startUploadSessionTasks(with request: URLRequest, data: HealthKitUploadData) throws {
        DDLogVerbose("trace")

        // Prepare POST files for upload. Fine to do this on background thread
        let batchMetadataPostBodyURL = try self.createPostBodyFileForBatchMetadataUpload(data: data)
        let batchSamplesPostBodyURL = try createBodyFileForBatchSamplesUpload(data: data)
        
        // Store this for later. We'll create the batch samples task once the metadata task finishes
        UserDefaults.standard.set(request.url, forKey: prefixedLocalId(self.uploadSamplesRequestUrlKey))
        UserDefaults.standard.set(request.allHTTPHeaderFields, forKey: prefixedLocalId(self.uploadSamplesRequestAllHTTPHeaderFieldsKey))
        UserDefaults.standard.set(batchSamplesPostBodyURL, forKey: prefixedLocalId(self.uploadSamplesPostDataUrlKey))
        UserDefaults.standard.synchronize()
        
        DispatchQueue.main.async {
            DDLogInfo("startUploadSessionTasks on main thread")
            
            // Choose the right session to start tasks with
            var uploadSession: URLSession?
            if UIApplication.shared.applicationState == UIApplicationState.background {
                uploadSession = self.backgroundUploadSession
            } else {
                uploadSession = self.foregroundUploadSession
            }
            guard uploadSession != nil else {
                let message = "Unable to start upload tasks, session does not exist, it was probably invalidated. This is unexpected"
                let error = NSError(domain: "HealthKitUploader", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
                DDLogError(message)
                self.delegate?.sampleUploader(uploader: self, didCompleteUploadWithError: error)
                return
            }

            // Remember that we have pending tasks
            self.setPendingUploadsState(task1IsPending: true, task2IsPending: true)
            
            // Create task 1 of 2
            let task1 = uploadSession!.uploadTask(with: request, fromFile: batchMetadataPostBodyURL)
            task1.taskDescription = self.prefixedLocalId(self.uploadMetadataTaskDescription)
            DDLogInfo("Created metadata upload task (1 of 2): \(task1.taskIdentifier)")
            task1.resume()
        }
    }
    
    func cancelTasks() {
        DDLogVerbose("trace")
        
        if self.backgroundUploadSession == nil && self.foregroundUploadSession == nil {
            self.setPendingUploadsState(task1IsPending: false, task2IsPending: false)
        } else {
            var uploadSessions = [URLSession]()
            if let uploadSession = self.foregroundUploadSession {
                uploadSessions.append(uploadSession)
            }
            if let uploadSession = self.backgroundUploadSession {
                uploadSessions.append(uploadSession)
            }
            for uploadSession in uploadSessions {
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
            }
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
        UIApplication.localNotifyMessage(message)

        var httpError: NSError?
        if let response = task.response as? HTTPURLResponse {
            if !(200 ... 299 ~= response.statusCode) {
                let message = "HTTP error on upload: \(response.statusCode)"
                DDLogError(message)
                httpError = NSError(domain: "HealthKitUploader", code: -2, userInfo: [NSLocalizedDescriptionKey: message])
            }
        }
        
        if let error = error {
            self.setPendingUploadsState(task1IsPending: false, task2IsPending: false)
            self.delegate?.sampleUploader(uploader: self, didCompleteUploadWithError: error)
        } else if httpError != nil {
            self.setPendingUploadsState(task1IsPending: false, task2IsPending: false)
            self.delegate?.sampleUploader(uploader: self, didCompleteUploadWithError: httpError)
        } else if task.taskDescription == prefixedLocalId(self.uploadMetadataTaskDescription) {
            // Create task 2 of 2
            if let task2RequestAllHTTPHeaderFields = UserDefaults.standard.dictionary(forKey: prefixedLocalId(self.uploadSamplesRequestAllHTTPHeaderFieldsKey)),
               let task2RequestUrl = UserDefaults.standard.url(forKey: prefixedLocalId(self.uploadSamplesRequestUrlKey)),
               let batchSamplesPostBodyURL = UserDefaults.standard.url(forKey: prefixedLocalId(self.uploadSamplesPostDataUrlKey))
            {
                setPendingUploadsState(task1IsPending: false, task2IsPending: true)

                let batchSamplesRequest = NSMutableURLRequest(url: task2RequestUrl)
                batchSamplesRequest.httpMethod = "POST"
                for (field, value) in task2RequestAllHTTPHeaderFields {
                    batchSamplesRequest.setValue(value as? String, forHTTPHeaderField: field)
                }
                let task2 = session.uploadTask(with: batchSamplesRequest as URLRequest, fromFile: batchSamplesPostBodyURL)
                task2.taskDescription = prefixedLocalId(self.uploadSamplesTaskDescription)
                DDLogInfo("Created samples upload task (2 of 2): \(task2.taskIdentifier)")
                task2.resume()
            } else {
                let message = "Failed to find stored POST body URL or stored request for samples upload"
                let settingsError = NSError(domain: "HealthKitUploader", code: -3, userInfo: [NSLocalizedDescriptionKey: message])
                DDLogError(message)
                self.setPendingUploadsState(task1IsPending: false, task2IsPending: false)
                self.delegate?.sampleUploader(uploader: self, didCompleteUploadWithError: settingsError)
            }
        } else if task.taskDescription == prefixedLocalId(self.uploadSamplesTaskDescription) {
            self.setPendingUploadsState(task1IsPending: false, task2IsPending: false)
            self.delegate?.sampleUploader(uploader: self, didCompleteUploadWithError: nil)
        }
    }
    
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        DDLogVerbose("trace")

        DispatchQueue.main.async {
            if session == self.foregroundUploadSession {
                DDLogInfo("Foreground upload session became invalid. Mode: \(self.mode)")
                self.foregroundUploadSession = nil
                self.ensureUploadSession(isBackground: false)
            } else if session == self.backgroundUploadSession {
                DDLogInfo("Background upload session became invalid. Mode: \(self.mode)")
                self.backgroundUploadSession = nil
                self.ensureUploadSession(isBackground: true)
            }
        }
    }
    
    // MARK: Private
    
    fileprivate func ensureUploadSession(isBackground: Bool) {
        DDLogVerbose("trace")
        
        guard (isBackground && self.backgroundUploadSession == nil) || (!isBackground && self.foregroundUploadSession == nil) else {
            return
        }
        
        var configuration = URLSessionConfiguration.default
        if isBackground {
            configuration = URLSessionConfiguration.background(withIdentifier: prefixedLocalId(self.backgroundUploadSessionIdentifier))
        }
        configuration.timeoutIntervalForResource = 60 // 60 seconds
        let uploadSession = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        uploadSession.delegateQueue.maxConcurrentOperationCount = 1 // So we can serialize the metadata and samples upload POSTs

        if isBackground {            
            self.backgroundUploadSession = uploadSession
        } else {
            self.foregroundUploadSession = uploadSession
        }

        DDLogInfo("Created upload session. isBackground:\(isBackground) Mode: \(self.mode)")
    }

    fileprivate func createPostBodyFileForBatchMetadataUpload(data: HealthKitUploadData) throws -> URL {
        DDLogVerbose("trace")
        
        let postBody = try JSONSerialization.data(withJSONObject: data.batchMetadata)
        if defaultDebugLevel != DDLogLevel.off {
            let postBodyString = NSString(data: postBody, encoding: String.Encoding.utf8.rawValue)! as String
            DDLogVerbose("Start batch upload JSON: \(postBodyString)")
        }
        return try self.savePostBodyForUpload(body: postBody, identifier: "uploadBatchMetadata.data")
    }
    
    fileprivate func createBodyFileForBatchSamplesUpload(data: HealthKitUploadData) throws -> URL {
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
        UserDefaults.standard.set(task1IsPending, forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.typeString, key: HealthKitSettings.Task1IsPendingKey))
        UserDefaults.standard.set(task1IsPending || task2IsPending, forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.typeString, key: HealthKitSettings.HasPendingUploadsKey))
        UserDefaults.standard.synchronize()
    }

    fileprivate var foregroundUploadSession: URLSession?
    fileprivate var backgroundUploadSession: URLSession?
    
    // use the following with prefixedLocalId to create ids unique to mode and upload type...
    fileprivate let backgroundUploadSessionIdentifier = "uploadSessionId"
    fileprivate let uploadMetadataTaskDescription = "upload metadata"
    fileprivate let uploadSamplesTaskDescription = "upload samples"
    
    fileprivate let uploadSamplesRequestUrlKey = "uploadSamplesRequestUrl"
    fileprivate let uploadSamplesRequestAllHTTPHeaderFieldsKey = "uploadSamplesRequestAllHTTPHeaderFields"
    fileprivate let uploadSamplesPostDataUrlKey = "uploadSamplesPostDataUrl"

    fileprivate func prefixedLocalId(_ key: String) -> String {
        return "\(self.mode)-\(self.typeString)\(key)"
    }

}
