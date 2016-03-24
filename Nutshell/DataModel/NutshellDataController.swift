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
class NutDataController: NSObject
{

    // MARK: - Constants
    
    private let kLocalObjectsStoreFilename = "SingleViewCoreData.sqlite"
    // Appending .nosync should prevent this file from being backed to the cloud
    private let kTidepoolObjectsStoreFilename = "TidepoolObjects.sqlite.nosync"
    private let kTestFilePrefix = "Test-"
    

    static var _controller: NutDataController?
    /// Supports a singleton controller for the application.
    class func controller() -> NutDataController {
        if _controller == nil {
            _controller = NutDataController()
        }
        return _controller!
    }

    /// Coordinator/store for current userId, token, etc. Should always be available.
    func mocForCurrentUser() -> NSManagedObjectContext {
        return self.mocForLocalObjects!
    }

    /// Coordinator/store for editable data: Meal, Workout items.
    ///
    /// This is only available if there is a current user logged in!
    func mocForNutEvents() -> NSManagedObjectContext? {
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
    
    private var _currentUserId: String?
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
    
    /// Call this at login/logout, token refresh(?), and upon enabling or disabling the HealthKit interface.
    func configureHealthKitInterface() {
        if !HealthKitManager.sharedInstance.isHealthDataAvailable {
            return
        }
        
        var interfaceEnabled = true
        if currentUserId != nil  {
            interfaceEnabled = healthKitInterfaceEnabledForCurrentUser()
            if !interfaceEnabled {
                DDLogVerbose("disable because not enabled for current user!")
            }
        } else {
            interfaceEnabled = false
            DDLogVerbose("disable because no current user!")
        }
        
        if interfaceEnabled {
            DDLogVerbose("enable!")
            HealthKitDataUploader.sharedInstance.startUploading(currentUserId: currentUserId)
            monitorForWorkoutData(true)
            HealthKitDataPusher.sharedInstance.enablePushToHealthKit(true)
        } else {
            DDLogVerbose("disable!")
            HealthKitDataUploader.sharedInstance.stopUploading()
            monitorForWorkoutData(false)
            HealthKitDataPusher.sharedInstance.enablePushToHealthKit(false)
        }
    }
    
    /// Call this after logging into a service account to set up the current user and configure the data model for the user.
    ///
    /// - parameter newUser:
    ///   The User object newly created from service login response.
    func loginUser(newUser: User) {
        self.deleteAnyTidepoolData()
        self.currentUser = newUser
        _currentUserId = newUser.userid
        configureHealthKitInterface()
    }

    /// Call this after logging out of the service to deconfigure the data model and clear the persisted user. Only the Meal and Workout events should remain persisted after this.
    func logoutUser() {
        self.deleteAnyTidepoolData()
        self.currentUser = nil
        _currentUserId = nil
        configureHealthKitInterface()
    }

    func monitorForWorkoutData(monitor: Bool) {
        // Set up HealthKit observation and background query.
        if (HealthKitManager.sharedInstance.isHealthDataAvailable) {
            if monitor {
                HealthKitManager.sharedInstance.startObservingWorkoutSamples() {
                    (newSamples: [HKSample]?, deletedSamples: [HKDeletedObject]?, error: NSError?) in
                    
                    if (newSamples != nil) {
                        NSLog("********* PROCESSING \(newSamples!.count) new workout samples ********* ")
                        dispatch_async(dispatch_get_main_queue()) {
                            self.processWorkoutEvents(newSamples!)
                        }
                    }
                    
                    if (deletedSamples != nil) {
                        NSLog("********* PROCESSING \(deletedSamples!.count) deleted workout samples ********* ")
                        dispatch_async(dispatch_get_main_queue()) {
                            self.processDeleteWorkoutEvents(deletedSamples!)
                        }
                    }
                }
            } else {
                HealthKitManager.sharedInstance.stopObservingWorkoutSamples()
            }
        }
    }

    func processProfileFetch(json: JSON) {
        if let user = self.currentUser {
            user.processProfileJSON(json)
            DatabaseUtils.databaseSave(user.managedObjectContext!)
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
    
    /// This is set after user profile fetch is complete upon log-in. When non-nil, it indicates whether the current user logged in is associated with a Data Service Account
    var isDSAUser: Bool? {
        get {
            var result: Bool?
            if let isDSA = currentUser?.accountIsDSA {
                result = Bool(isDSA)
            }
            return result
        }
    }

    //
    // MARK: - HealthKit user info
    //

    private let kHealthKitInterfaceEnabledKey = "workoutSamplingEnabled"
    private let kHealthKitInterfaceUserIdKey = "kUserIdForHealthKitInterfaceKey"
    private let kHealthKitInterfaceUserNameKey = "kUserNameForHealthKitInterfaceKey"
    

    /// Enables HealthKit for current user
    ///
    /// Note: This sets the current tidepool user as the HealthKit user!
    func enableHealthKitInterface() {
        guard let _ = currentUserId else {
            DDLogError("No logged in user at enableHealthKitInterface!")
            return
        }

        func configureCurrentHealthKitUser() {
            let defaults = NSUserDefaults.standardUserDefaults()
            defaults.setBool(true, forKey:self.kHealthKitInterfaceEnabledKey)
            if !self.healthKitInterfaceEnabledForCurrentUser() {
                defaults.setValue(currentUserId!, forKey: kHealthKitInterfaceUserIdKey)
                // may be nil...
                defaults.setValue(userFullName, forKey: kHealthKitInterfaceUserNameKey)
            }
            NSUserDefaults.standardUserDefaults().synchronize()
        }

        HealthKitManager.sharedInstance.authorize(shouldAuthorizeBloodGlucoseSampleReads: true, shouldAuthorizeBloodGlucoseSampleWrites: true, shouldAuthorizeWorkoutSamples: true) {
            success, error -> Void in
            if (error == nil) {
                configureCurrentHealthKitUser()
                self.configureHealthKitInterface()
            } else {
                NSLog("Error authorizing health data \(error), \(error!.userInfo)")
            }
        }
    }
    
    /// Disables HealthKit for current user
    ///
    /// Note: This does not NOT clear the current HealthKit user!
    func disableHealthKitInterface() {
        NSUserDefaults.standardUserDefaults().setBool(false, forKey:kHealthKitInterfaceEnabledKey)
        NSUserDefaults.standardUserDefaults().synchronize()
        configureHealthKitInterface()
    }

    /// Returns true only if the HealthKit interface is enabled and configured for the current user
    func healthKitInterfaceEnabledForCurrentUser() -> Bool {
        if healthKitInterfaceEnabled() == false {
            return false
        }
        if let curHealthKitUserId = healthKitUserTidepoolId(), curId = currentUserId {
            if curId == curHealthKitUserId {
                return true
            }
        }
        return false
    }

    /// Returns true if the HealthKit interface has been configured for a tidepool id different from the current user - ignores whether the interface is currently enabled.
    func healthKitInterfaceConfiguredForOtherUser() -> Bool {
        if let curHealthKitUserId = healthKitUserTidepoolId() {
            if let curId = currentUserId {
                if curId != curHealthKitUserId {
                    return true
                }
            } else {
                DDLogError("No logged in user at healthKitInterfaceEnabledForOtherUser!")
                return true
            }
        }
        return false
    }

    /// Returns whether authorization for HealthKit has been requested, and the HealthKit interface is currently enabled, regardless of user it is enabled for.
    ///
    /// Note: separately, we may enable/disable the current interface to HealthKit.
    private func healthKitInterfaceEnabled() -> Bool {
        return HealthKitManager.sharedInstance.authorizationRequestedForWorkoutSamples()
        && NSUserDefaults.standardUserDefaults().boolForKey(kHealthKitInterfaceEnabledKey)
    }

    /// If HealthKit interface is enabled, returns associated Tidepool account id
    func healthKitUserTidepoolId() -> String? {
        let result = NSUserDefaults.standardUserDefaults().stringForKey(kHealthKitInterfaceUserIdKey)
        return result
    }
    
    /// If HealthKit interface is enabled, returns associated Tidepool account id
    func healthKitUserTidepoolUsername() -> String? {
        let result = NSUserDefaults.standardUserDefaults().stringForKey(kHealthKitInterfaceUserNameKey)
        return result
    }
    
    //
    // MARK: - Loading workout events from Healthkit
    //

    private func processWorkoutEvents(workouts: [HKSample]) {
        let moc = NutDataController.controller().mocForNutEvents()!
        if let entityDescription = NSEntityDescription.entityForName("Workout", inManagedObjectContext: moc) {
            for event in workouts {
                if let workout = event as? HKWorkout {
                    NSLog("*** processing workout id: \(event.UUID.UUIDString)")
                    if let metadata = workout.metadata {
                        NSLog(" metadata: \(metadata)")
                    }
                    if let wkoutEvents = workout.workoutEvents {
                        if !wkoutEvents.isEmpty {
                            NSLog(" workout events: \(wkoutEvents)")
                        }
                    }
                    let we = NSManagedObject(entity: entityDescription, insertIntoManagedObjectContext: nil) as! Workout
                    
                    // Workout fields
                    we.appleHealthDate = workout.startDate
                    we.calories = workout.totalEnergyBurned?.doubleValueForUnit(HKUnit.kilocalorieUnit())
                    we.distance = workout.totalDistance?.doubleValueForUnit(HKUnit.mileUnit())
                    we.duration = workout.duration
                    we.source = workout.sourceRevision.source.name
                    // NOTE: use the Open mHealth enum string here!
                    we.subType = Workout.enumStringForHKWorkoutActivityType(workout.workoutActivityType)
                    
                    // EventItem fields
                    // Default title format: "Run - 4.2 miles"
                    var title: String = Workout.userStringForHKWorkoutActivityTypeEnumString(we.subType!)
                    if let miles = we.distance {
                        let floatMiles = Float(miles)
                        title = title + " - " + String(format: "%.2f",floatMiles) + " miles"
                    }
                    we.title = title
                    // Default notes string is the application name sourcing the event
                    we.notes = we.source
                    
                    // Common fields
                    we.time = workout.startDate
                    we.type = "workout"
                    we.id = event.UUID.UUIDString
                    we.userid = NutDataController.controller().currentUserId
                    let now = NSDate()
                    we.createdTime = now
                    we.modifiedTime = now
                    we.timezoneOffset = NSCalendar.currentCalendar().timeZone.secondsFromGMT/60
                    
                    // Check to see if we already have this one, with possibly a different id
                    if let time = we.time, userId = we.userid {
                        let request = NSFetchRequest(entityName: "Workout")
                        request.predicate = NSPredicate(format: "(time == %@) AND (userid = %@)", time, userId)
                        do {
                            let existingWorkouts = try moc.executeFetchRequest(request) as! [Workout]
                            for workout: Workout in existingWorkouts {
                                if workout.duration == we.duration &&
                                workout.title == we.title &&
                                workout.notes == we.notes {
                                NSLog("Deleting existing workout of same time and duration: \(workout)")
                                    moc.deleteObject(workout)
                                }
                            }
                        } catch {
                            NSLog("Workout dupe query failed!")
                        }
                    }
                    
                    moc.insertObject(we)
                    NSLog("added workout: \(we)")
                } else {
                    NSLog("ERROR: \(#function): Expected HKWorkout!")
                }
            }
        }
        DatabaseUtils.databaseSave(moc)
        
    }
    
    private func processDeleteWorkoutEvents(workouts: [HKDeletedObject]) {
        let moc = NutDataController.controller().mocForNutEvents()!
        for workout in workouts {
            NSLog("Processing deleted workout sample with UUID: \(workout.UUID)");
            let id = workout.UUID.UUIDString
            let request = NSFetchRequest(entityName: "Workout")
            // Note: look for any workout with this id, regardless of current user - we should only see it for one user, but multiple user operation is not yet completely defined.
            request.predicate = NSPredicate(format: "(id == %@)", id)
            do {
                let existingWorkouts = try moc.executeFetchRequest(request) as! [Workout]
                for workout: Workout in existingWorkouts {
                    NSLog("Deleting workout: \(workout)")
                    moc.deleteObject(workout)
                }
                DatabaseUtils.databaseSave(moc)
            } catch {
                NSLog("Existing workout query failed!")
            }
        }
    }
    

    private var runningUnitTests: Bool
    // no instances allowed..
    override private init() {
        self.runningUnitTests = false
        if let _ = NSClassFromString("XCTest") {
            self.runningUnitTests = true
            NSLog("Detected running unit tests!")
        }
    }

    private var _currentUser: User?
    private var currentUser: User? {
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
                if newUser != nil {
                    _currentUserId = newUser!.userid
                    NSLog("Set currentUser, name: \(newUser!.username), id: \(newUser!.userid)")
                } else {
                    NSLog("Cleared currentUser!")
                    _currentUserId = nil
                }
            }
        }
    }

    private var _managedObjectModel: NSManagedObjectModel?
    private var managedObjectModel: NSManagedObjectModel {
        get {
            if _managedObjectModel == nil {
                // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
                let modelURL = NSBundle.mainBundle().URLForResource("Nutshell", withExtension: "momd")!
                _managedObjectModel = NSManagedObjectModel(contentsOfURL: modelURL)!
            }
            return _managedObjectModel!
        }
        set {
            _managedObjectModel = nil
        }
    }
    
    lazy var applicationDocumentsDirectory: NSURL = {
        // The directory the application uses to store the Core Data store file. This code uses a directory named "org.tidepool.Nutshell" in the application's documents Application Support directory.
        let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        return urls[urls.count-1]
    }()

    private var _pscForLocalObjects: NSPersistentStoreCoordinator?
    private var pscForLocalObjects: NSPersistentStoreCoordinator? {
        get {
            if _pscForLocalObjects == nil {
                _pscForLocalObjects = createPSC(kLocalObjectsStoreFilename)
            }
            return _pscForLocalObjects
        }
    }

    private var _pscForTidepoolObjects: NSPersistentStoreCoordinator?
    private var pscForTidepoolObjects: NSPersistentStoreCoordinator? {
        get {
            if _pscForTidepoolObjects == nil {
                _pscForTidepoolObjects = createPSC(kTidepoolObjectsStoreFilename)
            }
            return _pscForTidepoolObjects
        }
    }
    
    private func filenameAdjustedForTest(filename: String) -> String {
        if self.runningUnitTests {
            // NOTE: if we are running unit tests, the store objects will be incompatible!
            return kTestFilePrefix + filename
        } else {
            return filename
        }
    }
    
    private func createPSC(storeBaseFileName: String) -> NSPersistentStoreCoordinator {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        var url = applicationDocumentsDirectory
        url = url.URLByAppendingPathComponent(filenameAdjustedForTest(storeBaseFileName))
        let failureReason = "There was an error creating or loading the application's saved data."
        let pscOptions = [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true]
        do {
            NSLog("Store url is \(url)")
            // TODO: use NSInMemoryStoreType for test databases!
            try coordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: url, options: pscOptions)
        } catch {
            // Report any error we got.
            var dict = [String: AnyObject]()
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data"
            dict[NSLocalizedFailureReasonErrorKey] = failureReason
            
            dict[NSUnderlyingErrorKey] = error as NSError
            let wrappedError = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
            // TODO: Replace this with code to handle the error appropriately -> probably delete the store and retry?
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog("Unresolved error \(wrappedError), \(wrappedError.userInfo)")
            abort()
        }
        return coordinator
    }

    private var _mocForLocalObjects: NSManagedObjectContext?
    private var mocForLocalObjects: NSManagedObjectContext? {
        get {
            if _mocForLocalObjects == nil {
                let coordinator = self.pscForLocalObjects
                let managedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
                managedObjectContext.persistentStoreCoordinator = coordinator
                _mocForLocalObjects = managedObjectContext
                
            }
            return _mocForLocalObjects!
        }
    }
    
    private var _mocForTidepoolObjects: NSManagedObjectContext?
    private var mocForTidepoolObjects: NSManagedObjectContext? {
        get {
            if _mocForTidepoolObjects == nil {
                let coordinator = self.pscForTidepoolObjects
                let managedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
                managedObjectContext.persistentStoreCoordinator = coordinator
                _mocForTidepoolObjects = managedObjectContext
            }
            return _mocForTidepoolObjects!
        }
    }
    
    private func saveContext() {
        if let mocForLocalObjects = mocForLocalObjects {
            self.saveContextIfChanged(mocForLocalObjects)
        }
        if let mocForTidepoolObjects = mocForTidepoolObjects {
            self.saveContextIfChanged(mocForTidepoolObjects)
        }
    }

    private func saveContextIfChanged(moc: NSManagedObjectContext) {
        if moc.hasChanges {
            do {
                try moc.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                NSLog("Unresolved error \(nserror), \(nserror.userInfo)")
                abort()
            }
        }
    }
    
    //
    // MARK: - Manage current user
    //

    private func getUser() -> User? {
        let moc = self.mocForCurrentUser()
        let request = NSFetchRequest(entityName: "User")
        do {
            if let results = try moc.executeFetchRequest(request) as? [User] {
                if results.count > 0 {
                    return results[0]
                }
            }
            return  nil
        } catch let error as NSError {
            print("Error getting user: \(error)")
            return nil
        }
    }
    
    private func updateUser(currentUser: User?, newUser: User?) {
        let moc = self.mocForCurrentUser()
        // Remove existing user if passed in
        if let currentUser = currentUser {
            let request = NSFetchRequest(entityName: "User")
            request.predicate = NSPredicate(format: "userid==%@", currentUser.userid!)
            do {
                let results = try moc.executeFetchRequest(request) as? [User]
                if results != nil {
                    for result in results! {
                        moc.deleteObject(result)
                    }
                }
            } catch let error as NSError {
                print("Failed to remove existing user: \(currentUser.userid) error: \(error)")
            }
        }
        
        if let newUser = newUser {
            moc.insertObject(newUser)
        }
        
        // Save the database
        do {
            try moc.save()
        } catch let error as NSError {
            print("Failed to save MOC for user: \(error)")
        }
    }

    /// Resets the tidepool object database by deleting the underlying file!
    private func deleteAnyTidepoolData() {
        // Delete the underlying file
        var url = self.applicationDocumentsDirectory
        url = url.URLByAppendingPathComponent(filenameAdjustedForTest(kTidepoolObjectsStoreFilename))
        var error: NSError?
        let fileExists = url.checkResourceIsReachableAndReturnError(&error)
        if (fileExists) {
            // First nil out locals so a new psc and moc will be created on demand
            _pscForTidepoolObjects = nil
            _mocForTidepoolObjects = nil
            DatabaseUtils.resetTidepoolEventLoader() // reset cache as well!
            let fm = NSFileManager.defaultManager()
            do {
                try fm.removeItemAtURL(url)
                NSLog("Deleted database at \(url)")
            } catch let error as NSError {
                NSLog("Failed to delete \(url), error: \(error)")
            }
        }
    }
    


}