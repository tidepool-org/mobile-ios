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

class hashtagBolderTests: XCTestCase {
    
    // TODO: change to also test higher level HashTagManager tests!
    
    let hashtagBolder = HashtagBolder()
    
    override func setUp() {
        super.setUp()
        // Setup code. This method is called before the invocation of each test method in the class.
        // No setup needed.
    }
    
    override func tearDown() {
        // Teardown code. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testEmpty() {
        XCTAssertEqual(hashtagBolder.boldHashtags(""), NSAttributedString(), "Assert that an empty string passed returns an empty attributed string")
    }
    
    func testNoHashtags() {
        // String that does not contain hashtags, to be passed through hashtagBolder.
        let text = "This is text that does not contain hashtags. No hashtags are present."
        
        // Expected attributed output has no bolded portions.
        let expected = NSAttributedString(string: text, attributes: [NSAttributedString.Key.font: Styles.mediumSmallRegularFont, NSAttributedString.Key.foregroundColor: Styles.blackishColor])
        
        // Assert that the output and the expected string are indeed the same string (by content and attributes, not instance).
        XCTAssertEqual(hashtagBolder.boldHashtags(text as NSString), expected, "Assert that a string containing no hashtags is unbolded.")
    }
    
    func testWithHashtags() {
        
        // String that does contain hashtags, to be passed through the hashtagBolder.
        let text = "This #is text #that? does #contain! #hashtags. #hashtags are present."
        
        // Expected attributed output that has bolded portions.
        let expected = NSMutableAttributedString(string: text, attributes: [NSAttributedString.Key.font: Styles.mediumSmallRegularFont, NSAttributedString.Key.foregroundColor: Styles.blackishColor])
        // Oh, and bold it.
        expected.addAttributes([NSAttributedString.Key.font: Styles.mediumSmallBoldFont], range: NSRange(location: 5, length: 3))
        expected.addAttributes([NSAttributedString.Key.font: Styles.mediumSmallBoldFont], range: NSRange(location: 14, length: 5))
        expected.addAttributes([NSAttributedString.Key.font: Styles.mediumSmallBoldFont], range: NSRange(location: 26, length: 8))
        expected.addAttributes([NSAttributedString.Key.font: Styles.mediumSmallBoldFont], range: NSRange(location: 36, length: 9))
        expected.addAttributes([NSAttributedString.Key.font: Styles.mediumSmallBoldFont], range: NSRange(location: 47, length: 9))
        
        // Assert that the output and the expected string are indeed the same string (by content and attributes, not instance).
        XCTAssertEqual(hashtagBolder.boldHashtags(text as NSString), expected, "Assert that a string containing hashtags is properly bolded.")
    }
    
    func testPerformanceExample() {
        // Test the speed of the hashtag bolder. Repeating hashtags take the most time.
        let text = "#first #second #first #second #first #second #first #second #first #second #first #second #first #second #first #second #first #second #first #second #first #second #first #second #first #second #first #second"
        self.measure() {
            let _ = self.hashtagBolder.boldHashtags(text as NSString)
        }
    }
    
}
