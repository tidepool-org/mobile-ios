//
//  MenuAccountSettingsViewController.swift
//  Nutshell
//
//  Created by Larry Kenyon on 9/14/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import UIKit

class MenuAccountSettingsViewController: UIViewController, UITextViewDelegate {

    @IBOutlet weak var loginAccount: UILabel!
    @IBOutlet weak var versionString: NutshellUILabel!
    @IBOutlet weak var usernameLabel: NutshellUILabel!
    @IBOutlet weak var sidebarView: UIView!
    @IBOutlet weak var healthKitSwitch: UISwitch!
    @IBOutlet weak var healthKitLabel: NutshellUILabel!
    
    @IBOutlet weak var privacyTextField: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let curService = APIConnector.connector().currentService!
        if curService == "Production" {
            versionString.text = "V" + UIApplication.appVersion()
        } else{
            versionString.text = "V" + UIApplication.appVersion() + " on " + curService
        }
        loginAccount.text = NutDataController.controller().currentUserName
        //let attributes = [NSUnderlineStyleAttributeName: NSUnderlineStyle.StyleSingle.rawValue]
 
        let str = "Privacy and Terms of Use"
        let paragraphStyle = NSParagraphStyle.defaultParagraphStyle().mutableCopy() as! NSMutableParagraphStyle
        paragraphStyle.alignment = .Center
        let attributedString = NSMutableAttributedString(string:str, attributes:[NSFontAttributeName: Styles.mediumVerySmallSemiboldFont, NSForegroundColorAttributeName: Styles.blackColor, NSParagraphStyleAttributeName: paragraphStyle])
        attributedString.addAttribute(NSLinkAttributeName, value: NSURL(string: "http://developer.tidepool.io/privacy-policy/")!, range: NSRange(location: 0, length: 7))
        attributedString.addAttribute(NSLinkAttributeName, value: NSURL(string: "http://developer.tidepool.io/terms-of-use/")!, range: NSRange(location: attributedString.length - 12, length: 12))
        privacyTextField.attributedText = attributedString
        privacyTextField.delegate = self
    }
    
    @IBAction func supportButtonHandler(sender: AnyObject) {
        APIConnector.connector().trackMetric("Clicked Tidepool Support (Hamburger)")
        let email = "support@tidepool.org"
        let url = NSURL(string: "mailto:\(email)")
        UIApplication.sharedApplication().openURL(url!)
    }

    func menuWillOpen() {
        // Late binding here because profile fetch occurs after login complete!
        usernameLabel.text = NutDataController.controller().userFullName
        healthKitSwitch.on = appHealthKitConfiguration.healthKitInterfaceEnabledForCurrentUser()
        var hideHealthKitUI = false
        // Note: Right now this is hard-wired true
        if !AppDelegate.healthKitUIEnabled {
            hideHealthKitUI = true
        }
        // The isDSAUser variable only becomes valid after user profile fetch, so if it is not set, assume true. Otherwise use it as main control of whether we show the HealthKit UI.
        if let isDSAUser = NutDataController.controller().isDSAUser {
            if !isDSAUser {
                hideHealthKitUI = true
            }
        }
        healthKitSwitch.hidden = hideHealthKitUI
        healthKitLabel.hidden = hideHealthKitUI
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func logOutTapped(sender: AnyObject) {
        APIConnector.connector().trackMetric("Clicked Log Out (Hamburger)")
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

    @IBAction func done(segue: UIStoryboardSegue) {
        print("unwind segue to menuaccount done!")
    }

    @IBAction func enableHealthData(sender: AnyObject) {
        if let enableSwitch = sender as? UISwitch {
            if enableSwitch.on {
                enableHealthKitInterfaceForCurrentUser()
            } else {
                NutDataController.controller().disableHealthKitInterface()
            }
        }
    }
    
    private func enableHealthKitInterfaceForCurrentUser() {
        if appHealthKitConfiguration.healthKitInterfaceConfiguredForOtherUser() {
            // use dialog to confirm delete with user!
            let curHKUserName = appHealthKitConfiguration.healthKitUserTidepoolUsername() ?? "Unknown"
            //let curUserName = usernameLabel.text!
            let titleString = "Are you sure?"
            let messageString = "A different account (" + curHKUserName + ") is currently associated with Health Data on this device"
            let alert = UIAlertController(title: titleString, message: messageString, preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .Cancel, handler: { Void in
                self.healthKitSwitch.on = false
                return
            }))
            alert.addAction(UIAlertAction(title: "Change Account", style: .Default, handler: { Void in
                NutDataController.controller().enableHealthKitInterface()
            }))
            self.presentViewController(alert, animated: true, completion: nil)
        } else {
            NutDataController.controller().enableHealthKitInterface()
        }
    }
    
    //
    // MARK: - UITextView delegate
    //
    
    // Intercept links in order to track metrics...
    func textView(textView: UITextView, shouldInteractWithURL URL: NSURL, inRange characterRange: NSRange) -> Bool {
        if URL.absoluteString.containsString("privacy-policy") {
            APIConnector.connector().trackMetric("Clicked privacy (Hamburger)")
        } else {
            APIConnector.connector().trackMetric("Clicked Terms of Use (Hamburger)")
        }
        return true
    }
    
}
