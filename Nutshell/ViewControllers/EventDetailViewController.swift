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
import CoreData
import CocoaLumberjack

class EventDetailViewController: BaseUIViewController {

    @IBOutlet weak var navBar: UINavigationBar!
    @IBOutlet weak var sceneContainerView: NutshellUIView!
    
    
    // Data
    // Note must be set by launching controller in prepareForSegue!
    var note: BlipNote!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // data
     }

     deinit {
        NotificationCenter.default.removeObserver(self)
     }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Set status bar to light color for dark navigationBar
        //UIApplication.shared.statusBarStyle = UIStatusBarStyle.lightContent
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    

    // delay manual layout until we know actual size of container view (at viewDidLoad it will be the current storyboard size)
    private var subviewedInitialized = false
    override func viewDidLayoutSubviews() {
        let frame = self.sceneContainerView.frame
        NSLog("viewDidLayoutSubviews: \(frame)")
        
        if (subviewedInitialized) {
            return
        }
        subviewedInitialized = true


    }
    
        
    // Configure title of navigationBar to given string
    func configureTitleView(_ text: String) {
        if let navItem = self.navBar.topItem {
            navItem.title = note.user?.fullName ?? ""
        }
    }
    
    // close the VC on button press from leftBarButtonItem
    @IBAction func backButtonPressed(_ sender: Any) {
        APIConnector.connector().trackMetric("Clicked Back View Note")
        self.performSegue(withIdentifier: "unwindToDone", sender: self)
        
    }
    

}


