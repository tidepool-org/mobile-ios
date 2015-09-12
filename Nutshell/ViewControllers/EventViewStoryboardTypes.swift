//
//  EventViewStoryboardTypes.swift
//  Nutshell
//
//  Created by Larry Kenyon on 9/12/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import Foundation

// MARK: Types

struct EventViewStoryboard {
    
    struct TableViewCellIdentifiers {
        static let eventItemCell = "eventItemCell"
        static let eventListCell = "eventListCell"
    }

    // MARK: SegueHandlerType
    
    struct SegueIdentifiers {
        static let EventItemDetailSegue = "EventItemDetailSegue"
        static let EventGroupSegue = "EventGroupSegue"
    }
}

