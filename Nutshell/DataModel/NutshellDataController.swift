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

class NutDataController
{

    // Supports a singleton controller for the application
    static var _controller: NutDataController?
    class func controller() -> NutDataController {
        if _controller == nil {
            _controller = NutDataController()
        }
        return _controller!
    }

    // Coordinator/store for current userId, token, etc. Should always be available.
    func mocForCurrentUser() -> NSManagedObjectContext {
        return NutDataController.controller().managedObjectContext
    }

    // Coordinator/store for editable data: Meal, Workout items. 
    // This is only available if there is a current user logged in!
    func mocForNutEvents() -> NSManagedObjectContext? {
        if _currentUserId != nil {
            return mocForCurrentUser()
        }
        return nil;
    }

    // Coordinator/store for read-only Tidepool data
    // This is only available if there is a current user logged in!
    func mocForTidepoolEvents() -> NSManagedObjectContext? {
        if _currentUserId != nil {
            return mocForCurrentUser()
        }
        return nil;
    }
    

    // Note: Since the data model stores the current user, uses the current userId for tagging some data objects, and switches the tidepool object store based on current user, manage it centrally here.
    

    // Read only - set indirectly via loginUser/logoutUser calls. Needed to tag nut events in database.
    var _currentUserId: String?
    var currentUserId: String? {
        get {
            return _currentUserId
        }
    }

    // Read only - returns nil string if no user set.
    // NOTE: startup reference from app delegate has side effect of setting currentUserId!
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

    func loginUser(newUser: User) {
        self.currentUser = newUser
        _currentUserId = newUser.userid
    }

    func logoutUser() {
        if self.currentUser != nil {
            DatabaseUtils.clearDatabase(mocForTidepoolEvents()!)
        }
        self.currentUser = nil
        _currentUserId = nil
    }
    
    func appWillTerminate() {
        self.saveContext()
    }

    //
    // MARK: - Private methods
    //

    // no instances allowed..
    private init() {
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

    private var _persistentStoreCoordinator: NSPersistentStoreCoordinator?
    // The persistent store coordinator for the application. 
    // TODO: create a separate one for transitory read only data!
    private var persistentStoreCoordinator: NSPersistentStoreCoordinator? {
        get {
            if _persistentStoreCoordinator == nil {
                let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
                var url = applicationDocumentsDirectory
//                if let storeUserIdPath = _currentUserId {
//                    url = url.URLByAppendingPathComponent(storeUserIdPath)
//                } else {
//                    NSLog("No user id path at persistent store time!")
//                    abort()
//                }
                url = url.URLByAppendingPathComponent("SingleViewCoreData.sqlite")
                let failureReason = "There was an error creating or loading the application's saved data."
                let pscOptions = [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true]
                do {
                    try coordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: url, options: pscOptions)
                } catch {
                    // Report any error we got.
                    var dict = [String: AnyObject]()
                    dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data"
                    dict[NSLocalizedFailureReasonErrorKey] = failureReason
                    
                    dict[NSUnderlyingErrorKey] = error as NSError
                    let wrappedError = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
                    // Replace this with code to handle the error appropriately.
                    // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                    NSLog("Unresolved error \(wrappedError), \(wrappedError.userInfo)")
                    abort()
                }
                _persistentStoreCoordinator = coordinator
            }
            return _persistentStoreCoordinator!
        }
    }
    
    private var _managedObjectContext: NSManagedObjectContext?
    private var managedObjectContext: NSManagedObjectContext {
        get {
            if _managedObjectContext == nil {
                let coordinator = self.persistentStoreCoordinator
                let managedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
                managedObjectContext.persistentStoreCoordinator = coordinator
                _managedObjectContext = managedObjectContext
            }
            return _managedObjectContext!
        }
    }
    
    private func saveContext () {
        if managedObjectContext.hasChanges {
            do {
                try managedObjectContext.save()
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
        let moc = NutDataController.controller().mocForCurrentUser()
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
        let moc = NutDataController.controller().mocForCurrentUser()
        // Remove existing user if passed in
        if let currentUser = currentUser {
            let request = NSFetchRequest(entityName: "User")
            request.predicate = NSPredicate(format: "userid==%@", currentUser.userid!)
            do {
                let results = try moc.executeFetchRequest(request) as! [User]
                for result in results {
                    moc.deleteObject(result)
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

}