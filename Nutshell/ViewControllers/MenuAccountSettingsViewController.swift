//
//  MenuAccountSettingsViewController.swift
//  Nutshell
//
//  Created by Larry Kenyon on 9/14/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import UIKit

class MenuAccountSettingsViewController: UIViewController {

    @IBOutlet weak var loginAccount: UILabel!
    @IBOutlet weak var versionString: NutshellUILabel!
    
    @IBOutlet weak var sidebarView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let curService = APIConnector.currentService!
        if curService == "Production" {
            versionString.text = "V" + UIApplication.appVersion()
        } else{
            versionString.text = "V" + UIApplication.appVersion() + " on " + curService
            
        }
        loginAccount.text = NutDataController.controller().currentUserName
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func logOutTapped(sender: AnyObject) {
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        appDelegate.logout()
    }

    @IBAction func termsOfUseTapped(sender: AnyObject) {
        let storyboard = UIStoryboard(name: "EventView", bundle: nil)
        let menuController = storyboard.instantiateViewControllerWithIdentifier("menuTermsVC") as! MenuTermsViewController
        sideMenuController()?.setContentViewController(menuController)
    }
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

    @IBAction func done(segue: UIStoryboardSegue) {
        print("unwind segue to menuaccount done!")
    }

}
