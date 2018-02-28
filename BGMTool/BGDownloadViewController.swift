//
//  BGDownloadViewController.swift
//  BGMTool
//
//  Copyright © 2018 Tidepool. All rights reserved.
//

import UIKit
import Alamofire
import SwiftyJSON
import CocoaLumberjack

class BGDownloadViewController: UIViewController {
    
    @IBOutlet weak var logInScene: UIView!
    
    @IBOutlet weak var loginViewContainer: UIControl!
    @IBOutlet weak var inputContainerView: UIView!
    
    @IBOutlet weak var emailTextField: TidepoolMobileUITextField!
    @IBOutlet weak var passwordTextField: TidepoolMobileUITextField!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var errorFeedbackLabel: TidepoolMobileUILabel!
    @IBOutlet weak var serviceButton: UIButton!

    @IBOutlet weak var downloadDataViewContainer: UIView!
    @IBOutlet weak var itemsDownloadedLabel: UILabel!
    @IBOutlet weak var itemsLabel: UILabel!
    
    // only one of the following shows...
    @IBOutlet weak var downloadProgressLabel: UILabel!
    @IBOutlet weak var downloadVerifyButtonContainerView: UIView!
    @IBOutlet weak var daysToDownloadTextField: UITextField!
    
    @IBOutlet weak var startDateLabel: UILabel!
    @IBOutlet weak var endDateLabel: UILabel!
    @IBOutlet weak var downloadButton: TPMenuButton!
    @IBOutlet weak var verifyButton: TPMenuButton!
    
    @IBOutlet weak var loginIndicator: UIActivityIndicatorView!
    @IBOutlet weak var networkOfflineLabel: TidepoolMobileUILabel!
    

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    deinit {
        // Re-enable idle timer (screen locking) when the controller is gone
        UIApplication.shared.isIdleTimerDisabled = false

        let nc = NotificationCenter.default
        nc.removeObserver(self, name: nil, object: nil)
        
    }

    var server: String = "Production"
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
      
        configureAsLoggedIn(APIConnector.connector().serviceAvailable())

        // Disable idle timer (screen locking) while BG Downloader is current screen
        UIApplication.shared.isIdleTimerDisabled = true

        self.loginIndicator.color = UIColor.black
        passwordTextField.keyboardAppearance = UIKeyboardAppearance.dark
        emailTextField.keyboardAppearance = UIKeyboardAppearance.dark
        
        let borderColor = Styles.alt2LightGreyColor
        
        passwordTextField.layer.borderColor = borderColor.cgColor
        passwordTextField.layer.borderWidth = 1.0
        //passwordTextField.layer.cornerRadius = 2.0
        
        emailTextField.layer.borderColor = borderColor.cgColor
        emailTextField.layer.borderWidth = 1.0
        //emailTextField.layer.cornerRadius = 2.0
        
        //emailTextField.text = ""
        //passwordTextField.text = ""
        
        serviceButton.setTitle(APIConnector.connector().currentService, for: .normal)

        let notificationCenter = NotificationCenter.default
        
        notificationCenter.addObserver(self, selector: #selector(BGDownloadViewController.textFieldDidChange), name: NSNotification.Name.UITextFieldTextDidChange, object: nil)
        updateButtonStates()
        
        notificationCenter.addObserver(self, selector: #selector(BGDownloadViewController.keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        notificationCenter.addObserver(self, selector: #selector(BGDownloadViewController.keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(BGDownloadViewController.reachabilityChanged(_:)), name: ReachabilityChangedNotification, object: nil)
        configureForReachability()
        resetDownloadUI()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        
        // Re-enable idle timer (screen locking) when the controller disappears
        UIApplication.shared.isIdleTimerDisabled = false
        
        // kill any download in progress
        if downloadInProgress {
            HealthKitBGInterface.sharedInstance.abortSyncInProgress()
            downloadInProgress = false
        }
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        appDelegate.logout()
        // uncomment to wipe password, but keep login email
        //self.passwordTextField.text = ""

        super.viewDidDisappear(animated)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    func reachabilityChanged(_ note: Notification) {
        DispatchQueue.main.async {
            self.configureForReachability()
        }
    }

    private func configureForReachability() {
        let connected = APIConnector.connector().isConnectedToNetwork()
        inputContainerView.isHidden = !connected
        networkOfflineLabel.isHidden = connected
    }

    // delay manual layout until we know actual size of container view (at viewDidLoad it will be the current storyboard size)
    private var subviewsInitialized = false
    override func viewDidLayoutSubviews() {
        //DDLogInfo("viewDidLayoutSubviews: \(self.logInScene.frame)")
        
        if (subviewsInitialized) {
            return
        }
        subviewsInitialized = true
        logInScene.setNeedsLayout()
        logInScene.layoutIfNeeded()
        // For the login button ;-)
        logInScene.checkAdjustSubviewSizing()
    }

    //
    // MARK: - Button and text field handlers
    //
    
    @IBAction func tapOutsideFieldHandler(_ sender: AnyObject) {
        passwordTextField.resignFirstResponder()
        emailTextField.resignFirstResponder()
        daysToDownloadTextField.resignFirstResponder()
    }
    
    @IBAction func passwordEnterHandler(_ sender: AnyObject) {
        passwordTextField.resignFirstResponder()
        if (loginButton.isEnabled) {
            login_button_tapped(self)
        }
    }
    
    @IBAction func emailEnterHandler(_ sender: AnyObject) {
        passwordTextField.becomeFirstResponder()
    }
    
    @IBAction func login_button_tapped(_ sender: AnyObject) {
        updateButtonStates()
        tapOutsideFieldHandler(self)
        loginIndicator.startAnimating()
        
        APIConnector.connector().login(emailTextField.text!,
                                       password: passwordTextField.text!) { (result:Alamofire.Result<User>, statusCode: Int?) -> (Void) in
                                        //DDLogInfo("Login result: \(result)")
                                        self.processLoginResult(result, statusCode: statusCode)
        }
    }
    
    fileprivate func processLoginResult(_ result: Alamofire.Result<User>, statusCode: Int?) {
        self.loginIndicator.stopAnimating()
        if (result.isSuccess) {
            if let user=result.value {
                DDLogInfo("Login success: \(user)")
                self.configureAsLoggedIn(true)
            } else {
                // This should not happen- we should not succeed without a user!
                DDLogError("Fatal error: No user returned!")
            }
        } else {
            DDLogError("login failed! Error: " + result.error.debugDescription)
            var errorText = "Check your Internet connection!"
            if let statusCode = statusCode {
                if statusCode == 401 {
                    errorText = NSLocalizedString("loginErrUserOrPassword", comment: "Wrong email or password!")
                }
            }
            self.errorFeedbackLabel.text = errorText
            self.errorFeedbackLabel.isHidden = false
            //self.passwordTextField.text = ""
        }
    }
    
    func textFieldDidChange() {
        updateButtonStates()
    }
    
    private func configureAsLoggedIn(_ loggedIn: Bool) {
        NSLog("TODO: support passing false!")
        downloadDataViewContainer.isHidden = !loggedIn
        loginViewContainer.isHidden = loggedIn
        updateDownloadUI()
    }
    
    private func updateButtonStates() {
        errorFeedbackLabel.isHidden = true
        // login button
        if (emailTextField.text != "" && passwordTextField.text != "") {
            loginButton.isEnabled = true
            loginButton.setTitleColor(UIColor.white, for:UIControlState())
        } else {
            loginButton.isEnabled = false
            loginButton.setTitleColor(UIColor.lightGray, for:UIControlState())
        }
    }
    
    @IBAction func selectServiceButtonHandler(_ sender: Any) {
        let api = APIConnector.connector()
        let actionSheet = UIAlertController(title: "Server" + " (" + api.currentService! + ")", message: "", preferredStyle: .actionSheet)
        for serverName in api.kSortedServerNames {
            actionSheet.addAction(UIAlertAction(title: serverName, style: .default, handler: { Void in
                api.switchToServer(serverName)
                self.serviceButton.setTitle(api.currentService, for: .normal)
            }))
        }
        self.present(actionSheet, animated: true, completion: nil)
    }
    
    //
    // MARK: - Download ui handling
    //
    
    private var downloadInProgress = false
    private var verifyMode = false
    private var downloadCompleted = false
    private var startDate: Date?
    private var finishDate: Date?
    private var startBlockDate: Date?
    private var endBlockDate: Date?
    private var itemsDownloaded: Int = 0

    // download 10 days at a time
    //private let kDownloadBlockTime: TimeInterval = 60*60*24*10
    private let kDownloadBlockTime: TimeInterval = 60*60*24*1

    // download last 3 years of data
    private var totalDownloadTimeInterval: TimeInterval = 60*60*24*365*3
    private let kDefaultTotalDownloadTimeInterval: TimeInterval = 60*60*24*365*3
    private let kDefaultDownloadDays: Int = 365*3
    private let kMaxDownloadDays: Int = 365*5
    private let kMinDownloadDays: Int = 1

    @IBAction func daysToDownloadEnterHandler(_ sender: Any) {
        daysToDownloadTextField.resignFirstResponder()
        syncDaysToDownload()
    }

    private func syncDaysToDownload() {
        if let daysToDownloadText = daysToDownloadTextField.text {
            if let daysToDownload = Int(daysToDownloadText) {
                if daysToDownload >= kMinDownloadDays && daysToDownload <= kMaxDownloadDays {
                    totalDownloadTimeInterval = TimeInterval(daysToDownload) * 60*60*24
                    return
                }
            }
        }
        daysToDownloadTextField.text = String(kDefaultTotalDownloadTimeInterval)
        totalDownloadTimeInterval = kDefaultTotalDownloadTimeInterval
    }
    
    @IBAction func downloadButtonHandler(_ sender: Any) {
        tapOutsideFieldHandler(self)
        syncDaysToDownload()
        if !HealthKitBGInterface.sharedInstance.checkInterfaceEnabled() {
            return
        }
        
        if !downloadInProgress && !downloadCompleted {
            downloadInProgress = true
            downloadCompleted = false
            verifyMode = false
            updateDownloadUI()
            downloadNextBlock()
        }
    }
    
    @IBAction func verifyButtonHandler(_ sender: Any) {
        tapOutsideFieldHandler(self)
        syncDaysToDownload()
        if !HealthKitBGInterface.sharedInstance.checkInterfaceEnabled() {
            return
        }
        
        if !downloadInProgress && !downloadCompleted {
            downloadInProgress = true
            downloadCompleted = false
            verifyMode = true
            updateDownloadUI()
            downloadNextBlock()
        }
    }
    
    private func downloadNextBlock() {
        if startDate == nil || startBlockDate == nil {
            self.startDate = Date()
            self.finishDate = self.startDate!.addingTimeInterval(-totalDownloadTimeInterval)
            self.endBlockDate = self.startDate
        } else {
            // start where we left off
            self.endBlockDate = self.startBlockDate
        }
        
        self.startBlockDate = endBlockDate!.addingTimeInterval(-kDownloadBlockTime)
        let completeCompare = endBlockDate!.compare(finishDate!)
        if completeCompare != .orderedDescending {
            downloadCompleted = true
        } else {
            let lastBlockCompare = startBlockDate!.compare(finishDate!)
            // for last block, don't start before the end date...
            if lastBlockCompare == .orderedAscending {
                startBlockDate = finishDate!
            }
        }
    
        updateDownloadUI()
        if !downloadCompleted {
            HealthKitBGInterface.sharedInstance.syncTidepoolData(from: startBlockDate!, to: endBlockDate!, verifyOnly: verifyMode) {
                (itemsDownloaded) -> Void in
                self.itemsDownloaded += itemsDownloaded
                // recurse until complete!
                self.downloadNextBlock()
            }
        }
    }
    
    private func resetDownloadUI() {
        downloadInProgress = false
        downloadCompleted = false
        verifyMode = false
        startBlockDate = nil
        endBlockDate = nil
        itemsDownloaded = 0
       // reset download UI
        updateDownloadUI()
    }

    private func updateDownloadUI() {
    
        if downloadInProgress || downloadCompleted {
            downloadVerifyButtonContainerView.isHidden = true
            downloadProgressLabel.isHidden = false
            if verifyMode {
                downloadProgressLabel.text = downloadCompleted ? "Verify complete!" : "Verify in progress..."
                itemsLabel.text = "Healthkit items not in Tidepool"
            } else {
                downloadProgressLabel.text = downloadCompleted ? "Download complete!" : "Download in progress..."
                itemsLabel.text = "Tidepool items downloaded to HK"
            }
        } else {
            downloadVerifyButtonContainerView.isHidden = false
            downloadProgressLabel.isHidden = true
        }
        
        if let started = startBlockDate, let ended = endBlockDate {
            var dateString = DateFormatter.localizedString(from: started, dateStyle: .medium, timeStyle: .short)
            self.startDateLabel.text = dateString
            dateString = DateFormatter.localizedString(from: ended, dateStyle: .medium, timeStyle: .short)
            self.endDateLabel.text = dateString
        } else {
            startDateLabel.text = ""
            endDateLabel.text = ""
        }
        
        itemsDownloadedLabel.text = String(itemsDownloaded)
    }


    //
    // MARK: - View handling for keyboard
    //
    
    @IBOutlet weak var keyboardPlaceholdHeightConstraint: NSLayoutConstraint!
    private var viewAdjustAnimationTime: Float = 0.25
    private func adjustLogInView(_ keyboardHeight: CGFloat) {
        keyboardPlaceholdHeightConstraint.constant = keyboardHeight
        UIView.animate(withDuration: TimeInterval(viewAdjustAnimationTime), animations: {
            self.logInScene.layoutIfNeeded()
        })
    }
    
    // UIKeyboardWillShowNotification
    func keyboardWillShow(_ notification: Notification) {
        // make space for the keyboard if needed
        let keyboardFrame = (notification.userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        viewAdjustAnimationTime = notification.userInfo![UIKeyboardAnimationDurationUserInfoKey] as! Float
        DDLogInfo("keyboardWillShow, kbd height: \(keyboardFrame.height)")
        adjustLogInView(keyboardFrame.height)
    }
    
    // UIKeyboardWillHideNotification
    func keyboardWillHide(_ notification: Notification) {
        // reposition login view if needed
        self.adjustLogInView(0.0)
    }

    
}

