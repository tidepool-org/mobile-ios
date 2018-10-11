import UIKit
import SwiftyJSON

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
//func lastStoredTzId() -> String? {
//    return nil
//}
//let currentTimeZoneId = TimeZone.current.identifier
//let lastTimezoneId = lastStoredTzId()
//if currentTimeZoneId != lastTimezoneId {
//    print("timezones unequal!")
//} else {
//    print("timezones match!")
//}
//
//let profileDict: [String: Any] = [
//    "patient": [
//        "birthday": "1953-08-27",
//        "diagnosisType": "prediabetes",
//        "diagnosisDate": "1953-08-27"
//    ],
//    "fullName": "Larry Kenyon"
//]
//
//let addDict: [String: Any] = ["patient": [
//    "biologicalSex": "male"
//    ]
//]
//
//func createJsonData(_ src: [String: Any]) -> Data? {
//    let result: Data?
//    do {
//        result = try JSONSerialization.data(withJSONObject: src, options: [])
//        return result
//    } catch {
//        // return nil to signal failure
//        return nil
//    }
//}
//
//let profileData = createJsonData(profileDict)
//if let profileData = profileData {
//    if let profileJson = String(data: profileData, encoding: .utf8) {
//        print("profile Json: \(profileJson)")
//    }
//}
//let bioSexData = createJsonData(addDict)
//if let bioSexData = bioSexData {
//    if let bioSexJson = String(data: bioSexData, encoding: .utf8) {
//        print("biosex Json: \(bioSexJson)")
//    }
//}
//
//do {
//    var profileJson = try JSON(data: profileData!)
//    do {
//        let addData = try JSON(data: bioSexData!)
//        try profileJson.merge(with: addData)
//        let mergedString = profileJson.rawString()
//        print("merged: \(mergedString ?? "no value!")")
//        let mergedData = try profileJson.rawData()
//        print(String(data: mergedData, encoding: .utf8) ?? "merged doesn't print!")
//    } catch {
//        print("unable to create bio sex Json from data")
//    }
//} catch {
//    print("unable to create profile Json from data")
//}
