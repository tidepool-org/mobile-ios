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
    /// Supports a singleton controller for the application.
    static let sharedInstance = NutDataController()
    
    // MARK: - Constants
    
    fileprivate let kLocalObjectsStoreFilename = "SingleViewCoreData.sqlite"
    // Appending .nosync should prevent this file from being backed to the cloud
    fileprivate let kTidepoolObjectsStoreFilename = "TidepoolObjects.sqlite.nosync"
    fileprivate let kTestFilePrefix = "Test-"
    
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
    
    /// Temp shared global for all notes for current profile (until we move this into local database.
    var currentNotes: [BlipNote]?
    
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
                    NSLog("Current viewable user is \(_currentViewedUser?.fullName)")
                    _currentViewedUser = user
                }
            }
            return _currentViewedUser
        }
        set(newUser) {
            _currentViewedUser = newUser
            NSLog("Current viewable user changed to \(_currentViewedUser!.fullName)")
            self.deleteAnyTidepoolData()
            configureHealthKitInterface()
        }
    }
    fileprivate var _currentViewedUser: BlipUser?


    /// Call this at login/logout, token refresh(?), and upon enabling or disabling the HealthKit interface.
    func configureHealthKitInterface() {
        appHealthKitConfiguration.configureHealthKitInterface(currentUserId, isDSAUser: isDSAUser)
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
        configureHealthKitInterface()
    }

    /// Call this after logging out of the service to deconfigure the data model and clear the persisted user. Only the Meal and Workout events should remain persisted after this.
    func logoutUser() {
        self.deleteAnyTidepoolData()
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
    // MARK: - HealthKit user info
    //

    /// Enables HealthKit for current viewable user
    ///
    /// Note: This sets the current tidepool user as the HealthKit user!
    func enableHealthKitInterface() {
        appHealthKitConfiguration.enableHealthKitInterface(currentUserName, userid: currentUserId, isDSAUser: isDSAUser, needsGlucoseReads: true, needsGlucoseWrites: true, needsWorkoutReads: true)
    }
    
    /// Disables HealthKit for current user
    ///
    /// Note: This does not NOT clear the current HealthKit user!
    func disableHealthKitInterface() {
        appHealthKitConfiguration.disableHealthKitInterface()
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
            NSLog("Detected running unit tests!")
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
                    NSLog("Set currentUser, name: \(newUser!.username), id: \(newUser!.userid)")
                } else {
                    NSLog("Cleared currentUser!")
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
                let modelURL = Bundle.main.url(forResource: "Nutshell", withExtension: "momd")!
                _managedObjectModel = NSManagedObjectModel(contentsOf: modelURL)!
            }
            return _managedObjectModel!
        }
        set {
            _managedObjectModel = nil
        }
    }
    
    lazy var applicationDocumentsDirectory: URL = {
        // The directory the application uses to store the Core Data store file. This code uses a directory named "org.tidepool.Nutshell" in the application's documents Application Support directory.
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return urls[urls.count-1]
    }()

    fileprivate var _pscForLocalObjects: NSPersistentStoreCoordinator?
    fileprivate var pscForLocalObjects: NSPersistentStoreCoordinator? {
        get {
            if _pscForLocalObjects == nil {
                _pscForLocalObjects = createPSC(kLocalObjectsStoreFilename)
            }
            return _pscForLocalObjects
        }
    }

    fileprivate var _pscForTidepoolObjects: NSPersistentStoreCoordinator?
    fileprivate var pscForTidepoolObjects: NSPersistentStoreCoordinator? {
        get {
            if _pscForTidepoolObjects == nil {
                _pscForTidepoolObjects = createPSC(kTidepoolObjectsStoreFilename)
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
    
    fileprivate func createPSC(_ storeBaseFileName: String) -> NSPersistentStoreCoordinator {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        var url = applicationDocumentsDirectory
        url = url.appendingPathComponent(filenameAdjustedForTest(storeBaseFileName))
        let failureReason = "There was an error creating or loading the application's saved data."
        let pscOptions = [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true]
        do {
            NSLog("Store url is \(url)")
            // TODO: use NSInMemoryStoreType for test databases!
            try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: pscOptions)
        } catch {
            // Report any error we got.
            var dict = [String: AnyObject]()
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data" as AnyObject?
            dict[NSLocalizedFailureReasonErrorKey] = failureReason as AnyObject?
            
            dict[NSUnderlyingErrorKey] = error as NSError
            let wrappedError = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
            // TODO: Replace this with code to handle the error appropriately -> probably delete the store and retry?
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog("Unresolved error \(wrappedError), \(wrappedError.userInfo)")
            abort()
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
                NSLog("Unresolved error \(nserror), \(nserror.userInfo)")
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
            print("Error getting user: \(error)")
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
                print("Failed to remove existing user: \(currentUser.userid) error: \(error)")
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
    fileprivate func deleteAnyTidepoolData() {
        // Delete the underlying file
        var url = self.applicationDocumentsDirectory
        url = url.appendingPathComponent(filenameAdjustedForTest(kTidepoolObjectsStoreFilename))
        var error: NSError?
        let fileExists = (url as NSURL).checkResourceIsReachableAndReturnError(&error)
        if (fileExists) {
            // First nil out locals so a new psc and moc will be created on demand
            _pscForTidepoolObjects = nil
            _mocForTidepoolObjects = nil
            DatabaseUtils.resetTidepoolEventLoader() // reset cache as well!
            let fm = FileManager.default
            do {
                try fm.removeItem(at: url)
                NSLog("Deleted database at \(url)")
            } catch let error as NSError {
                NSLog("Failed to delete \(url), error: \(error)")
            }
        }
    }
    


}
