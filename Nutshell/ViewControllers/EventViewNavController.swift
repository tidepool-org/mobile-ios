//
//  EventViewNavController.swift
//  Nutshell
//
//  Created by Larry Kenyon on 12/13/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import UIKit

class EventViewNavController: ENSideMenuNavigationController, ENSideMenuDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        let storyboard = UIStoryboard(name: "EventView", bundle: nil)
        let menuController = storyboard.instantiateViewControllerWithIdentifier("sidebarController") as! MenuAccountSettingsViewController
        sideMenu = ENSideMenu(sourceView: self.view, menuViewController: menuController, menuPosition:.Left)

        //sideMenu?.delegate = self //optional
        sideMenu?.menuWidth = 235.0 // optional, default is 160
        //sideMenu?.bouncingEnabled = false
        //sideMenu?.allowPanGesture = false
        // make navigation bar showing over side menu
        view.bringSubviewToFront(navigationBar)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

    // MARK: - ENSideMenu Delegate
    func sideMenuWillOpen() {
        print("sideMenuWillOpen")
    }
    
    func sideMenuWillClose() {
        print("sideMenuWillClose")
    }
    
    func sideMenuDidClose() {
        print("sideMenuDidClose")
    }
    
    func sideMenuDidOpen() {
        print("sideMenuDidOpen")
    }

}
