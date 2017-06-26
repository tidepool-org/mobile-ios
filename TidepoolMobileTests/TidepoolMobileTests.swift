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
@testable import Nutshell
import Alamofire
import SwiftyJSON

class TidepoolMobileTests: XCTestCase {

    // Initial API connection and note used throughout testing
    var userid: String = ""
    var email: String = "testaccount+duffliteA@tidepool.org"
    var pass: String = "testaccount+duffliteA"
    var server: String = "Production"

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        // Initialize database by referencing username. This must be done before using the APIConnector!
        let _ = NutDataController.sharedInstance.currentUserName
        _ = APIConnector.connector().configure()
        APIConnector.connector().switchToServer(server)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func login(_ username: String, password: String, remember: Bool, completion: @escaping (Result<User>) -> (Void)) {
        APIConnector.connector().login(email,
            password: pass) { (result:(Alamofire.Result<User>)) -> (Void) in
                print("Login result: \(result)")
                completion(result)
        }
    }
    
    func test01LoginOut() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        let expectation = self.expectation(description: "Login successful")
        if email == "test username goes here!" {
            XCTFail("Fatal error: please edit TidepoolMobileTests.swift and add a test account!")
        }
        self.login(email, password: pass, remember: false) { (result:(Alamofire.Result<User>)) -> (Void) in
                print("Login result: \(result)")
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
        
        self.login(email, password: pass, remember: false) { (result:(Alamofire.Result<User>)) -> (Void) in
            print("Login for profile result: \(result)")

             APIConnector.connector().fetchProfile(NutDataController.sharedInstance.currentUserId!) { (result:Alamofire.Result<JSON>) -> (Void) in
                NSLog("Profile fetch result: \(result)")
                if (result.isSuccess) {
                    if let json = result.value {
                        NutDataController.sharedInstance.processLoginProfileFetch(json)
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
        let expectation = self.expectation(description: "User profile fetch successful")
        
        self.login(email, password: pass, remember: false) { (result:(Alamofire.Result<User>)) -> (Void) in
            print("Login for fetch user data result: \(result)")
            
            // Look at events in July 2015...
            let startDate = TidepoolMobileUtils.dateFromJSON("2015-07-01T00:00:00.000Z")!
            let endDate = TidepoolMobileUtils.dateFromJSON("2015-07-31T23:59:59.000Z")!
            
            APIConnector.connector().getReadOnlyUserData(startDate, endDate: endDate) { (result:Alamofire.Result<JSON>) -> (Void) in
                NSLog("FetchUserData result: \(result)")
                if (result.isSuccess) {
                    if let json = result.value {
                        if result.isSuccess {
                            DatabaseUtils.sharedInstance.updateEvents(NutDataController.sharedInstance.mocForTidepoolEvents()!, eventsJSON: json)
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
        let expectation = self.expectation(description: "User profile fetch successful")
        
        self.login(email, password: pass, remember: false) { (result:(Alamofire.Result<User>)) -> (Void) in
            print("Login for fetch user data result: \(result)")
            
            // Look at events in July 2015...
            let startDate = TidepoolMobileUtils.dateFromJSON("2015-07-01T00:00:00.000Z")!
            let endDate = TidepoolMobileUtils.dateFromJSON("2015-07-31T23:59:59.000Z")!
            
            APIConnector.connector().getReadOnlyUserData(startDate, endDate: endDate) { (result:Alamofire.Result<JSON>) -> (Void) in
                NSLog("FetchUserData2 result: \(result)")
                if (result.isSuccess) {
                    if let json = result.value {
                        if result.isSuccess {
                            _ = DatabaseUtils.sharedInstance.updateEventsForTimeRange(startDate, endTime: endDate, moc:NutDataController.sharedInstance.mocForTidepoolEvents()!, eventsJSON: json) {
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

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
