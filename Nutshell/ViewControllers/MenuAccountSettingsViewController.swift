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
    
    @IBOutlet weak var termsOfUseView: UIView!
    @IBOutlet weak var sidebarView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        termsOfUseView.hidden = true
        versionString.text = UIApplication.appVersion() + " on " + APIConnector.currentService!
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

    private func showTerms(show: Bool) {
        termsOfUseView.hidden = !show
        sidebarView.hidden = show
        if self.revealViewController() != nil {
            if show {
                self.revealViewController().setFrontViewPosition(FrontViewPosition.RightMost, animated: true)
            } else {
                self.revealViewController().setFrontViewPosition(FrontViewPosition.Right, animated: true)
            }
        }
    }
    
    @IBAction func termsOfUseTapped(sender: AnyObject) {
        showTerms(true)
    }
    
    @IBAction func closeTermsButtonHandler(sender: AnyObject) {
        showTerms(false)
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
