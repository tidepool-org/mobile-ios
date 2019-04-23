/*
 * Copyright (c) 2019, Tidepool Project
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

import Foundation

class TPTimeZoneTracker {
    
    static var tracker: TPTimeZoneTracker?
    init() {
        TPTimeZoneTracker.tracker = self
        // first check for implicit tz changes, then register for changes...
        self.postTimezoneEventChanges(){}
        NotificationCenter.default.addObserver(self, selector: #selector(TPTimeZoneTracker.timezoneDidChange(_:)), name:Notification.Name.NSSystemTimeZoneDidChange, object: nil)

    }

    @objc internal func timezoneDidChange(_ notification: Notification) {
        DispatchQueue.main.async {
            DDLogInfo("\(#function)")
            // first, log timezone change to data controller...
            self.tzDidChange(notification)
            self.postTimezoneEventChanges() {}
        }
    }
    
    //
    // MARK: - Timezone change tracking, public interface
    //
    
    /// Call to check for implicit timezone changes
    private func checkForTimezoneChange() {
        NSLog("\(#function)")
        let currentTimeZoneId = TimeZone.current.identifier
        let lastTimezoneId = lastStoredTzId()
        if currentTimeZoneId != lastTimezoneId {
            DDLogInfo("Detected timezone change from: \(lastTimezoneId) to: \(currentTimeZoneId)")
            self.addNewTimezoneChangeAtTime(Date(), newTimezoneId: currentTimeZoneId, previousTimezoneId: lastTimezoneId)
        } else {
            NSLog("\(#function): no tz change detected!")
        }
    }
    
    /// Pass along any timezone change notifications. Note: this could simply call the checkForTimeZoneChange method above, except that this notification gives us the previous timezone as well, which may not have been saved.
    func tzDidChange(_ notification : Notification) {
        NSLog("\(#function)")

        let newTimeZoneId = TimeZone.current.identifier
        if newTimeZoneId == lastStoredTzId() {
            DDLogError("TZ change notification when TZ has not changed: \(newTimeZoneId)")
            return
        }
        DDLogInfo("Changed to timezone id: \(newTimeZoneId)")
        let previousTimeZone = notification.object as? TimeZone
        var previousTimezoneId: String?
        if previousTimeZone != nil {
            previousTimezoneId = previousTimeZone!.identifier
            DDLogInfo("Changed from timezone id: \(previousTimezoneId!)")
            if previousTimezoneId == newTimeZoneId {
                DDLogInfo("Ignoring notification of change to same timezone!")
                return
            }
        }
        self.addNewTimezoneChangeAtTime(Date(), newTimezoneId: newTimeZoneId, previousTimezoneId: previousTimezoneId)
        
    }
    
    /// Recursively posts any pending timezone change events to service.
    /// Only call in main, in foreground.
    func postTimezoneEventChanges(_ completion: @escaping () -> (Void)) {
        NSLog("\(#function)")
        checkForTimezoneChange()
        if changesUploading {
            DDLogInfo("already uploading changes")
            completion()
        } else {
            let changes = storedTimezoneChanges()
            let changeCount = changes.count
            if changeCount > 0 {
                changesUploading = true
                TPUploaderServiceAPI.connector?.postTimezoneChangesEvent(changes) {
                    lastTzUploaded in
                    if lastTzUploaded != nil {
                        self.removeStoredTimezoneChanges(changeCount)
                        // persist last timezone uploaded successfully
                        self.lastUploadedTimezoneId = lastTzUploaded
                        self.changesUploading = false
                        // call recursively until all timezone changes have posted...
                        self.postTimezoneEventChanges(completion)
                    } else {
                        self.changesUploading = false
                        completion()
                    }
                }
            } else {
                completion()
            }
        }
    }
    
    /// Clear out timezone cache if current HK user changes
    func clearTzCache() {
        self.pendingChanges = []
        self.lastUploadedTimezoneId = nil
    }
    
    //
    // MARK: - Timezone change private...
    //
    
    // Set true when attempting to upload to service, so only one thread attempts this until it succeeds or fails
    private var changesUploading: Bool = false
    
    //
    private func storedTimezoneChanges() -> [(time: String, newTzId: String, oldTzId: String?)] {
        NSLog("\(#function)")
        return self.pendingChanges
    }
    
    // Remove the oldest changeCount changes, presumably because they were successfully uploaded; set changesUploading false after this (should be true when this is called!)
    private func removeStoredTimezoneChanges(_ changeCount: Int) {
        NSLog("\(#function)")
        if !changesUploading {
            DDLogError("Should not be called when changesUploading flag has not been set!")
            return
        }
        var changesToRemove = changeCount
        while changesToRemove > 0 {
            let e = self.pendingChanges.remove(at: 0)
            DDLogInfo("Removed tz change entry: \(e.time), \(e.newTzId), \(e.oldTzId ?? "")")
            changesToRemove -= 1
        }
    }
    
    /// Last timezone id that we uploaded... might be nil if we never posted.
    private var lastUploadedTimezoneId: String? {
        set(newValue) {
            if _lastUploadedTimezoneId != newValue {
                UserDefaults.standard.set(newValue, forKey: kLastUploadedTimezoneIdSettingKey)
                _lastUploadedTimezoneId = newValue
            }
        }
        get {
            if _lastUploadedTimezoneId == nil {
                _lastUploadedTimezoneId = UserDefaults.standard.string(forKey: kLastUploadedTimezoneIdSettingKey)
            }
            return _lastUploadedTimezoneId
        }
    }
    private let kLastUploadedTimezoneIdSettingKey = "kLastUploadedTimezoneId"
    private var _lastUploadedTimezoneId: String?
    
    //TODO: persist timezone changes that are not uploaded.
    private var pendingChanges = [(time: String, newTzId: String, oldTzId: String?)]()
    
    private func addNewTimezoneChangeAtTime(_ timeNoticed: Date, newTimezoneId: String, previousTimezoneId: String?) {
        DDLogInfo("\(#function) added new timezone change event, to: \(newTimezoneId), from: \(previousTimezoneId ?? "")")
        let dateFormatter = DateFormatter()
        let timeString = dateFormatter.isoStringFromDate(timeNoticed, zone: TimeZone(secondsFromGMT: 0), dateFormat: iso8601dateZuluTime)
        self.pendingChanges.append((time: timeString, newTzId: newTimezoneId, oldTzId: previousTimezoneId))
    }
    
    // Last timezone change we stored or uploaded. Used to check to see if we have a new timezone or not...
    private func lastStoredTzId() -> String {
        if let lastChange = pendingChanges.last {
            return lastChange.newTzId
        } else if let lastTzId = lastUploadedTimezoneId {
            return lastTzId
        } else {
            // we've never uploaded a timezone change, and don't have a current one. Seed our cache with a nil to current entry.
            let result = TimeZone.current.identifier
            addNewTimezoneChangeAtTime(Date(), newTimezoneId: result, previousTimezoneId: nil)
            return result
        }
    }

}
