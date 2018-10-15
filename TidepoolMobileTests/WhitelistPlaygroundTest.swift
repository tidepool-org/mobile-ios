//
//  WhitelistPlaygroundTest.swift
//  TidepoolMobile
//
//  Copyright © 2018 Tidepool. All rights reserved.
//

// Paste into playground to work on whitelisting logic for cbg samples

import UIKit

func determineTypeOfBG(sourceName: String, bundleId: String) -> String {
    let bundleIdSeparators = CharacterSet(charactersIn: ".")
    let whiteListSources = [
        "Loop" : true,
        "BGMTool" : true,
        ]
    let whiteListBundleIds = [
        "com.dexcom.Share2" : true,
        "com.dexcom.CGM" : true,
        "com.dexcom.G6" : true,
        ]
    let whiteListBundleComponents = [
        "loopkit" : true
    ]
    let kTypeCbg = "cbg"
    let kTypeSmbg = "smbg"
    
    // First check whitelisted sources for those we know are cbg sources...
    //let sourceName = sample.sourceRevision.source.name
    if whiteListSources[sourceName] != nil {
        return kTypeCbg
    }
    
    // Also mark glucose data from HK as CGM data if any of the following are true:
    // (1) HKSource.bundleIdentifier is one of the following: com.dexcom.Share2, com.dexcom.CGM, or com.dexcom.G6.
    
    //let bundleId = sample.sourceRevision.source.bundleIdentifier
    if whiteListBundleIds[bundleId] != nil {
        return kTypeCbg
    }
    
    // (2) HKSource.bundleIdentifier ends in .Loop
    if bundleId.hasSuffix(".Loop") {
        return kTypeCbg
    }
    
    // (3) HKSource.bundleIdentifier has loopkit as one of the (dot separated) components
    let bundleIdComponents = bundleId.components(separatedBy: bundleIdSeparators)
    for comp in bundleIdComponents {
        if whiteListBundleComponents[comp] != nil {
            return kTypeCbg
        }
    }
    
    // Assume everything else is smbg!
    return kTypeSmbg
}

let testCases = [
    (sourceName: "Dexcom", bundleId: "com.dexcom.Share2", type: "cbg"),
    (sourceName: "Dexcom", bundleId: "com.dexcom.CGM", type: "cbg"),
    (sourceName: "Dexcom", bundleId: "com.dexcom.G6", type: "cbg"),
    (sourceName: "Loop", bundleId: "any.bundle.id", type: "cbg"),
    (sourceName: "Woop", bundleId: "any.bundle.loopkit", type: "cbg"),
    (sourceName: "Zip", bundleId: "loopkit.bundle.loopkit", type: "cbg"),
    (sourceName: "Mup", bundleId: "my.loopkit.bundle", type: "cbg"),
    (sourceName: "Mup", bundleId: "my.notloopkit.bundle", type: "smbg"),
]

for (sourceName, bundleId, type) in testCases {
    let result = determineTypeOfBG(sourceName: sourceName, bundleId: bundleId)
    if result != type {
        print("FAIL: sourceName: \(sourceName), bundleId: \(bundleId) should not be \(result)!")
    } else {
        print("PASS: sourceName: \(sourceName), bundleId: \(bundleId) checks as \(result)!")
    }
    
}
