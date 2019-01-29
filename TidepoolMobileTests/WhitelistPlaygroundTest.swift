//
//  WhitelistPlaygroundTest.swift
//  TidepoolMobile
//
//  Copyright © 2018 Tidepool. All rights reserved.
//

// Paste into playground to work on whitelisting logic for cbg samples

import UIKit

func determineTypeOfBG(sourceName: String, bundleId: String) -> (type: String, isDexcom: Bool) {
    let bundleIdSeparators = CharacterSet(charactersIn: ".")
    // source string, isDexcom?
    let whiteListSources = [
        "loop" : false,
        "bgmtool" : false,
        ]
    // bundleId string, isDexcom?
    let whiteListBundleIds = [
        "com.dexcom.share2" : true,
        "com.dexcom.cgm" : true,
        "com.dexcom.g6" : true,
        "org.nightscoutfoundation.spike" : false,
        ]
    // bundleId component string, isDexcom?
    let whiteListBundleComponents = [
        "loopkit" : false
    ]
    let kTypeCbg = "cbg"
    let kTypeSmbg = "smbg"
    let bundleIdLowercased = bundleId.lowercased()
    let sourceNameLowercased = sourceName.lowercased()
    
    // First check whitelisted sources for those we know are cbg sources...
    //let sourceName = sample.sourceRevision.source.name
    var isDexcom = whiteListSources[sourceNameLowercased]
    if isDexcom != nil {
        return (kTypeCbg, isDexcom!)
    }
    
    // source name prefixed with "dexcom" also counts to catch European app with source == "Dexcom 6"
    if sourceNameLowercased.hasPrefix("dexcom") {
        return (kTypeCbg, true)
    }
    
    // Also mark glucose data from HK as CGM data if any of the following are true:
    // (1) HKSource.bundleIdentifier is one of the following: com.dexcom.Share2, com.dexcom.CGM, com.dexcom.G6, or org.nightscoutfoundation.spike.
    
    //let bundleId = sample.sourceRevision.source.bundleIdentifier
    isDexcom = whiteListBundleIds[bundleIdLowercased]
    if isDexcom != nil {
        return (kTypeCbg, isDexcom!)
    }
    
    // (2) HKSource.bundleIdentifier ends in .Loop
    if bundleIdLowercased.hasSuffix(".loop") {
        return (kTypeCbg, false)
    }
    
    // (3) HKSource.bundleIdentifier has loopkit as one of the (dot separated) components
    let bundleIdComponents = bundleIdLowercased.components(separatedBy: bundleIdSeparators)
    for comp in bundleIdComponents {
        isDexcom = whiteListBundleComponents[comp]
        if isDexcom != nil {
            return (kTypeCbg, isDexcom!)
        }
    }
    
    // Assume everything else is smbg!
    return (kTypeSmbg, false)
}

let testCases = [
    (sourceName: "Dexcom", bundleId: "com.dexcom.Share2", type: "cbg", isDexcom: true),
    (sourceName: "Dexcom", bundleId: "com.dexcom.CGM", type: "cbg", isDexcom: true),
    (sourceName: "Dexcom", bundleId: "com.dexcom.G6", type: "cbg", isDexcom: true),
    (sourceName: "Loop", bundleId: "any.bundle.id", type: "cbg", isDexcom: false),
    (sourceName: "Woop", bundleId: "any.bundle.loopkit", type: "cbg", isDexcom: false),
    (sourceName: "Zip", bundleId: "loopkit.bundle.loopkit", type: "cbg", isDexcom: false),
    (sourceName: "Mup", bundleId: "my.loopkit.bundle", type: "cbg", isDexcom: false),
    (sourceName: "Mup", bundleId: "my.notloopkit.bundle", type: "smbg", isDexcom: false),
    (sourceName: "Spike For iPhone/iPod Touch", bundleId: "org.Nightscoutfoundation.spike", type: "cbg", isDexcom: false),
    (sourceName: "Dexcom 6", bundleId: "com.whatever", type: "cbg", isDexcom: true),
]

for (sourceName, bundleId, type, isDexcom) in testCases {
    let lookup = determineTypeOfBG(sourceName: sourceName, bundleId: bundleId)
    if lookup.type != type {
        print("FAIL: sourceName: \(sourceName), bundleId: \(bundleId) should not be \(lookup.type)!")
    } else if lookup.isDexcom != isDexcom {
        print("FAIL: sourceName: \(sourceName), bundleId: \(bundleId) isDexcom should be \(lookup.isDexcom)!")
    } else {
        print("PASS: sourceName: \(sourceName), bundleId: \(bundleId) checks as \(lookup.type), isDexcom = \(lookup.isDexcom)!")
    }
    
}
