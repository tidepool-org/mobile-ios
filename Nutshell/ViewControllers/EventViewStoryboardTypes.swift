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
        static let eventItemCell = "eventItemCell"
        static let eventListCell = "eventListCell"
        static let eventListCellNoLoc = "eventListCell"
        static let eventListCellWithLoc = "eventListCellWithLoc"
        static let noteListCell = "noteListCell"
    }

    // MARK: SegueHandlerType
    
    struct SegueIdentifiers {
        static let EventItemDetailSegue = "EventItemDetailSegue"
        static let HomeToAddEventSegue = "HomeToAddEventSegue"
        static let EventGroupSegue = "EventGroupSegue"
        static let EventItemAddSegue = "EventItemAddSegue"
        static let EventItemEditSegue = "EventItemEditSegue"
        static let PhotoDisplaySegue = "PhotoDisplaySegue"
        static let UnwindSegueFromShowPhoto = "UnwindSegueFromShowPhoto"
    }
}

//class SegueFromLeft: UIStoryboardSegue {
//    
//    override func perform() {
//        let src: UIViewController = self.sourceViewController
//        let dst: UIViewController = self.destinationViewController
//        let transition: CATransition = CATransition()
//        let timeFunc : CAMediaTimingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
//        transition.duration = 0.25
//        transition.timingFunction = timeFunc
//        transition.type = kCATransitionPush
//        transition.subtype = kCATransitionFromLeft
//        src.navigationController!.view.layer.addAnimation(transition, forKey: kCATransition)
//        src.navigationController!.pushViewController(dst, animated: false)
//    }
//    
//}
//
//// Note: For iOS 9 you can just hook this up as an unwind segue, but prior iOS releases don't support this. For now, just hook this as a regular segue to another VC - which one shouldn't matter since this just does a pop, although the dest VC will be allocated, it's viewDidLoad won't be called.
//class UnwindSegueFromRight: UIStoryboardSegue {
//    
//    override func perform() {
//        let src: UIViewController = self.sourceViewController
//        let transition: CATransition = CATransition()
//        let timeFunc : CAMediaTimingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionEaseInEaseOut)
//        transition.duration = 0.25
//        transition.timingFunction = timeFunc
//        transition.type = kCATransitionPush
//        transition.subtype = kCATransitionFromRight
//        src.navigationController!.view.layer.addAnimation(transition, forKey: kCATransition)
//        src.navigationController!.popViewControllerAnimated(false)
//    }
//    
//}



