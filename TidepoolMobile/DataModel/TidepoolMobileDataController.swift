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


import UIKit
import CoreData
import Alamofire
import SwiftyJSON
import HealthKit
import CocoaLumberjack

/// Provides NSManagedObjectContext's for local and tidepool data stored locally. Manages the persistent object representing the current user.
///
/// Notes:
///
/// The interface supports different storage contexts for user, nut event, and tidepool objects. Privately, two datastores are used, one for the local editable data (User, Meal, and Workout objects), and one for the read-only Tidepool data (Basal, Bolus, ContinuousGlucose, Wizard, and SelfMonitoringGlucose).
///
/// The local data store is allocated when the application starts, if not already allocated, and never deleted. Meal and Workout events in this store are tagged with the service userId string; queries against this database for these events always include the userid as a match criteria.
///
/// The Tidepool data store is only allocated at login, and is deleted at logout. It is named so it won't be backed up to iCloud if the user has application backup to cloud configured.
class TidepoolMobileDataController: NSObject
{
    /// Supports a singleton controller for the application.
    static let sharedInstance = TidepoolMobileDataController()
    private let defaults = UserDefaults.standard
    
    // MARK: - Constants
    
    fileprivate let kLocalObjectsStoreFilename = "SingleViewCoreData.sqlite"
    // Appending .nosync should prevent this file from being backed to the cloud
    fileprivate let kTidepoolObjectsStoreFilename = "TidepoolObjects.sqlite.nosync"
    fileprivate let kTestFilePrefix = "Test-"
    
    /// Coordinator/store for current userId, token, etc. Should always be available.
    func mocForCurrentUser() -> NSManagedObjectContext {
        return self.mocForLocalObjects!
    }

    /// Coordinator/store for editable data: Hashtags, User.
    ///
    /// This is only available if there is a current user logged in!
    func mocForLocalEvents() -> NSManagedObjectContext? {
        if currentUserId != nil {
            return self.mocForLocalObjects
        }
        return nil;
    }

    /// Coordinator/store for read-only Tidepool data
    ///
    /// This is only available if there is a current user logged in!
    func mocForTidepoolEvents() -> NSManagedObjectContext? {
        if currentUserId != nil {
            return self.mocForTidepoolObjects
        }
        return nil;
    }
    
    fileprivate var _currentUserId: String?
    /// Service userid for the currently logged in account, or nil. 
    /// 
    /// Read only - set indirectly via loginUser/logoutUser calls. Needed to tag nut events in database.
    ///
    /// Note: Since the data model stores the current user, uses the current userId for tagging some data objects, and switches the tidepool object store based on current user, manage it centrally here.
    var currentUserId: String? {
        get {
            return _currentUserId
        }
    }
        
    /// Used mainly for display, this is the login name for the currently logged in user, or nil.
    ///
    /// Read only - returns nil string if no user set.
    ///
    /// NOTE: startup reference from app delegate has side effect of setting currentUserId!
    var currentUserName: String {
        get {
            if let user = self.currentUser {
                if let name = user.username {
                    return name
                }
            }
            return ""
        }
    }
    
    /// Used for filling out a health data upload request...
    ///
    /// Read only - returns nil string if no user or uploadId is available.
    var currentUploadId: String? {
        get {
            if let user = self.currentUser {
                if let uploadId = user.uploadId {
                    return uploadId
                } else if let uploadId = defaults.string(forKey: HealthKitSettings.HKDataUploadIdKey) {
                    // restore from persisted value if possible!
                    user.uploadId = uploadId
                    return uploadId
                }
            }
            return nil
        }
        set {
            defaults.setValue(newValue, forKey: HealthKitSettings.HKDataUploadIdKey)
            if let user = self.currentUser {
                user.uploadId = newValue
            }
        }
    }

    /// Used for filling out an email for the user to send to themselves; from the current user login, or nil.
    ///
    /// Read only - returns nil string if no user set.
    var currentLoggedInUserEmail: String? {
        get {
            if let user = self.currentUser {
                if let email = user.email {
                    return email
                }
            }
            return nil
        }
    }

    /// Return current logged in user as a BlipUser object. Alternately, just reference currentUserName, currentUserId, etc.
    var currentLoggedInUser: BlipUser? {
        get {
            if _currentLoggedInUser == nil {
                if let user = self.currentUser {
                    _currentLoggedInUser = BlipUser(user: user)
                }
            }
            return _currentLoggedInUser
        }
    }
    fileprivate var _currentLoggedInUser: BlipUser?
    
    /// This determines the set of tidepool data and the notes we are viewing. Defaults to the current logged in user. Cannot set to nil! Setting will delete any cached tidepool data, and reconfigure the healthkit interface!
    var currentViewedUser: BlipUser? {
        get {
            if _currentViewedUser == nil {
                if let user = self.currentLoggedInUser {
                    DDLogInfo("Current viewable user is \(String(describing: _currentViewedUser?.fullName))")
                    _currentViewedUser = user
                    loadUserSettings()
                }
            }
            return _currentViewedUser
        }
        set(newUser) {
            _currentViewedUser = newUser
            DDLogInfo("Current viewable user changed to \(String(describing: _currentViewedUser!.fullName))")
            self.deleteAnyTidepoolData()
            self.saveCurrentViewedUserId()
            configureHealthKitInterface()
            loadUserSettings()
        }
    }
    fileprivate var _currentViewedUser: BlipUser?

    fileprivate func loadUserSettings() {
        
        if let settingsUser = _currentViewedUser {
            // only fetch if we haven't yet...
            if settingsUser.bgTargetLow == nil && settingsUser.bgTargetHigh == nil {
                APIConnector.connector().fetchUserSettings(settingsUser.userid) { (result:Alamofire.Result<JSON>) -> (Void) in
                    DDLogInfo("Settings fetch result: \(result)")
                    if (result.isSuccess) {
                        if let json = result.value {
                            settingsUser.processSettingsJSON(json)
                        }
                    }
                    // ignore settings fetch failure, not all users have settings, and this is just used for graph coloring.
                }
            }
        }
    }

    /// Call this at login/logout, token refresh(?), and upon enabling or disabling the HealthKit interface.
    func configureHealthKitInterface() {
        appHealthKitConfiguration.configureHealthKitInterface(self.currentUserId, isDSAUser: self.isDSAUser)
    }
    
    /// Call this after logging into a service account to set up the current user and configure the data model for the user.
    ///
    /// - parameter newUser:
    ///   The User object newly created from service login response.
    func loginUser(_ newUser: User) {
        self.deleteAnyTidepoolData()
        self.currentUser = newUser
        _currentUserId = newUser.userid
        _currentLoggedInUser = nil
        _currentViewedUser = nil
        self.configureHealthKitInterface()
    }

    /// Call this after logging out of the service to deconfigure the data model and clear the persisted user. Only the Meal and Workout events should remain persisted after this.
    func logoutUser() {
        self.deleteAnyTidepoolData()
        self.deleteSavedCurrentViewedUserId()
        self.currentUploadId = nil
        self.currentUser = nil
        _currentUserId = nil
        _currentLoggedInUser = nil
        _currentViewedUser = nil
        configureHealthKitInterface()
    }

    func processLoginProfileFetch(_ json: JSON) {
        if let user = self.currentUser {
            user.processProfileJSON(json)
            _ = DatabaseUtils.databaseSave(user.managedObjectContext!)
            _currentLoggedInUser = nil  // update currentLoggedInUser too...
            _currentViewedUser = nil  // and current viewable user as well
            // reconfigure after profile fetch because we know isDSAUser now!
            configureHealthKitInterface()
        }
    }
    
    /// Update user biological sex. Once persisted here, we should no longer try updating it on service...
    func updateUserBiologicalSex(_ biologicalSex: String) {
        if let user = currentLoggedInUser {
            user.biologicalSex = biologicalSex
        }
        if let user = currentUser {
            user.updateBiologicalSex(biologicalSex)
        }
    }
    
    /// Courtesy call from the AppDelegate for any last minute save, probably not necessary.
    func appWillTerminate() {
        self.saveContext()
    }

    /// 
    var userFullName: String? {
        get {
            return currentUser?.fullName ?? ""
        }
    }
    
    /// This is set after user profile fetch is complete upon log-in. When non-nil, it indicates whether the current user logged in is associated with a Data Storage Account
    var isDSAUser: Bool? {
        get {
            var result: Bool?
            if let isDSA = currentLoggedInUser?.isDSAUser {
                result = Bool(isDSA)
            }
            return result
        }
    }

    //
    // MARK: - Save/restore/delete current profile id
    //
    let kSavedCurrentViewerIdKey = "CurrentViewerIdKey"
    func saveCurrentViewedUserId() {
        if let user = self.currentViewedUser {
            let id = user.userid
            defaults.setValue(id, forKey: kSavedCurrentViewerIdKey)
        }
    }
    
    func deleteSavedCurrentViewedUserId() {
        defaults.removeObject(forKey: kSavedCurrentViewerIdKey)
    }
    
    func checkRestoreCurrentViewedUser(_ completion: @escaping () -> (Void)) {
        if let userId = defaults.string(forKey: kSavedCurrentViewerIdKey) {
            if let loggedInUserId = currentLoggedInUser?.userid {
                if userId != loggedInUserId {
                    APIConnector.connector().fetchProfile(userId) { (result:Alamofire.Result<JSON>) -> (Void) in
                        DDLogInfo("checkRestoreCurrentViewedUser profile fetch result: \(result)")
                        if (result.isSuccess) {
                            if let json = result.value {
                                let user = BlipUser(userid: userId)
                                user.processProfileJSON(json)
                                self.currentViewedUser = user
                            }
                        }
                        completion()
                    }
                    return
                }
            }
        }
        completion()
    }
    
    //
    // MARK: - HealthKit user info
    //

    /// Enables HealthKit for current viewable user
    ///
    /// Note: This sets the current tidepool user as the HealthKit user!
    func enableHealthKitInterface() {
        DDLogInfo("trace")
        appHealthKitConfiguration.enableHealthKitInterface(currentUserName, userid: currentUserId, isDSAUser: isDSAUser, needsUploaderReads: true, needsGlucoseWrites: false)
    }
    
    /// Disables HealthKit for current user
    ///
    /// Note: This does not NOT clear the current HealthKit user!
    func disableHealthKitInterface() {
        DDLogInfo("trace")
        appHealthKitConfiguration.disableHealthKitInterface()
        // clear uploadId to be safe... also for logout.
        self.currentUploadId = nil
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
    func timezoneDidChange(_ notification : NSNotification) {
        NSLog("\(#function)")
        //TODO: only store if new tz is different from last seen?
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
                APIConnector.connector().postTimezoneChangesEvent(changes) {
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
                defaults.set(newValue, forKey: kLastUploadedTimezoneIdSettingKey)
                _lastUploadedTimezoneId = newValue
            }
        }
        get {
            if _lastUploadedTimezoneId == nil {
                _lastUploadedTimezoneId = defaults.string(forKey: kLastUploadedTimezoneIdSettingKey)
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

    //
    // MARK: - Private
    //

    fileprivate var runningUnitTests: Bool
    // no instances allowed..
    override fileprivate init() {
        self.runningUnitTests = false
        if let _ = NSClassFromString("XCTest") {
            self.runningUnitTests = true
            DDLogInfo("Detected running unit tests!")
        }
    }

    fileprivate var _currentUser: User?
    fileprivate var currentUser: User? {
        get {
            if _currentUser == nil {
                if let user = self.getUser() {
                    _currentUser = user
                    _currentUserId = user.userid
                }
            }
            return _currentUser
        }
        set(newUser) {
            if newUser != _currentUser {
                self.updateUser(_currentUser, newUser: newUser)
                _currentUser = newUser
                _currentLoggedInUser = nil
                _currentViewedUser = nil
                if newUser != nil {
                    _currentUserId = newUser!.userid
                    DDLogInfo("Set currentUser, name: \(String(describing: newUser!.username)), id: \(String(describing: newUser!.userid))")
                } else {
                    DDLogInfo("Cleared currentUser!")
                    _currentUserId = nil
                }
            }
        }
    }

    fileprivate var _managedObjectModel: NSManagedObjectModel?
    fileprivate var managedObjectModel: NSManagedObjectModel {
        get {
            if _managedObjectModel == nil {
                // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
                let modelURL = Bundle.main.url(forResource: "TidepoolMobile", withExtension: "momd")!
                _managedObjectModel = NSManagedObjectModel(contentsOf: modelURL)!
            }
            return _managedObjectModel!
        }
        set {
            _managedObjectModel = nil
        }
    }
    
    lazy var applicationDocumentsDirectory: URL = {
        // The directory the application uses to store the Core Data store file. This code uses a directory named "org.tidepool.TidepoolMobile" in the application's documents Application Support directory.
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return urls[urls.count-1]
    }()

    fileprivate var _pscForLocalObjects: NSPersistentStoreCoordinator?
    fileprivate var pscForLocalObjects: NSPersistentStoreCoordinator? {
        get {
            if _pscForLocalObjects == nil {
                do {
                    try _pscForLocalObjects = createPSC(kLocalObjectsStoreFilename)
                } catch {
                    // May have a corrupted database, delete it here so user doesn't have to delete the app in order to recover. Worst case for local data is forcing the user to have to login again.
                    do {
                        DDLogError("CRASHED OPENING LOCAL OBJECTS DB: DELETING AND RETRYING")
                        deleteLocalObjectData()
                        try _pscForLocalObjects = createPSC(kLocalObjectsStoreFilename)
                    } catch {
                        DDLogError("CRASHED SECOND TIME OPENING LOCAL OBJECTS DB!")
                        // give up after second time...
                        _pscForLocalObjects = nil
                    }
                }
            }
            return _pscForLocalObjects
        }
    }

    fileprivate var _pscForTidepoolObjects: NSPersistentStoreCoordinator?
    fileprivate var pscForTidepoolObjects: NSPersistentStoreCoordinator? {
        get {
            if _pscForTidepoolObjects == nil {
                do {
                    try _pscForTidepoolObjects = createPSC(kTidepoolObjectsStoreFilename)
                } catch {
                    // May have a corrupted database, delete it here so user doesn't have to delete the app in order to recover. Worst case is cached tidepool data will need to be refetched!
                    do {
                        DDLogError("CRASHED OPENING TIDEPOOL OBJECTS DB: DELETING AND RETRYING")
                        deleteAnyTidepoolData()
                        try _pscForTidepoolObjects = createPSC(kTidepoolObjectsStoreFilename)
                    } catch {
                        // give up after second time...
                        DDLogError("CRASHED SECOND TIME OPENING TIDEPOOL OBJECTS DB!")
                       _pscForTidepoolObjects = nil
                    }
                }
            }
            return _pscForTidepoolObjects
        }
    }
    
    fileprivate func filenameAdjustedForTest(_ filename: String) -> String {
        if self.runningUnitTests {
            // NOTE: if we are running unit tests, the store objects will be incompatible!
            return kTestFilePrefix + filename
        } else {
            return filename
        }
    }
    
    fileprivate func createPSC(_ storeBaseFileName: String) throws -> NSPersistentStoreCoordinator  {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        var url = applicationDocumentsDirectory
        url = url.appendingPathComponent(filenameAdjustedForTest(storeBaseFileName))
        let pscOptions = [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true]
        do {
            DDLogInfo("Store url is \(url)")
            // TODO: use NSInMemoryStoreType for test databases!
            try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: pscOptions)
        } catch {
            // Report any error we got.
            throw(error)
        }
        return coordinator
    }

    fileprivate var _mocForLocalObjects: NSManagedObjectContext?
    fileprivate var mocForLocalObjects: NSManagedObjectContext? {
        get {
            if _mocForLocalObjects == nil {
                let coordinator = self.pscForLocalObjects
                let managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
                managedObjectContext.persistentStoreCoordinator = coordinator
                _mocForLocalObjects = managedObjectContext
                
            }
            return _mocForLocalObjects!
        }
    }
    
    fileprivate var _mocForTidepoolObjects: NSManagedObjectContext?
    fileprivate var mocForTidepoolObjects: NSManagedObjectContext? {
        get {
            if _mocForTidepoolObjects == nil {
                let coordinator = self.pscForTidepoolObjects
                let managedObjectContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
                managedObjectContext.persistentStoreCoordinator = coordinator
                _mocForTidepoolObjects = managedObjectContext
            }
            return _mocForTidepoolObjects!
        }
    }
    
    fileprivate func saveContext() {
        if let mocForLocalObjects = mocForLocalObjects {
            self.saveContextIfChanged(mocForLocalObjects)
        }
        if let mocForTidepoolObjects = mocForTidepoolObjects {
            self.saveContextIfChanged(mocForTidepoolObjects)
        }
    }

    fileprivate func saveContextIfChanged(_ moc: NSManagedObjectContext) {
        if moc.hasChanges {
            do {
                try moc.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                DDLogError("Unresolved error \(nserror), \(nserror.userInfo)")
                abort()
            }
        }
    }
    
    //
    // MARK: - Manage current user
    //

    fileprivate func getUser() -> User? {
        let moc = self.mocForCurrentUser()
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "User")
        do {
            if let results = try moc.fetch(request) as? [User] {
                if results.count > 0 {
                    return results[0]
                }
            }
        } catch let error as NSError {
            DDLogInfo("Error getting user: \(error)")
        }
        return nil
    }
    
    fileprivate func updateUser(_ currentUser: User?, newUser: User?) {
        let moc = self.mocForCurrentUser()
        // Remove existing user if passed in
        if let currentUser = currentUser {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: "User")
            request.predicate = NSPredicate(format: "userid==%@", currentUser.userid!)
            do {
                let results = try moc.fetch(request) as? [User]
                if results != nil {
                    for result in results! {
                        moc.delete(result)
                    }
                }
            } catch let error as NSError {
                DDLogError("Failed to remove existing user: \(currentUser.userid!)) error: \(error)")
            }
        }
        
        if let newUser = newUser {
            moc.insert(newUser)
        }
        
        // Save the database
        do {
            try moc.save()
        } catch let error as NSError {
            print("Failed to save MOC for user: \(error)")
        }
    }

    /// Resets the tidepool object database by deleting the underlying file!
    fileprivate func deleteLocalObjectData() {
        // Delete the underlying file
        // First nil out locals so a new psc and moc will be created on demand
        _pscForLocalObjects = nil
        _mocForLocalObjects = nil
        deleteDatabase(kLocalObjectsStoreFilename)
    }

    /// Resets the tidepool object database by deleting the underlying file!
    fileprivate func deleteAnyTidepoolData() {
        // Delete the underlying file
        // First nil out locals so a new psc and moc will be created on demand
        _pscForTidepoolObjects = nil
        _mocForTidepoolObjects = nil
        DatabaseUtils.sharedInstance.resetTidepoolEventLoader() // reset cache as well!
        deleteDatabase(kTidepoolObjectsStoreFilename)
    }
    
    fileprivate func deleteDatabase(_ docsDirDBName: String) {
        // Delete the underlying file
        var url = self.applicationDocumentsDirectory
        url = url.appendingPathComponent(filenameAdjustedForTest(docsDirDBName))
        var error: NSError?
        let fileExists = (url as NSURL).checkResourceIsReachableAndReturnError(&error)
        if (fileExists) {
            let fm = FileManager.default
            do {
                try fm.removeItem(at: url)
                DDLogInfo("Deleted database at \(url)")
            } catch let error as NSError {
                DDLogError("Failed to delete \(url), error: \(error)")
            }
        }
    }


}
