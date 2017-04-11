/*
 * Copyright (c) 2016, Tidepool Project
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
import UIKit
import CocoaLumberjack
import MessageUI
import HealthKit
import FLAnimatedImage

class ConnectToHealthCelebrationViewController: UIViewController {
    
    @IBOutlet weak var animatedImageView: FLAnimatedImageView!
    
    enum Notifications {
        static let DismissButtonTapped = "ConnectToHealthCelebrationViewController-DismissButtonTapped"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let path = Bundle.main.path(forResource: "celebration-animated-dots", ofType: "gif") {
            do {
                let animatedImage = try FLAnimatedImage(animatedGIFData: Data(contentsOf: URL(fileURLWithPath: path)))
                animatedImageView.animatedImage = animatedImage
            } catch {
                DDLogError("Unable to load animated gifs!")
                
            }
        }
    }
    
    @IBAction func dismissButtonTapped(_ sender: AnyObject) {
        self.performSegue(withIdentifier: "unwindSegueToLogin", sender: self)
    }
}
