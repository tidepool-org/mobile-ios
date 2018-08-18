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
        DDLogVerbose("type: \(uploadType.typeName), mode: \(mode.rawValue)")
        
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
        DDLogVerbose("type: \(typeString), mode: \(mode.rawValue)")

        // Prepare POST files for upload. Fine to do this on background thread
        // May be nil if no samples to upload
        let batchSamplesPostBody = try createBodyForBatchSamplesUpload(data: data)
        // May be nil if no samples to delete
        let batchSamplesDeleteBodyURL = try createBodyFileForBatchSamplesDelete(data: data)
       
        UserDefaults.standard.set(batchSamplesDeleteBodyURL, forKey: prefixedLocalId(self.deleteSamplesRequestUrlKey))
        if batchSamplesDeleteBodyURL != nil {
            // Store this for later, for delete phase...
            UserDefaults.standard.set(request.url, forKey: prefixedLocalId(self.uploadSamplesRequestUrlKey))
            UserDefaults.standard.set(request.allHTTPHeaderFields, forKey: prefixedLocalId(self.uploadSamplesRequestAllHTTPHeaderFieldsKey))
        }
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

            // Create upload task if there are uploads to do...
            if batchSamplesPostBody != nil {
                self.setPendingUploadsState(uploadTaskIsPending: true)
                let uploadTask = uploadSession!.uploadTask(with: request as URLRequest, from: batchSamplesPostBody!)
                uploadTask.taskDescription = self.prefixedLocalId(self.uploadSamplesTaskDescription)
                DDLogInfo("Created samples upload task: \(uploadTask.taskIdentifier)")
                uploadTask.resume()
            // Otherwise check for deletes...
            } else if !self.startDeleteTaskInSession(uploadSession!) {
                let message = "Failed to find samples to upload or delete!"
                let settingsError = NSError(domain: "HealthKitUploader", code: -3, userInfo: [NSLocalizedDescriptionKey: message])
                DDLogError(message)
                self.setPendingUploadsState(uploadTaskIsPending: false)
                self.delegate?.sampleUploader(uploader: self, didCompleteUploadWithError: settingsError)
            }
        }
    }
    
    func startDeleteTaskInSession(_ session: URLSession) -> Bool {
        if let deleteSamplesPostBodyURL = UserDefaults.standard.url(forKey: self.prefixedLocalId(self.deleteSamplesRequestUrlKey)),
            let deleteTaskRequestAllHTTPHeaderFields = UserDefaults.standard.dictionary(forKey: self.prefixedLocalId(self.uploadSamplesRequestAllHTTPHeaderFieldsKey)),
            let deleteTaskRequestUrl = UserDefaults.standard.url(forKey: self.prefixedLocalId(self.uploadSamplesRequestUrlKey))
        {
            self.setPendingUploadsState(uploadTaskIsPending: true)
            
            let deleteSamplesRequest = NSMutableURLRequest(url: deleteTaskRequestUrl)
            deleteSamplesRequest.httpMethod = "DELETE"
            for (field, value) in deleteTaskRequestAllHTTPHeaderFields {
                deleteSamplesRequest.setValue(value as? String, forHTTPHeaderField: field)
            }
            let deleteTask = session.uploadTask(with: deleteSamplesRequest as URLRequest, fromFile: deleteSamplesPostBodyURL)
            deleteTask.taskDescription = self.prefixedLocalId(self.deleteSamplesTaskDescription)
            DDLogInfo("Created samples delete task: \(deleteTask.taskIdentifier)")
            deleteTask.resume()
            return true
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
                    DDLogInfo("Canceling \(uploadTasks.count) tasks")
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

        var message = ""
        if let error = error {
            message = "Upload task failed: \(task.taskDescription!), with error: \(error), id: \(task.taskIdentifier), type: \(self.typeString)"
        } else {
            message = "Upload task completed: \(task.taskDescription!), id: \(task.taskIdentifier), type: \(self.typeString)"
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
            self.setPendingUploadsState(uploadTaskIsPending: false)
            self.delegate?.sampleUploader(uploader: self, didCompleteUploadWithError: error)
        } else if httpError != nil {
            self.setPendingUploadsState(uploadTaskIsPending: false)
            self.delegate?.sampleUploader(uploader: self, didCompleteUploadWithError: httpError)
        } else if task.taskDescription == prefixedLocalId(self.uploadSamplesTaskDescription) && !self.startDeleteTaskInSession(session) {
            // If we were doing uploads, and there are no deletes to start, we are done!
            self.setPendingUploadsState(uploadTaskIsPending: false)
            self.delegate?.sampleUploader(uploader: self, didCompleteUploadWithError: nil)
        }
    }
    
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
    
    fileprivate func ensureUploadSession(isBackground: Bool) {
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

    fileprivate func createBodyFileForBatchSamplesDelete(data: HealthKitUploadData) throws -> URL? {
        DDLogVerbose("type: \(typeString), mode: \(mode.rawValue)")
        
        // Prepare upload delete body
        let samplesToDeleteDictArray = data.uploadType.prepareDataForDelete(data)
        var validatedSamples = [[String: AnyObject]]()
        // Prevent serialization exceptions!
        for sample in samplesToDeleteDictArray {
            DDLogInfo("Next sample to upload: \(sample)")
            if JSONSerialization.isValidJSONObject(sample) {
                validatedSamples.append(sample)
            } else {
                DDLogError("Sample cannot be serialized to JSON!")
                DDLogError("Sample: \(sample)")
            }
        }
        print("Next samples to delete: \(validatedSamples)")
        if validatedSamples.isEmpty {
            return nil
        }
        let postBody = try JSONSerialization.data(withJSONObject: validatedSamples)
        //print("Post body for upload: \(postBody)")
        return try self.savePostBodyForUpload(body: postBody, identifier: HealthKitSettings.prefixedKey(prefix: "", type: self.typeString, key: "deleteBatchSamples.data"))
    }

    fileprivate func createBodyForBatchSamplesUpload(data: HealthKitUploadData) throws -> Data? {
        DDLogVerbose("type: \(typeString), mode: \(mode.rawValue)")

        // Prepare upload post body
        let samplesToUploadDictArray = data.uploadType.prepareDataForUpload(data)
        var validatedSamples = [[String: AnyObject]]()
        // Prevent serialization exceptions!
        for sample in samplesToUploadDictArray {
            DDLogInfo("Next sample to upload: \(sample)")
            if JSONSerialization.isValidJSONObject(sample) {
                validatedSamples.append(sample)
            } else {
                DDLogError("Sample cannot be serialized to JSON!")
                DDLogError("Sample: \(sample)")
            }
        }
        print("Next samples to upload: \(samplesToUploadDictArray)")
        if validatedSamples.isEmpty {
            return nil
        }
        // Note: exceptions during serialization are NSException type, and won't get caught by a Swift do/catch, so pre-validate!
        let postBody = try JSONSerialization.data(withJSONObject: validatedSamples)
        return postBody
    }
    
    fileprivate func createBodyFileForBatchSamplesUpload(data: HealthKitUploadData) throws -> URL? {
        DDLogVerbose("type: \(typeString), mode: \(mode.rawValue)")
        
        // Prepare upload post body
        let samplesToUploadDictArray = data.uploadType.prepareDataForUpload(data)
        var validatedSamples = [[String: AnyObject]]()
        // Prevent serialization exceptions!
        for sample in samplesToUploadDictArray {
            DDLogInfo("Next sample to upload: \(sample)")
            if JSONSerialization.isValidJSONObject(sample) {
                validatedSamples.append(sample)
            } else {
                DDLogError("Sample cannot be serialized to JSON!")
                DDLogError("Sample: \(sample)")
            }
        }
        print("Next samples to upload: \(samplesToUploadDictArray)")
        if validatedSamples.isEmpty {
            return nil
        }
        // Note: exceptions during serialization are NSException type, and won't get caught by a Swift do/catch, so pre-validate!
        let postBody = try JSONSerialization.data(withJSONObject: validatedSamples)
        //print("Post body for upload: \(postBody)")
        return try self.savePostBodyForUpload(body: postBody, identifier: HealthKitSettings.prefixedKey(prefix: "", type: self.typeString, key: "uploadBatchSamples.data"))
    }

    fileprivate func savePostBodyForUpload(body: Data, identifier: String) throws -> URL {
        DDLogVerbose("identifier: \(identifier)")
        
        let postBodyURL = getUploadURLForIdentifier(with: identifier)
        try body.write(to: postBodyURL, options: .atomic)
        return postBodyURL
    }
    
    fileprivate func getUploadURLForIdentifier(with identifier: String) -> URL {
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let postBodyURL = cachesDirectory.appendingPathComponent(identifier)
        return postBodyURL
    }
    
    fileprivate func setPendingUploadsState(uploadTaskIsPending: Bool) {
        UserDefaults.standard.set(uploadTaskIsPending, forKey: HealthKitSettings.prefixedKey(prefix: self.mode.rawValue, type: self.typeString, key: HealthKitSettings.HasPendingUploadsKey))
        UserDefaults.standard.synchronize()
    }

    fileprivate var foregroundUploadSession: URLSession?
    fileprivate var backgroundUploadSession: URLSession?
    
    // use the following with prefixedLocalId to create ids unique to mode and upload type...
    fileprivate let backgroundUploadSessionIdentifier = "uploadSessionId"
    fileprivate let uploadSamplesTaskDescription = "upload samples"
    fileprivate let deleteSamplesTaskDescription = "delete samples"

    fileprivate let uploadSamplesRequestUrlKey = "uploadSamplesRequestUrl"
    fileprivate let deleteSamplesRequestUrlKey = "deleteSamplesRequestUrl"
    fileprivate let uploadSamplesRequestAllHTTPHeaderFieldsKey = "uploadSamplesRequestAllHTTPHeaderFields"

    fileprivate func prefixedLocalId(_ key: String) -> String {
        return "\(self.mode)-\(self.typeString)\(key)"
    }

}
