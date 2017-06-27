//
//  EventItem.swift
//  
//
//  Created by Larry Kenyon on 10/6/15.
//
//

import Foundation
import CoreData


class EventItem: CommonData {
    // override for eventItems that have location too!
    func nutEventIdString() -> String {
        return title ?? ""
    }
}
