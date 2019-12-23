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

protocol HealthKitSampleUploaderDelegate: class {
    func sampleUploader(uploader: HealthKitUploader, didCompleteUploadWithError error: Error?, rejectedSamples: [Int]?)
}

class HealthKitUploader: NSObject, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate {
    init(_ mode: TPUploader.Mode) {
        DDLogVerbose("mode: \(mode.rawValue)")
        
        self.mode = mode
        super.init()

        self.ensureUploadSession()
    }

    private(set) var mode: TPUploader.Mode
    weak var delegate: HealthKitSampleUploaderDelegate?
    private let settings = HKGlobalSettings.sharedInstance

    func hasPendingUploadTasks() -> Bool {
        let setting = mode == .Current ? settings.hasPendingCurrentUploads : settings.hasPendingHistoricalUploads
        return setting.value
    }
    
    private var lastUploadSamplePostBody: Data?
    private var lastDeleteSamplePostBody: Data?

    private var debugSkipUpload = false
    // NOTE: This is called from a query results handler, not on main thread
    func startUploadSessionTasks(with samples: [[String: AnyObject]], deletes: [[String: AnyObject]]) throws {
        DDLogVerbose("mode: \(mode.rawValue)")
        
        // Prepare POST files for upload. Fine to do this on background thread (Upload tasks from NSData are not supported in background sessions, so this has to come from a file, at least if we are in the background).
        // May be nil if no samples to upload
        //DDLogVerbose("samples to upload: \(samples)")
        let (batchSamplesPostBodyURL, samplePostBody) = try createBodyFileForBatchSamplesUpload(samples)
        lastUploadSamplePostBody = samplePostBody
        
        // May be nil if no samples to delete
        let (batchSamplesDeleteBodyURL, deletePostBody) = try createBodyFileForBatchSamplesDelete(deletes)
        lastDeleteSamplePostBody = deletePostBody
        UserDefaults.standard.set(batchSamplesDeleteBodyURL, forKey: prefixedLocalId(self.deleteSamplesDataUrlKey))

        DispatchQueue.main.async {
            DDLogInfo("(mode: \(self.mode.rawValue)) [main]")
            if self.debugSkipUpload {
                DDLogInfo("DEBUG SKIPPING UPLOAD!")
                self.delegate?.sampleUploader(uploader: self, didCompleteUploadWithError: nil, rejectedSamples: nil)
                return
            }
            
            guard let uploadSession = self.uploadSession else {
                let message = "Unable to start upload tasks, session does not exist, it was probably invalidated. This is unexpected"
                let error = NSError(domain: "HealthKitUploader", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
                DDLogError(message)
                self.delegate?.sampleUploader(uploader: self, didCompleteUploadWithError: error, rejectedSamples: nil)
                return
            }

            // Default error message...
            var message: String?

            // Create upload task if there are uploads to do...
            if batchSamplesPostBodyURL != nil {
                do {
                    let request = try TPUploaderServiceAPI.connector!.makeDataUploadRequest("POST")
                    self.setPendingUploadsState(uploadTaskIsPending: true)
                    let uploadTask = uploadSession.uploadTask(with: request, fromFile: batchSamplesPostBodyURL!)
                    uploadTask.taskDescription = self.prefixedLocalId(self.uploadSamplesTaskDescription)
                    DDLogInfo("((self.mode.rawValue)) Created samples upload task: \(uploadTask.taskIdentifier)")
                    uploadTask.resume()
                    return
                } catch {
                    message = "Failed to create upload POST Url!"
                }
            }
            // Otherwise check for deletes...
            else if self.startDeleteTaskInSession(uploadSession) == true {
                // delete task started successfully, just return...
                return
            }
            
            self.setPendingUploadsState(uploadTaskIsPending: false)
            if message != nil {
                let settingsError = NSError(domain: "HealthKitUploader", code: -3, userInfo: [NSLocalizedDescriptionKey: message!])
                DDLogError(message!)
                self.delegate?.sampleUploader(uploader: self, didCompleteUploadWithError: settingsError, rejectedSamples: nil)
            } else {
                // No uploads or deletes found (probably due to filtered bad values)
                self.delegate?.sampleUploader(uploader: self, didCompleteUploadWithError: nil, rejectedSamples: nil)
            }
        }
    }
    
    func startDeleteTaskInSession(_ session: URLSession) -> Bool {
        if let deleteSamplesPostBodyURL = UserDefaults.standard.url(forKey: self.prefixedLocalId(self.deleteSamplesDataUrlKey))
        {
            self.setPendingUploadsState(uploadTaskIsPending: true)
            do {
                let deleteSamplesRequest = try TPUploaderServiceAPI.connector!.makeDataUploadRequest("DELETE")
                self.setPendingUploadsState(uploadTaskIsPending: true)
                let deleteTask = session.uploadTask(with: deleteSamplesRequest, fromFile: deleteSamplesPostBodyURL)
                deleteTask.taskDescription = self.prefixedLocalId(self.deleteSamplesTaskDescription)
                DDLogInfo("(\(self.mode.rawValue)) Created samples delete task: \(deleteTask.taskIdentifier)")
                deleteTask.resume()
                return true
           } catch {
                DDLogError("Failed to create upload DELETE Url!")
            }
        }
        return false
    }
    
    func cancelTasks() {
        DDLogVerbose("mode: \(mode.rawValue)")
        
        if self.uploadSession == nil {
            self.setPendingUploadsState(uploadTaskIsPending: false)
        } else {
            self.uploadSession!.getTasksWithCompletionHandler { (dataTasks, uploadTasks, downloadTasks) -> Void in
                DDLogInfo("(\(self.mode.rawValue)) Canceling \(uploadTasks.count) tasks")
                if uploadTasks.count > 0 {
                    for uploadTask in uploadTasks {
                        DDLogInfo("Canceling task: \(uploadTask.taskIdentifier)")
                        uploadTask.cancel()
                    }
                } else {
                    self.setPendingUploadsState(uploadTaskIsPending: false)
                }
            }
        }
    }
    
    // MARK: URLSessionTaskDelegate
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DDLogVerbose("mode: \(mode.rawValue)")

        let lastUploadPost = lastUploadSamplePostBody
        let lastDeletePost = lastDeleteSamplePostBody
        lastUploadSamplePostBody = nil
        lastDeleteSamplePostBody = nil
        
        var message = ""
        let taskDescr = task.taskDescription ?? ""
        if let error = error {
            message = "Upload task failed: \(taskDescr), with error: \(error), id: \(task.taskIdentifier)"
        } else {
            message = "Upload task completed: \(taskDescr), id: \(task.taskIdentifier)"
        }
        DDLogInfo(message)
        //UIApplication.localNotifyMessage(message)

        var httpError: NSError?
        var rejectedSamples: [Int]?
        if let response = task.response as? HTTPURLResponse {
            if !(200 ... 299 ~= response.statusCode) {
                let message = "HTTP error on upload: \(response.statusCode)"
                var responseMessage: String?
                if let lastData = lastData  {
                    responseMessage = String(data: lastData, encoding: .utf8)
                    if response.statusCode == 400 {
                        do {
                            let json = try JSONSerialization.jsonObject(with: lastData, options: [])
                            if let jsonDict = json as? [String: Any] {
                                rejectedSamples = parseErrResponse(jsonDict)
                            }
                        } catch {
                            DDLogError("Unable to parse response message as dictionary!")
                        }
                    } else if response.statusCode == 401 {
                        // token expired? Notify service connector to handle this!
                        TPUploaderServiceAPI.connector!.receivedAuthErrorOnUpload()
                    }
                }
                DDLogError(message)
                if let responseMessage = responseMessage {
                    DDLogInfo("response message: \(responseMessage)")
                }
                if let postBody = lastUploadPost {
                    if let postBodyJson = String(data: postBody, encoding: .utf8) {
                        DDLogInfo("failed upload samples: \(postBodyJson)")
                    } else {
                        DDLogInfo("failed upload samples: ...")
                    }
                } else if let postBody = lastDeletePost {
                    if let postBodyJson = String(data: postBody, encoding: .utf8) {
                        DDLogInfo("failed delete samples: \(postBodyJson)")
                    } else {
                        DDLogInfo("failed delete samples: ...")
                    }
                }
                httpError = NSError(domain: "HealthKitUploader", code: -2, userInfo: [NSLocalizedDescriptionKey: message])
            }
        }
        
        if let error = error {
            self.setPendingUploadsState(uploadTaskIsPending: false)
            self.delegate?.sampleUploader(uploader: self, didCompleteUploadWithError: error, rejectedSamples: nil)
            return
        }
        
        if httpError != nil {
            self.setPendingUploadsState(uploadTaskIsPending: false)
            self.delegate?.sampleUploader(uploader: self, didCompleteUploadWithError: httpError, rejectedSamples: rejectedSamples)
            return
        }
        
        // Clear upload post body copy since uploads completed successfully...
        self.lastUploadSamplePostBody = nil
        
        // See if there are any deletes to do, and resume task to do them if so
        if task.taskDescription == prefixedLocalId(self.uploadSamplesTaskDescription) {
            if self.startDeleteTaskInSession(session) == true {
                return
            }
        }
        // If we were doing uploads, and there are no deletes to start, or if we just finished deletes, then we are done!
        self.lastDeleteSamplePostBody = nil
        self.setPendingUploadsState(uploadTaskIsPending: false)
        self.delegate?.sampleUploader(uploader: self, didCompleteUploadWithError: nil, rejectedSamples: nil)
    }
    
    private func parseErrResponse(_ response: [String: Any]) -> [Int]? {
        var messageParseError = false
        var rejectedSamples: [Int] = []

        func parseErrorDict(_ errDict: Any) {
            guard let errDict = errDict as? [String: Any] else {
                NSLog("Error message source field is not valid!")
                messageParseError = true
                return
            }
            guard let errStr = errDict["pointer"] as? String else {
                NSLog("Error message source pointer missing or invalid!")
                messageParseError = true
                return
            }
            print("next error is \(errStr)")
            guard errStr.count >= 2 else {
                NSLog("Error message pointer string too short!")
                messageParseError = true
                return
            }
            let parser = Scanner(string: errStr)
            parser.scanLocation = 1
            var index: Int = -1
            guard parser.scanInt(&index) else {
                NSLog("Unable to find index in error message!")
                messageParseError = true
                return
            }
            print("index of next bad sample is: \(index)")
            rejectedSamples.append(index)
        }

        if let errorArray = response["errors"] as? [[String: Any]] {
            for errorDict in errorArray {
                if let source = errorDict["source"] {
                    parseErrorDict(source)
                }
            }
        } else {
            if let source = response["source"] as? [String: Any] {
                parseErrorDict(source)
            }
        }
        
        if !messageParseError && rejectedSamples.count > 0 {
            return rejectedSamples
        } else {
            return nil
        }
    }

    // Retain last upload response data for error message debugging...
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        DDLogVerbose("mode: \(mode.rawValue)")
        lastData = data
    }
    var lastData: Data?
    
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        DDLogVerbose("mode: \(mode.rawValue)")

        DispatchQueue.main.async {
            DDLogInfo("Upload session became invalid. Mode: \(self.mode)")
            self.uploadSession = nil
            self.ensureUploadSession()
        }
    }
    
    // MARK: Private
    
    private func ensureUploadSession() {
        DDLogVerbose("mode: \(mode.rawValue)")
        
        guard self.uploadSession == nil else {
            return
        }
        
        let configuration = URLSessionConfiguration.background(withIdentifier: prefixedLocalId(self.backgroundUploadSessionIdentifier))
        configuration.timeoutIntervalForResource = 60 // 60 seconds
        let newUploadSession = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        newUploadSession.delegateQueue.maxConcurrentOperationCount = 1 // So we can serialize the metadata and samples upload POSTs
        self.uploadSession = newUploadSession

        DDLogInfo("Created upload session. Mode: \(self.mode)")
    }

    private func createBodyFileForBatchSamplesDelete(_ samplesToDeleteDictArray: [[String: AnyObject]]) throws -> (URL?, Data?) {
        DDLogVerbose("mode: \(mode.rawValue)")
        
        // Prepare upload delete body
        var validatedSamples = [[String: AnyObject]]()
        // Prevent serialization exceptions!
        for sample in samplesToDeleteDictArray {
            DDLogInfo("Next sample to delete: \(sample)")
            if JSONSerialization.isValidJSONObject(sample) {
                validatedSamples.append(sample)
            } else {
                DDLogError("Sample cannot be serialized to JSON!")
                DDLogError("Sample: \(sample)")
            }
        }
        if validatedSamples.isEmpty {
            return (nil, nil)
        }
        DDLogVerbose("Count of samples to delete: \(validatedSamples.count)")
        //DDLogInfo("Next samples to delete: \(validatedSamples)")
        return try self.savePostBodyForUpload(samples: validatedSamples, identifier: prefixedKey(prefix: self.mode.rawValue, type: "All", key: "deleteBatchSamples.data"))
    }

    func prefixedKey(prefix: String, type: String, key: String) -> String {
        let result = "\(prefix)-\(type)\(key)"
        //print("prefixedKey: \(result)")
        return result
    }

    private func createBodyFileForBatchSamplesUpload(_ samplesToUploadDictArray: [[String: AnyObject]]) throws -> (URL?, Data?) {
        DDLogVerbose("mode: \(mode.rawValue)")
        
        // Note: exceptions during serialization are NSException type, and won't get caught by a Swift do/catch, so pre-validate!
        return try self.savePostBodyForUpload(samples: samplesToUploadDictArray, identifier: prefixedKey(prefix: self.mode.rawValue, type: "All", key: "uploadBatchSamples.data"))
    }

    private func savePostBodyForUpload(samples: [[String: AnyObject]], identifier: String) throws -> (URL?, Data?) {
        DDLogVerbose("identifier: \(identifier)")
 
        let postBody = try JSONSerialization.data(withJSONObject: samples)
        //print("Post body for upload: \(postBody)")
        let postBodyURL = getUploadURLForIdentifier(with: identifier)
        try postBody.write(to: postBodyURL, options: .atomic)
        return (postBodyURL, postBody)
    }
    
    private func getUploadURLForIdentifier(with identifier: String) -> URL {
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let postBodyURL = cachesDirectory.appendingPathComponent(identifier)
        return postBodyURL
    }
    
    private func setPendingUploadsState(uploadTaskIsPending: Bool) {
        let setting = mode == .Current ? settings.hasPendingCurrentUploads : settings.hasPendingHistoricalUploads
        setting.value = uploadTaskIsPending
    }

    private var uploadSession: URLSession?
    
    // use the following with prefixedLocalId to create ids unique to mode...
    private let backgroundUploadSessionIdentifier = "UploadSessionId"
    private let uploadSamplesTaskDescription = "Upload samples"
    private let deleteSamplesTaskDescription = "Delete samples"
    // nil if no deletes for this type, otherwise the file url for the delete body...
    private let deleteSamplesDataUrlKey = "DeleteSamplesDataUrl"
 
    private func prefixedLocalId(_ key: String) -> String {
        return "\(self.mode.rawValue)-\(key)"
    }

}
