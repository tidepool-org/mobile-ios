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

import XCTest
@testable import TidepoolMobile
import Alamofire
import SwiftyJSON

class APIConnectTests: XCTestCase, NoteAPIWatcher, UsersFetchAPIWatcher  {

    
    // TODO: add tests for update and delete note, and no note return
    // TODO: use login if already logged in!
    
    
    // Initial API connection and note used throughout testing
    var userid: String = ""
    var email: String = "ethan+urchintests@tidepool.org"
    var pass: String = "urchintests"
    var server: String = "Development"

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        // Initialize database by referencing username. This must be done before using the APIConnector!
        let _ = TidepoolMobileDataController.sharedInstance.currentUserName
        _ = APIConnector.connector().configure()
        APIConnector.connector().switchToServer(server)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    
    //
    // MARK: - NoteAPIWatcher delegate
    //
    func loadingNotes(_ loading: Bool) {}
    func endRefresh() {}
    
    
    private var addNotesExpectation: XCTestExpectation?
    func addNotes(_ notes: [BlipNote]) {
        if let addNotesExpectation = addNotesExpectation {
            if notes.count > 0 {
                addNotesExpectation.fulfill()
            } else {
                XCTFail("No notes!")
            }
        }
    }
    
    func addComments(_ notes: [BlipNote], messageId: String) {}
    
    private var postCompleteExpectation: XCTestExpectation?
    func postComplete(_ note: BlipNote) {
        if let postCompleteExpectation = postCompleteExpectation {
            postCompleteExpectation.fulfill()
        }
    }
    
    func deleteComplete(_ note: BlipNote) {}
    func updateComplete(_ originalNote: BlipNote, editedNote: BlipNote) {}
    
    //
    // MARK: - UsersFetchAPIWatcher delegate
    //

    private var viewableUsersExpectation: XCTestExpectation?
    func viewableUsers(_ userIds: [String]) {
        if let viewableUsersExpectation = viewableUsersExpectation {
            if userIds.count > 0 {
                viewableUsersExpectation.fulfill()
            } else {
                XCTFail("No viewable users!")
            }
        }
    }
    
    //
    // MARK: - Helper functions
    //
    
    func login(_ username: String, password: String, completion: @escaping (Result<User>) -> (Void)) {
        APIConnector.connector().login(email,
            password: pass) { (result:Alamofire.Result<User>, statusCode: Int?) -> (Void) in
                print("Login result: \(result)")
                completion(result)
        }
    }
    
    //
    // MARK: - Tests
    //
    
    func test01LoginSuccess() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        let expectation = self.expectation(description: "Login successful")
        if email == "test username goes here!" {
            XCTFail("Fatal error: please edit TidepoolMobileTests.swift and add a test account!")
        }
        self.login(email, password: pass) { (result:(Alamofire.Result<User>)) -> (Void) in
                if ( result.isSuccess ) {
                    if let user=result.value {
                        NSLog("login success: \(user)")
                        expectation.fulfill()
                        //appDelegate.setupUIForLoginSuccess()
                    } else {
                        // This should not happen- we should not succeed without a user!
                        XCTFail("Fatal error: No user returned!")
                    }
                } else {
                    var errorCode = ""
                    if let error = result.error {
                        errorCode = String(error._code)
                    }
                    XCTFail("login failed! Error: " + errorCode + result.error.debugDescription)
                }
        }
        // Wait 5.0 seconds until expectation has been fulfilled. If not, fail.
        waitForExpectations(timeout: 5.0, handler: nil)

    }

    func test02FetchUserProfile() {
        let expectation = self.expectation(description: "User profile fetch successful")
        
        self.login(email, password: pass) { (result:(Alamofire.Result<User>)) -> (Void) in
            print("Login for profile result: \(result)")

             APIConnector.connector().fetchProfile(TidepoolMobileDataController.sharedInstance.currentUserId!) { (result:Alamofire.Result<JSON>) -> (Void) in
                NSLog("Profile fetch result: \(result)")
                if (result.isSuccess) {
                    if let json = result.value {
                        TidepoolMobileDataController.sharedInstance.processLoginProfileFetch(json)
                    }
                    expectation.fulfill()
                } else {
                    var errorCode = ""
                    if let error = result.error {
                        errorCode = String(error._code)
                    }
                    XCTFail("profile fetch failed! Error: " + errorCode + result.error.debugDescription)
                }
            }
        }
        
        // Wait 5.0 seconds until expectation has been fulfilled. If not, fail.
        waitForExpectations(timeout: 5.0, handler: nil)
    }

    func test03FetchUserData() {
        // Note: tests updateEvents, which is not currently used!
        let expectation = self.expectation(description: "User profile fetch successful")
        self.login(email, password: pass) { (result:(Alamofire.Result<User>)) -> (Void) in
            print("Login for fetch user data result: \(result)")
            
            // Look at events in July 2015...
            let startDate = TidepoolMobileUtils.dateFromJSON("2015-07-01T00:00:00.000Z")!
            let endDate = TidepoolMobileUtils.dateFromJSON("2015-07-31T23:59:59.000Z")!
            
            APIConnector.connector().getReadOnlyUserData(startDate, endDate: endDate) { (result:Alamofire.Result<JSON>) -> (Void) in
                NSLog("FetchUserData result: \(result)")
                if (result.isSuccess) {
                    if let json = result.value {
                        if result.isSuccess {
                            DatabaseUtils.sharedInstance.updateEvents(TidepoolMobileDataController.sharedInstance.mocForTidepoolEvents()!, eventsJSON: json)
                        } else {
                            NSLog("No user data events!")
                        }
                    }
                    expectation.fulfill()
                } else {
                    var errorCode = ""
                    if let error = result.error {
                        errorCode = String(error._code)
                    }
                    XCTFail("user data fetch failed! Error: " + errorCode + result.error.debugDescription)
                }
            }
        }
        // Wait 5.0 seconds until expectation has been fulfilled. If not, fail.
        waitForExpectations(timeout: 5.0, handler: nil)
    }
    
    func test04FetchUserData2() {
        // Note: tests updateEventsForTimeRange!
        let expectation = self.expectation(description: "User profile fetch successful")
        
        self.login(email, password: pass) { (result:(Alamofire.Result<User>)) -> (Void) in
            print("Login for fetch user data result: \(result)")
            // Look at events in July 2015...
            let startDate = TidepoolMobileUtils.dateFromJSON("2015-07-01T00:00:00.000Z")!
            let endDate = TidepoolMobileUtils.dateFromJSON("2015-07-31T23:59:59.000Z")!
            
            APIConnector.connector().getReadOnlyUserData(startDate, endDate: endDate) { (result:Alamofire.Result<JSON>) -> (Void) in
                NSLog("FetchUserData2 result: \(result)")
                if (result.isSuccess) {
                    if let json = result.value {
                        if result.isSuccess {
                            _ = DatabaseUtils.sharedInstance.updateEventsForTimeRange(startDate, endTime: endDate, moc:TidepoolMobileDataController.sharedInstance.mocForTidepoolEvents()!, eventsJSON: json) {
                                (success) -> (Void) in
                                expectation.fulfill()
                            }
                        } else {
                            XCTFail("updateEventsForTimeRange failed!")
                        }
                    }
                } else {
                    var errorCode = ""
                    if let error = result.error {
                        errorCode = String(error._code)
                    }
                    XCTFail("user data fetch failed! Error: " + errorCode + result.error.debugDescription)
                }
            }
        }
        // Wait 5.0 seconds until expectation has been fulfilled. If not, fail.
        waitForExpectations(timeout: 5.0, handler: nil)
    }

    func test05GetViewableUsers() {
        
        // First, perform login request and verify that login was successful.
        test01LoginSuccess()
        
        // Expectation to be fulfilled once request returns with correct response, fulfilled in viewableUsers callback.
        viewableUsersExpectation = self.expectation(description: "Viewable users request")
        APIConnector.connector().getAllViewableUsers(self)
        
        // Wait 5.0 seconds until expectation has been fulfilled. If not, fail.
        waitForExpectations(timeout: 5.0, handler: nil)
    }
    
    func test06PostANote() {
        
        // First, perform login request and verify that login was successful.
        test01LoginSuccess()
        
        // Expectation to be fulfilled once request returns with correct response, fulfilled in addNotes callback.
        postCompleteExpectation = self.expectation(description: "Post note request")
        let userId = TidepoolMobileDataController.sharedInstance.currentUserId!
        let note = BlipNote()
        note.userid = userId
        note.groupid = userId
        note.timestamp = Date()
        note.messagetext = "New note added from test."
        APIConnector.connector().doPostWithNote(self, note: note)
        
        // Wait 5.0 seconds until expectation has been fulfilled. If not, fail.
        waitForExpectations(timeout: 5.0, handler: nil)
    }

    func test07GetAllNotes() {
        
        // First, perform login request and verify that login was successful.
        test01LoginSuccess()
        
        // Expectation to be fulfilled once request returns with correct response, fulfilled in addNotes callback.
        addNotesExpectation = self.expectation(description: "Get notes request")
        let userId = TidepoolMobileDataController.sharedInstance.currentUserId!
        APIConnector.connector().getNotesForUserInDateRange(self, userid: userId, start: nil, end: nil)
        
        // Wait 5.0 seconds until expectation has been fulfilled. If not, fail.
        waitForExpectations(timeout: 5.0, handler: nil)
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
