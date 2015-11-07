//
//  MenuAccountSettingsViewController.swift
//  Nutshell
//
//  Created by Larry Kenyon on 9/14/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import UIKit

class MenuAccountSettingsViewController: UIViewController {

    @IBOutlet weak var glucoseSettingsView: UIView!
    @IBOutlet weak var bottomSettingsView: NutshellUIView!
    @IBOutlet weak var loginAccount: UILabel!
    @IBOutlet weak var versionString: NutshellUILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        glucoseSettingsView.hidden = true;
        bottomSettingsView.hidden = false;
        
        versionString.text = UIApplication.appVersion() + " on " + APIConnector.currentService!
        
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        loginAccount.text = appDelegate.API?.currentUserId
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func logOutTapped(sender: AnyObject) {
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        appDelegate.logout()
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
