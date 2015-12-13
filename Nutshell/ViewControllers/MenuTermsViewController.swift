//
//  MenuTermsViewController.swift
//  Nutshell
//
//  Created by Larry Kenyon on 12/13/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import UIKit

class MenuTermsViewController: UIViewController, ENSideMenuDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        self.sideMenuController()?.sideMenu?.delegate = self
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func toggleSideMenu(sender: AnyObject) {
        //toggleSideMenuView()
        let storyboard = UIStoryboard(name: "EventView", bundle: nil)
        let eventListController = storyboard.instantiateViewControllerWithIdentifier("eventListVC") as! EventListTableViewController
        sideMenuController()?.setContentViewController(eventListController)
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
        print("MenuTermsViewController sideMenuWillOpen")
    }
    
    func sideMenuWillClose() {
        print("MenuTermsViewController sideMenuWillClose")
    }
    
    func sideMenuShouldOpenSideMenu() -> Bool {
        print("MenuTermsViewController sideMenuShouldOpenSideMenu")
        return false
    }
    
    func sideMenuDidClose() {
        print("MenuTermsViewController sideMenuDidClose")
    }
    
    func sideMenuDidOpen() {
        print("MenuTermsViewController sideMenuDidOpen")
    }

}
