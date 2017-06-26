//
//  Note.swift
//  TidepoolMobile
//
//  Created by Brian King on 9/15/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation
import CoreData
import SwiftyJSON

class Note: CommonData {
    override class func fromJSON(_ json: JSON, moc: NSManagedObjectContext) -> Note? {
        if let entityDescription = NSEntityDescription.entity(forEntityName: "Note", in: moc) {
            let me = Note(entity: entityDescription, insertInto: nil)
            
            me.shortText = json["shortText"].string
            me.text = json["text"].string
            me.creatorId = json["creatorId"].string
            me.reference = json["reference"].string
            me.displayTime = TidepoolMobileUtils.dateFromJSON(json["displayTime"].string)
            
            return me
        }
        
        return nil
    }
}
