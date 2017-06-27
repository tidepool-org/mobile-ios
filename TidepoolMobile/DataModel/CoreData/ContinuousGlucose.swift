//
//  ContinuousGlucose.swift
//  TidepoolMobile
//
//  Created by Brian King on 9/15/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation
import CoreData
import SwiftyJSON

class ContinuousGlucose: CommonData {

    override class func fromJSON(_ json: JSON, moc: NSManagedObjectContext) -> ContinuousGlucose? {
        if let entityDescription = NSEntityDescription.entity(forEntityName: "ContinuousGlucose", in: moc) {
            let me = ContinuousGlucose(entity: entityDescription, insertInto: nil) 
            
            if let value = json["value"].number {
                me.value = value
            } else {
                print("cbg record with missing value skipped")
                return nil
            }

            if let units = json["units"].string {
                if units != "mmol/L" {
                    print("cbg record with incorrect units skipped: \(units)")
                    return nil
                }
            } else {
                print("cbg record with no units field, assuming mmol/L - value: \(String(describing: me.value))")
            }
            
            me.isig = json["isig"].string
            
            return me
        }
        
        return nil
    }
}
