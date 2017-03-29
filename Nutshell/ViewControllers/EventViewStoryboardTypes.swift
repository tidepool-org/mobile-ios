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
import QuartzCore

// MARK: Types

struct EventViewStoryboard {
    
    struct TableViewCellIdentifiers {
        static let noteListCell = "noteListCell"
        static let noteDetailCell = "noteDetailCell"
    }

    // MARK: SegueHandlerType
    
    struct SegueIdentifiers {
        static let EventItemAddSegue = "segueToEventAdd"
        static let EventItemEditSegue = "segueToEditView"
        static let EventItemDetailSegue = "segueToEventDetail"
    }
}



