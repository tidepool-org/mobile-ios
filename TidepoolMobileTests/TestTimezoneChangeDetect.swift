//
//  TestTimezoneChangeDetect.swift
//  TidepoolMobile
//
//  Copyright © 2018 Tidepool. All rights reserved.
//

import UIKit

var lastStoredTzId: String?
class RandomObj {
}
var randObj: RandomObj?

func testTimezoneDidChange(_ notification : Notification, testName: String) {
    print("\ntesting: \(testName)")
    //only store if new tz is different from last seen?
    let newTimeZoneId = TimeZone.current.identifier
    if newTimeZoneId == lastStoredTzId {
        print("TZ change notification when TZ has not changed: \(newTimeZoneId)")
        return
    }
    print("Changed to timezone id: \(newTimeZoneId)")
    let previousTimeZone = notification.object as? TimeZone
    var previousTimezoneId: String?
    if previousTimeZone != nil {
        previousTimezoneId = previousTimeZone!.identifier
        print("Changed from timezone id: \(previousTimezoneId!)")
        if previousTimezoneId == newTimeZoneId {
            print("Ignoring notification of change to same timezone!")
            return
        }
    }
    print("addNewTimezoneChange newTimezoneId: \(newTimeZoneId), previousTimezoneId: \(previousTimezoneId ?? "nil")")
}

let curTz = TimeZone.current
let gmtTz = TimeZone(secondsFromGMT: 0)

lastStoredTzId = nil
let noChangeNote = Notification(name: Notification.Name.NSSystemTimeZoneDidChange, object: curTz)
testTimezoneDidChange(noChangeNote, testName: "lastStoredTzId is nil, prev tz is current")

lastStoredTzId = TimeZone.current.identifier
testTimezoneDidChange(noChangeNote, testName: "lastStoredTzId is current, prev tz is current")

lastStoredTzId = nil
let nilLastChangeNote = Notification(name: Notification.Name.NSSystemTimeZoneDidChange, object: randObj)
testTimezoneDidChange(nilLastChangeNote, testName: "lastStoredTzId is nil, prev tz is nil")

randObj = RandomObj()
let otherObjLastChangeNote = Notification(name: Notification.Name.NSSystemTimeZoneDidChange, object: randObj)
testTimezoneDidChange(nilLastChangeNote, testName: "lastStoredTzId is nil, prev tz is other obj")
