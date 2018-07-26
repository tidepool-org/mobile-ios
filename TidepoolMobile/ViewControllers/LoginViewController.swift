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
import Alamofire
import SwiftyJSON
import CocoaLumberjack

class LoginViewController: BaseUIViewController {

    @IBOutlet weak var logInScene: UIView!
    @IBOutlet weak var logInEntryContainer: UIView!

    @IBOutlet weak var inputContainerView: UIView!
    @IBOutlet weak var offlineMessageContainerView: UIView!
    
    @IBOutlet weak var emailTextField: TidepoolMobileUITextField!
    @IBOutlet weak var passwordTextField: TidepoolMobileUITextField!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var loginIndicator: UIActivityIndicatorView!
    @IBOutlet weak var errorFeedbackLabel: TidepoolMobileUILabel!
    
    @IBOutlet weak var versionLabel: UILabel!
    
    @IBOutlet weak var signUpButton: UIButton!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    deinit {
        let nc = NotificationCenter.default
        nc.removeObserver(self, name: nil, object: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        configureVersion()

        self.signUpButton.setTitleColor(Styles.lightDarkGreyColor, for: .highlighted)
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

        let notificationCenter = NotificationCenter.default

        notificationCenter.addObserver(self, selector: #selector(LoginViewController.textFieldDidChange), name: NSNotification.Name.UITextFieldTextDidChange, object: nil)
        updateButtonStates()
        
        notificationCenter.addObserver(self, selector: #selector(LoginViewController.keyboardWillShow(_:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        notificationCenter.addObserver(self, selector: #selector(LoginViewController.keyboardWillHide(_:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(LoginViewController.reachabilityChanged(_:)), name: ReachabilityChangedNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(LoginViewController.switchedToNewServer(_:)), name: NSNotification.Name(rawValue: "switchedToNewServer"), object: nil)

        configureForReachability()
    }
    
    private func configureVersion() {
        let curService = APIConnector.connector().currentService!
        if curService == "Production" {
            versionLabel.text = "v" + UIApplication.appVersion()
        } else{
            versionLabel.text = "v" + UIApplication.appVersion() + " on " + curService
        }
    }
    
    @objc func reachabilityChanged(_ note: Notification) {
        configureForReachability()
    }
    
    @objc func switchedToNewServer(_ note: Notification) {
        configureVersion()
    }

    fileprivate func configureForReachability() {
        let connected = APIConnector.connector().isConnectedToNetwork()
        inputContainerView.isHidden = !connected
        offlineMessageContainerView.isHidden = connected
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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

    @IBAction func signUpButtonTapped(_ sender: Any) {
        if let url = URL(string: "http://tidepool.org/signup") {
            UIApplication.shared.open(url)
        }
    }
    
    @IBAction func forgotPasswordTapped(_ sender: Any) {
        if let url = URL(string: "https://app.tidepool.org/request-password-reset") {
            UIApplication.shared.open(url)
        }
    }

    @IBAction func debugSettingsTapped(_ sender: AnyObject) {
        self.debugSettings = DebugSettings(presentingViewController: self)
        self.debugSettings?.showDebugMenuActionSheet()
    }
    
    fileprivate func processLoginResult(_ result: Alamofire.Result<User>, statusCode: Int?) {
        self.loginIndicator.stopAnimating()
        if (result.isSuccess) {
            if let user=result.value {
                DDLogInfo("Login success: \(user)")
                self.loginIndicator.startAnimating()
                APIConnector.connector().fetchProfile(TidepoolMobileDataController.sharedInstance.currentUserId!) { (result:Alamofire.Result<JSON>) -> (Void) in
                        DDLogInfo("Profile fetch result: \(result)")
                    self.loginIndicator.stopAnimating()
                    if (result.isSuccess) {
                        if let json = result.value {
                            TidepoolMobileDataController.sharedInstance.processLoginProfileFetch(json)
                        }
                        // if we were able to get a profile, try getting an uploadId
                        let appDelegate = UIApplication.shared.delegate as! AppDelegate
                        appDelegate.setupUIForLoginSuccess()
                     }
                }
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
            self.passwordTextField.text = ""
        }
    }
    
    @objc func textFieldDidChange() {
        updateButtonStates()
    }

    fileprivate func updateButtonStates() {
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

    //
    // MARK: - View handling for keyboard
    //

    @IBOutlet weak var keyboardPlaceholdHeightConstraint: NSLayoutConstraint!
    fileprivate var viewAdjustAnimationTime: Float = 0.25
    fileprivate func adjustLogInView(_ keyboardHeight: CGFloat) {
        keyboardPlaceholdHeightConstraint.constant = keyboardHeight
        UIView.animate(withDuration: TimeInterval(viewAdjustAnimationTime), animations: {
            self.logInScene.layoutIfNeeded()
        }) 
    }
   
    // UIKeyboardWillShowNotification
    @objc func keyboardWillShow(_ notification: Notification) {
        // make space for the keyboard if needed
        let keyboardFrame = (notification.userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue).cgRectValue
        viewAdjustAnimationTime = notification.userInfo![UIKeyboardAnimationDurationUserInfoKey] as! Float
        DDLogInfo("keyboardWillShow, kbd height: \(keyboardFrame.height)")
        adjustLogInView(keyboardFrame.height)
    }
    
    // UIKeyboardWillHideNotification
    @objc func keyboardWillHide(_ notification: Notification) {
        // reposition login view if needed
        self.adjustLogInView(0.0)
    }
    
    fileprivate var debugSettings: DebugSettings?
}
