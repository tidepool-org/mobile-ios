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

import Foundation
import CocoaLumberjack
import SwiftyJSON

// TODO: unclear we need this - perhaps just use our User class, backed by core data model...
class BlipUser {
    
    var fullName: String?
    let userid: String
    var patient: BlipPatient?
    var bgTargetLow: NSNumber?
    var bgTargetHigh: NSNumber?
    
    init(userid: String) {
        self.userid = userid
    }
 
    init(user: User) {
        self.userid = user.userid!
        if user.accountIsDSA != nil {
            self.patient = BlipPatient()
        }
        self.fullName = user.fullName
    }

    /// Indicates whether the current user logged in is associated with a Data Storage Account
    var isDSAUser: Bool {
        return patient != nil
    }

    func processProfileJSON(_ json: JSON) {
        DDLogInfo("profile json: \(json)")
        fullName = json["fullName"].string
        let patient = json["patient"]
        if patient != JSON.null {
            self.patient = BlipPatient() // use empty patient for now
        }
    }

    func processUserDict(_ userDict: NSDictionary) {
        if let name = userDict["fullName"] as? String {
            self.fullName = name
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        if let patientDict = userDict["patient"] as? NSDictionary {
            let patient = BlipPatient()
            if let birthdayString = patientDict["birthday"] as? String,
               let birthday = dateFormatter.date(from: birthdayString) {
                patient.birthday = birthday
            } else {
                DDLogInfo("Patient birthday not present or invalid: \(String(describing: patientDict["birthday"]))")
            }
            if let diagnosisDateString = patientDict["diagnosisDate"] as? String,
               let diagnosisDate = dateFormatter.date(from: diagnosisDateString) {
                patient.diagnosisDate = diagnosisDate
            } else {
                DDLogInfo("Patient diagnosisDate not present or invalid: \(String(describing: patientDict["diagnosisDate"]))")
            }
            if let aboutMe = patientDict["aboutMe"] as? String {
                patient.aboutMe = aboutMe
            }
            if let aboutMe = patientDict["about"] as? String {
                patient.aboutMe = aboutMe
            }
            self.patient = patient
        }
    }
    
    /*
     {
     "bgTarget": {
     "low": 110,
     "high": 130
     },
     "siteChangeSource": "cannulaPrime",
     "units": {
     "bg": "mg/dL"
     }
     }
    */
    func processSettingsJSON(_ json: JSON) {
        DDLogInfo("settings json: \(json)")
        self.bgTargetLow = json["bgTarget"]["low"].number
        self.bgTargetHigh = json["bgTarget"]["high"].number
        DDLogInfo("Low: \(String(describing: bgTargetLow)), High: \(String(describing: bgTargetHigh))")
    }

}
