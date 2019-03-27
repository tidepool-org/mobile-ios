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
    func sampleUploader(uploader: HealthKitUploader, didCompleteUploadWithError error: Error?)
}

// TODO: uploader - we should avoid using file based POSTs when in foreground (probably faster!? and simpler)

class HealthKitUploader: NSObject, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate {
    init(mode: TPUploader.Mode, uploadType: HealthKitUploadType) {
        DDLogVerbose("type: \(uploadType.typeName), mode: \(mode.rawValue)")
        
        self.mode = mode
        self.typeString = uploadType.typeName
        self.uploaderSettings = UploaderSettings(mode: mode, type: uploadType)
        
        super.init()

        self.ensureUploadSession(isBackground: false)
        self.ensureUploadSession(isBackground: true)
    }

    private(set) var mode: TPUploader.Mode
    private(set) var typeString: String
    weak var delegate: HealthKitSampleUploaderDelegate?
    private let uploaderSettings: UploaderSettings
    
    func hasPendingUploadTasks() -> Bool {
        return uploaderSettings.boolForKey(.hasPendingUploadsKey)
    }
    
    private var lastUploadSamplePostBody: Data?
    private var lastDeleteSamplePostBody: Data?

    // NOTE: This is called from a query results handler, not on main thread
    func startUploadSessionTasks(with data: HealthKitUploadData) throws {
        DDLogVerbose("type: \(typeString), mode: \(mode.rawValue)")
        
        // Prepare POST files for upload. Fine to do this on background thread (Upload tasks from NSData are not supported in background sessions, so this has to come from a file, at least if we are in the background).
        // May be nil if no samples to upload
        let (batchSamplesPostBodyURL, samplePostBody) = try createBodyFileForBatchSamplesUpload(data: data)
        lastUploadSamplePostBody = samplePostBody
        
        // May be nil if no samples to delete
        let (batchSamplesDeleteBodyURL, deletePostBody) = try createBodyFileForBatchSamplesDelete(data: data)
        lastDeleteSamplePostBody = deletePostBody
        UserDefaults.standard.set(batchSamplesDeleteBodyURL, forKey: prefixedLocalId(self.deleteSamplesDataUrlKey))
        
        DispatchQueue.main.async {
            DDLogInfo("(\(self.typeString), mode: \(self.mode.rawValue)) [main]")
            
            // Choose the right session to start tasks with
            var uploadSession: URLSession?
            if UIApplication.shared.applicationState == UIApplication.State.background {
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

            // Default error message...
            var message: String?

            // Create upload task if there are uploads to do...
            if batchSamplesPostBodyURL != nil {
                do {
                    let request = try TPUploaderServiceAPI.connector!.makeDataUploadRequest("POST")
                    self.setPendingUploadsState(uploadTaskIsPending: true)
                    let uploadTask = uploadSession!.uploadTask(with: request, fromFile: batchSamplesPostBodyURL!)
                    uploadTask.taskDescription = self.prefixedLocalId(self.uploadSamplesTaskDescription)
                    DDLogInfo("(\(self.typeString), \(self.mode.rawValue)) Created samples upload task: \(uploadTask.taskIdentifier)")
                    uploadTask.resume()
                    return
                } catch {
                    message = "Failed to create upload POST Url!"
                }
            }
            // Otherwise check for deletes...
            else if self.startDeleteTaskInSession(uploadSession!) == true {
                // delete task started successfully, just return...
                return
            }
            
            self.setPendingUploadsState(uploadTaskIsPending: false)
            if message != nil {
                let settingsError = NSError(domain: "HealthKitUploader", code: -3, userInfo: [NSLocalizedDescriptionKey: message!])
                DDLogError(message!)
                self.delegate?.sampleUploader(uploader: self, didCompleteUploadWithError: settingsError)
            } else {
                // No uploads or deletes found (probably due to filtered bad values)
                self.delegate?.sampleUploader(uploader: self, didCompleteUploadWithError: nil)
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
                DDLogInfo("(type: \(self.typeString), \(self.mode.rawValue)) Created samples delete task: \(deleteTask.taskIdentifier)")
                deleteTask.resume()
                return true
           } catch {
                DDLogError("Failed to create upload DELETE Url!")
            }
        }
        return false
    }
    
    func cancelTasks() {
        DDLogVerbose("type: \(typeString), mode: \(mode.rawValue)")
        
        if self.backgroundUploadSession == nil && self.foregroundUploadSession == nil {
            self.setPendingUploadsState(uploadTaskIsPending: false)
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
                    DDLogInfo("(\(self.typeString), \(self.mode.rawValue)) Canceling \(uploadTasks.count) tasks")
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
    }
    
    // MARK: URLSessionTaskDelegate
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DDLogVerbose("type: \(typeString), mode: \(mode.rawValue)")

        let lastUploadPost = lastUploadSamplePostBody
        let lastDeletePost = lastDeleteSamplePostBody
        lastUploadSamplePostBody = nil
        lastDeleteSamplePostBody = nil
        
        var message = ""
        let taskDescr = task.taskDescription ?? ""
        if let error = error {
            message = "Upload task failed: \(taskDescr), with error: \(error), id: \(task.taskIdentifier), type: \(self.typeString)"
        } else {
            message = "Upload task completed: \(taskDescr), id: \(task.taskIdentifier), type: \(self.typeString)"
        }
        DDLogInfo(message)
        //UIApplication.localNotifyMessage(message)

        var httpError: NSError?
        if let response = task.response as? HTTPURLResponse {
            if !(200 ... 299 ~= response.statusCode) {
                let message = "HTTP error on upload: \(response.statusCode)"
                var responseMessage: String?
                if let lastData = lastData  {
                    responseMessage = String(data: lastData, encoding: .utf8)
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
            self.delegate?.sampleUploader(uploader: self, didCompleteUploadWithError: error)
            return
        }
        
        if httpError != nil {
            self.setPendingUploadsState(uploadTaskIsPending: false)
            self.delegate?.sampleUploader(uploader: self, didCompleteUploadWithError: httpError)
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
        self.delegate?.sampleUploader(uploader: self, didCompleteUploadWithError: nil)
    }
    
    // Retain last upload response data for error message debugging...
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        DDLogVerbose("type: \(typeString), mode: \(mode.rawValue)")
        lastData = data
    }
    var lastData: Data?
    
    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        DDLogVerbose("type: \(typeString), mode: \(mode.rawValue)")

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
    
    private func ensureUploadSession(isBackground: Bool) {
        DDLogVerbose("type: \(typeString), mode: \(mode.rawValue)")
        
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

    private func createBodyFileForBatchSamplesDelete(data: HealthKitUploadData) throws -> (URL?, Data?) {
        DDLogVerbose("type: \(typeString), mode: \(mode.rawValue)")
        
        // Prepare upload delete body
        let samplesToDeleteDictArray = data.uploadType.prepareDataForDelete(data)
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
        return try self.savePostBodyForUpload(samples: validatedSamples, identifier: prefixedKey(prefix: "", type: self.typeString, key: "deleteBatchSamples.data"))
    }

    func prefixedKey(prefix: String, type: String, key: String) -> String {
        let result = "\(prefix)-\(type)\(key)"
        //print("prefixedKey: \(result)")
        return result
    }

    private func createBodyFileForBatchSamplesUpload(data: HealthKitUploadData) throws -> (URL?, Data?) {
        DDLogVerbose("type: \(typeString), mode: \(mode.rawValue)")
        
        // Prepare upload post body
        let samplesToUploadDictArray = data.uploadType.prepareDataForUpload(data)
        var validatedSamples = [[String: AnyObject]]()
        // Prevent serialization exceptions!
        for sample in samplesToUploadDictArray {
            //DDLogInfo("Next sample to upload: \(sample)")
            if JSONSerialization.isValidJSONObject(sample) {
                validatedSamples.append(sample)
            } else {
                DDLogError("Sample cannot be serialized to JSON!")
                DDLogError("Sample: \(sample)")
            }
        }
        //print("Next samples to upload: \(samplesToUploadDictArray)")
        if validatedSamples.isEmpty {
            return (nil, nil)
        }
        DDLogVerbose("Count of samples to upload: \(validatedSamples.count)")
        // Note: exceptions during serialization are NSException type, and won't get caught by a Swift do/catch, so pre-validate!
        return try self.savePostBodyForUpload(samples: validatedSamples, identifier: prefixedKey(prefix: "", type: self.typeString, key: "uploadBatchSamples.data"))
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
        uploaderSettings.updateBoolSettingForKey(.hasPendingUploadsKey, value: uploadTaskIsPending)
    }

    private var foregroundUploadSession: URLSession?
    private var backgroundUploadSession: URLSession?
    
    // use the following with prefixedLocalId to create ids unique to mode and upload type...
    private let backgroundUploadSessionIdentifier = "UploadSessionId"
    private let uploadSamplesTaskDescription = "Upload samples"
    private let deleteSamplesTaskDescription = "Delete samples"
    // nil if no deletes for this type, otherwise the file url for the delete body...
    private let deleteSamplesDataUrlKey = "DeleteSamplesDataUrl"
 
    private func prefixedLocalId(_ key: String) -> String {
        return "\(self.mode)-\(self.typeString)\(key)"
    }

}
