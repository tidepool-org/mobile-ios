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
import XCTest

class dateFormatterExtensionTests: XCTestCase {

    // TODO: change to test higher level date functions!
    
    override func setUp() {
        super.setUp()
        // Setup code. This method is called before the invocation of each test method in the class.
        // No setup needed.
    }
    
    override func tearDown() {
        // Teardown code. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testAttributedStringFromDate() {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = TimeZone(identifier: "GMT")
        
        // Date to be used in formatting test.
        let date = Date(timeIntervalSince1970: 946729800)
        
        // Expected result of formatted string.
        let expected = NSMutableAttributedString(string: "Saturday 1/1/00 12:30pm", attributes: [NSAttributedString.Key.foregroundColor: UIColor.black, NSAttributedString.Key.font: UIFont(name: "OpenSans", size: 12.5)!])
        // Bold the time at the end.
        expected.addAttribute(NSAttributedString.Key.font, value: UIFont(name: "OpenSans-Bold", size: 12.5)!, range: NSRange(location: 16, length: 7))
        
        // Assert that the output and the expected, have the same formatting.
        XCTAssertEqual(dateFormatter.attributedStringFromDate(date), expected, "Assert that the date formatter properly bolds to expected.")
    }
    
    func testDateFromISOString() {
        let dateFormatter = DateFormatter()
        
        // String to be converted to NSDate.
        let dateString = "2015-06-04T13:45:36+00:00"
        
        // Expected NSDate to be created.
        let expected = Date(timeIntervalSince1970: 1433425536)
        
        // Assert that the output and the expected date are indeed the same date (by content, not instance).
        XCTAssertEqual(dateFormatter.dateFromISOString(dateString), expected, "Assert that date formatter converts to NSDate properly.")
    }
    
    func testISOStringFromDate() {
        let dateFormatter = DateFormatter()
        
        // NSDate to be converted to String.
        let date = Date(timeIntervalSince1970: 1433425536)

        // Expected String to be created.
        let expected = "2015-06-04T13:45:36Z"
        
        // Assert that the output and the expected string are indeed the same string (by content, not instance).
        XCTAssertEqual(dateFormatter.isoStringFromDate(date, zone: TimeZone(identifier: "GMT")), expected, "Assert that date formatter converts NSDate to ISO 8601 properly.")
    }

    func testStringFromRegDate() {
        let dateFormatter = DateFormatter()
        
        // NSDate to be converted to String.
        let date = Date(timeIntervalSince1970: 823521600)
        
        // Expected String to be created.
        let expected = "1996-02-05"
        
        // Assert that the output and the expected string are indeed the same string (by content, not instance).
        XCTAssertEqual(dateFormatter.stringFromRegDate(date), expected, "Assert that a NSDate for a day, such as a birthday, converts to a string properly.")
    }

}
