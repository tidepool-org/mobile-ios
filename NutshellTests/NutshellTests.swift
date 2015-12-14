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

class NutshellTests: XCTestCase {

    // Initial API connection and note used throughout testing
    var userid: String = ""
    var email: String = "testaccount+duffliteA@tidepool.org"
    var pass: String = "testaccount+duffliteA"
    var server: String = "Production"

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        // Initialize database by referencing username. This must be done before using the APIConnector!
        let _ = NutDataController.controller().currentUserName
        APIConnector.connector().configure()
        APIConnector.connector().switchToServer(server)
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testLoginOut() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        let expectation = expectationWithDescription("Login successful")
        if email == "test username goes here!" {
            XCTFail("Fatal error: please edit NutshellTests.swift and add a test account!")
        }
        APIConnector.connector().login(email,
            password: pass, remember: false,
            completion: { (result:(Alamofire.Result<User>)) -> (Void) in
                print("Login result: \(result)")
                if ( result.isSuccess ) {
                    if let user=result.value {
                        print("login success: \(user)")
                        expectation.fulfill()
                        //appDelegate.setupUIForLoginSuccess()
                    } else {
                        // This should not happen- we should not succeed without a user!
                        XCTFail("Fatal error: No user returned!")
                    }
                } else {
                    var errorCode = ""
                    if let error = result.error as? NSError {
                        errorCode = String(error.code)
                    }
                    XCTFail("login failed! Error: " + errorCode + result.error.debugDescription)
                }
        })
        // Wait 5.0 seconds until expectation has been fulfilled. If not, fail.
        waitForExpectationsWithTimeout(5.0, handler: nil)

    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock {
            // Put the code you want to measure the time of here.
        }
    }
    
}
