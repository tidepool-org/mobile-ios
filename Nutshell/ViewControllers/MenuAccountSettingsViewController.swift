//
//  MenuAccountSettingsViewController.swift
//  Nutshell
//
//  Created by Larry Kenyon on 9/14/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import UIKit
import CocoaLumberjack

class MenuAccountSettingsViewController: UIViewController, UITextViewDelegate {

    var didSelectSwitchProfile = false
    
    @IBOutlet weak var loginAccount: UILabel!
    @IBOutlet weak var versionString: NutshellUILabel!
    @IBOutlet weak var usernameLabel: NutshellUILabel!
    @IBOutlet weak var sidebarView: UIView!
    @IBOutlet weak var healthKitSwitch: UISwitch!
    @IBOutlet weak var healthKitLabel: NutshellUILabel!
    @IBOutlet weak var healthStatusContainerView: UIStackView!
    @IBOutlet weak var healthStatusLine1: UILabel!
    @IBOutlet weak var healthStatusLine2: UILabel!
    @IBOutlet weak var healthStatusLine3: UILabel!
    
    @IBOutlet weak var privacyTextField: UITextView!
    var hkTimeRefreshTimer: Timer?
    fileprivate let kHKTimeRefreshInterval: TimeInterval = 30.0

    //
    // MARK: - Base Methods
    //

    override func viewDidLoad() {
        super.viewDidLoad()
        let curService = APIConnector.connector().currentService!
        if curService == "Production" {
            versionString.text = "v" + UIApplication.appVersion()
        } else{
            versionString.text = "v" + UIApplication.appVersion() + " on " + curService
        }
        loginAccount.text = NutDataController.sharedInstance.currentUserName
        
        //healthKitSwitch.tintColor = Styles.brightBlueColor
        //healthKitSwitch.thumbTintColor = Styles.whiteColor
        healthKitSwitch.onTintColor = Styles.brightBlueColor

        let notificationCenter = NotificationCenter.default
        notificationCenter.addObserver(self, selector: #selector(MenuAccountSettingsViewController.handleUploaderNotification(_:)), name: NSNotification.Name(rawValue: HealthKitDataUploader.Notifications.Updated), object: nil)
    }

    deinit {
        let nc = NotificationCenter.default
        nc.removeObserver(self, name: nil, object: nil)
        hkTimeRefreshTimer?.invalidate()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func menuWillOpen() {
        // Late binding here because profile fetch occurs after login complete!
        // Treat this like viewWillAppear...
        usernameLabel.text = NutDataController.sharedInstance.userFullName
        
        configureHKInterface()
    }
    
    //
    // MARK: - Navigation
    //

    @IBAction func done(_ segue: UIStoryboardSegue) {
        print("unwind segue to menuaccount done!")
    }

    //
    // MARK: - Button/switch handling
    //
    
    @IBAction func switchProfileTapped(_ sender: AnyObject) {
        didSelectSwitchProfile = true
        self.hideSideMenuView()
    }
    
    @IBAction func supportButtonHandler(_ sender: AnyObject) {
        APIConnector.connector().trackMetric("Clicked Tidepool Support (Hamburger)")
        let url = URL(string: "support.tidepool.org")
        UIApplication.shared.openURL(url!)
    }
    
    @IBAction func privacyButtonTapped(_ sender: Any) {
        APIConnector.connector().trackMetric("Clicked Privacy and Terms (Hamburger)")
        let url = URL(string: "tidepool.org/legal/")
        UIApplication.shared.openURL(url!)
    }
    
    @IBAction func logOutTapped(_ sender: AnyObject) {
        APIConnector.connector().trackMetric("Clicked Log Out (Hamburger)")
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.logout()
    }
    
    //
    // MARK: - Healthkit Methods
    //
    
    @IBAction func enableHealthData(_ sender: AnyObject) {
        if let enableSwitch = sender as? UISwitch {
            if enableSwitch.isOn {
                enableHealthKitInterfaceForCurrentUser()
            } else {
                NutDataController.sharedInstance.disableHealthKitInterface()
            }
            configureHKInterface()
        }
    }

    fileprivate func startHKTimeRefreshTimer() {
        if hkTimeRefreshTimer == nil {
            hkTimeRefreshTimer = Timer.scheduledTimer(timeInterval: kHKTimeRefreshInterval, target: self, selector: #selector(MenuAccountSettingsViewController.nextHKTimeRefresh), userInfo: nil, repeats: true)
        }
    }

    func stopHKTimeRefreshTimer() {
        hkTimeRefreshTimer?.invalidate()
        hkTimeRefreshTimer = nil
    }

    func nextHKTimeRefresh() {
        DDLogInfo("nextHKTimeRefresh")
        configureHKInterface()
    }
    
    internal func handleUploaderNotification(_ notification: Notification) {
        DDLogInfo("handleUploaderNotification: \(notification.name)")
        configureHKInterface()
    }

    fileprivate func configureHKInterface() {
        // Late binding here because profile fetch occurs after login complete!
        usernameLabel.text = NutDataController.sharedInstance.userFullName
        let hkCurrentEnable = appHealthKitConfiguration.healthKitInterfaceEnabledForCurrentUser()
        healthKitSwitch.isOn = hkCurrentEnable
        if hkCurrentEnable {
            self.configureHealthStatusLines()
            // make sure timer is turned on to prevent a stale interface...
            startHKTimeRefreshTimer()
        } else {
            stopHKTimeRefreshTimer()
        }
        
        var hideHealthKitUI = false
        // Note: Right now this is hard-wired true
        if !AppDelegate.healthKitUIEnabled {
            hideHealthKitUI = true
        }
        // The isDSAUser variable only becomes valid after user profile fetch, so if it is not set, assume true. Otherwise use it as main control of whether we show the HealthKit UI.
        if let isDSAUser = NutDataController.sharedInstance.isDSAUser {
            if !isDSAUser {
                hideHealthKitUI = true
            }
        }
        healthKitSwitch.isHidden = hideHealthKitUI
        healthKitLabel.isHidden = hideHealthKitUI
        healthStatusContainerView.isHidden = hideHealthKitUI || !hkCurrentEnable
    }
    
    fileprivate func enableHealthKitInterfaceForCurrentUser() {
        if appHealthKitConfiguration.healthKitInterfaceConfiguredForOtherUser() {
            // use dialog to confirm delete with user!
            let curHKUserName = appHealthKitConfiguration.healthKitUserTidepoolUsername() ?? "Unknown"
            //let curUserName = usernameLabel.text!
            let titleString = "Are you sure?"
            let messageString = "A different account (" + curHKUserName + ") is currently associated with Health Data on this device"
            let alert = UIAlertController(title: titleString, message: messageString, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { Void in
                self.healthKitSwitch.isOn = false
                return
            }))
            alert.addAction(UIAlertAction(title: "Change Account", style: .default, handler: { Void in
                NutDataController.sharedInstance.enableHealthKitInterface()
            }))
            self.present(alert, animated: true, completion: nil)
        } else {
            NutDataController.sharedInstance.enableHealthKitInterface()
        }
    }
    
    let healthKitUploadStatusMostRecentSamples: String = "Uploading last 14 days of Dexcom data\u{2026}"
    let healthKitUploadStatusUploadPausesWhenPhoneIsLocked: String = "FYI upload pauses when phone is locked"
    let healthKitUploadStatusDaysUploaded: String = "%d of %d days"
    let healthKitUploadStatusUploadingCompleteHistory: String = "Uploading complete history of Dexcom data"
    let healthKitUploadStatusLastUploadTime: String = "Last reading %@"
    let healthKitUploadStatusNoDataAvailableToUpload: String = "No data available to upload"
    let healthKitUploadStatusDexcomDataDelayed3Hours: String = "Dexcom data from Health is delayed 3 hours"

    fileprivate func configureHealthStatusLines() {
        let hkDataUploader = HealthKitDataUploader.sharedInstance
        var phase = hkDataUploader.uploadPhaseBloodGlucoseSamples
        
        // if we haven't actually uploaded a first historical sample, act like we're still doing most recent samples...
        if phase == .historicalSamples && hkDataUploader.totalDaysHistoricalBloodGlucoseSamples == 0 {
            phase = .mostRecentSamples
        }

        switch phase {
        case .mostRecentSamples:
            healthStatusLine1.text = healthKitUploadStatusMostRecentSamples
            healthStatusLine2.text = healthKitUploadStatusUploadPausesWhenPhoneIsLocked
            healthStatusLine3.text = ""
        case .historicalSamples:
            healthStatusLine1.text = healthKitUploadStatusUploadingCompleteHistory
            var healthKitUploadStatusDaysUploadedText = ""
            if hkDataUploader.totalDaysHistoricalBloodGlucoseSamples > 0 {
                healthKitUploadStatusDaysUploadedText = String(format: healthKitUploadStatusDaysUploaded, hkDataUploader.currentDayHistoricalBloodGlucoseSamples, hkDataUploader.totalDaysHistoricalBloodGlucoseSamples)
            }
            healthStatusLine2.text = healthKitUploadStatusDaysUploadedText
            healthStatusLine3.text = healthKitUploadStatusUploadPausesWhenPhoneIsLocked
        case .currentSamples:
            if hkDataUploader.totalUploadCountBloodGlucoseSamples > 0 {
                let lastUploadTimeAgoInWords = hkDataUploader.lastUploadTimeBloodGlucoseSamples.timeAgoInWords(Date())
                healthStatusLine1.text = String(format: healthKitUploadStatusLastUploadTime, lastUploadTimeAgoInWords)
            } else {
                healthStatusLine1.text = healthKitUploadStatusNoDataAvailableToUpload
            }
            healthStatusLine2.text = healthKitUploadStatusDexcomDataDelayed3Hours
            healthStatusLine3.text = ""
        }
    }
    
    
}
