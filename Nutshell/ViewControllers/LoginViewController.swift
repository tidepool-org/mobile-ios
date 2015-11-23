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

class LoginViewController: BaseUIViewController {

    @IBOutlet weak var logInScene: UIView!
    @IBOutlet weak var logInEntryContainer: UIView!

    @IBOutlet weak var inputContainerView: UIView!
    @IBOutlet weak var offlineMessageContainerView: UIView!
    
    @IBOutlet weak var emailTextField: NutshellUITextField!
    @IBOutlet weak var passwordTextField: NutshellUITextField!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var loginIndicator: UIActivityIndicatorView!
    @IBOutlet weak var rememberMeButton: UIButton!
    @IBOutlet weak var errorFeedbackLabel: NutshellUILabel!
    @IBOutlet weak var forgotPasswordLabel: NutshellUILabel!
    
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    deinit {
        let nc = NSNotificationCenter.defaultCenter()
        nc.removeObserver(self, name: nil, object: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let notificationCenter = NSNotificationCenter.defaultCenter()

        notificationCenter.addObserver(self, selector: "textFieldDidChange", name: UITextFieldTextDidChangeNotification, object: nil)
        updateButtonStates()
        
        // forgot password text needs an underline...
        if let forgotText = forgotPasswordLabel.text {
            let forgotStr = NSAttributedString(string: forgotText, attributes:[NSFontAttributeName: forgotPasswordLabel.font, NSUnderlineStyleAttributeName: NSUnderlineStyle.StyleSingle.rawValue])
            forgotPasswordLabel.attributedText = forgotStr
        }
        
        notificationCenter.addObserver(self, selector: "keyboardWillShow:", name: UIKeyboardWillShowNotification, object: nil)
        notificationCenter.addObserver(self, selector: "keyboardWillHide:", name: UIKeyboardWillHideNotification, object: nil)

        NSNotificationCenter.defaultCenter().addObserver(self, selector: "reachabilityChanged:", name: ReachabilityChangedNotification, object: nil)
        configureForReachability()
        
        // Tap all four corners to bring up server selection action sheet
        let width: CGFloat = 100
        let height: CGFloat = width
        corners.append(CGRect(x: 0, y: 0, width: width, height: height))
        corners.append(CGRect(x: self.view.frame.width - width, y: 0, width: width, height: height))
        corners.append(CGRect(x: 0, y: self.view.frame.height - height, width: width, height: height))
        corners.append(CGRect(x: self.view.frame.width - width, y: self.view.frame.height - height, width: width, height: height))
        for (var i = 0; i < corners.count; i++) {
            cornersBool.append(false)
        }
    }
    
    func reachabilityChanged(note: NSNotification) {
        if let appDelegate = UIApplication.sharedApplication().delegate as? AppDelegate, api = appDelegate.API {
            // try token refresh if we are now connected...
            // TODO: change message to "attempting token refresh"?
            if api.isConnectedToNetwork() && api.sessionToken != nil {
                NSLog("Login: attempting to refresh token...")
                api.refreshToken() { succeeded -> (Void) in
                    if succeeded {
                        appDelegate.setupUIForLoginSuccess()
                    } else {
                        NSLog("Refresh token failed, need to log in normally")
                        api.logout() {
                            self.configureForReachability()
                        }
                    }
                }
                return
            }
        }
        configureForReachability()
    }

    private func configureForReachability() {
        if let appDelegate = UIApplication.sharedApplication().delegate as? AppDelegate {
            var connected = true
            if let api = appDelegate.API {
                connected = api.isConnectedToNetwork()
            }
            inputContainerView.hidden = !connected
            offlineMessageContainerView.hidden = connected
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    //
    // MARK: - Button and text field handlers
    //

    @IBAction func tapOutsideFieldHandler(sender: AnyObject) {
        passwordTextField.resignFirstResponder()
        emailTextField.resignFirstResponder()
    }
    
    @IBAction func passwordEnterHandler(sender: AnyObject) {
        passwordTextField.resignFirstResponder()
        if (loginButton.enabled) {
            login_button_tapped(self)
        }
    }

    @IBAction func emailEnterHandler(sender: AnyObject) {
        passwordTextField.becomeFirstResponder()
    }
    
    @IBAction func rememberMeButtonTapped(sender: AnyObject) {
        rememberMeButton.selected = !rememberMeButton.selected
    }
    
    @IBAction func login_button_tapped(sender: AnyObject) {
        updateButtonStates()
        loginIndicator.startAnimating()
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        
        appDelegate.API?.login(emailTextField.text!,
            password: passwordTextField.text!, remember: rememberMeButton.selected,
            completion: { (result:(Alamofire.Result<User>)) -> (Void) in
                print("Login result: \(result)")
                self.loginIndicator.stopAnimating()
                if ( result.isSuccess ) {
                    if let user=result.value {
                        print("login success: \(user)")
                        appDelegate.setupUIForLoginSuccess()

                        if appDelegate.incrementalDataLoadMode {
                            NSLog("DEVELOPMENT SERVER: don't load data at login for development service!")
                            return
                        }
                        
                        // Update the database with the current user info
                        appDelegate.API?.getUserData() { (result) -> (Void) in
                            if result.isSuccess {
                                let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
                                let moc = appDelegate.managedObjectContext
                                DatabaseUtils.updateEvents(moc, eventsJSON: result.value!)
                            } else {
                                print("Failed to get events for user. Error: \(result.error!)")
                            }
                        }
                    } else {
                        // This should not happen- we should not succeed without a user!
                        print("Fatal error: No user returned!")
                    }
                } else {
                    print("login failed! Error: " + result.error.debugDescription)
                    var errorText = NSLocalizedString("loginErrUserOrPassword", comment: "Wrong email or password!")
                    if let error = result.error as? NSError {
                        print("NSError: \(error)")
                        if error.code == -1009 {
                            errorText = NSLocalizedString("loginErrOffline", comment: "The Internet connection appears to be offline!")
                        }
                        // TODO: handle network offline!
                    }
                    self.errorFeedbackLabel.text = errorText
                    self.errorFeedbackLabel.hidden = false
                    self.passwordTextField.text = ""
                }
        })
    }
    
    func textFieldDidChange() {
        updateButtonStates()
    }

    private func updateButtonStates() {
        errorFeedbackLabel.hidden = true
        // login button
        if (emailTextField.text != "" && passwordTextField.text != "") {
            loginButton.enabled = true
            loginButton.setTitleColor(UIColor.whiteColor(), forState:UIControlState.Normal)
        } else {
            loginButton.enabled = false
            loginButton.setTitleColor(UIColor.lightGrayColor(), forState:UIControlState.Normal)
        }
    }

    //
    // MARK: - View handling for keyboard
    //

    private var viewAdjustAnimationTime: Float = 0.25
    private func adjustLogInView(centerOffset: CGFloat) {
        
        for c in logInScene.constraints {
            if c.firstAttribute == NSLayoutAttribute.CenterY {
                c.constant = -centerOffset
                break
            }
        }
        UIView.animateWithDuration(NSTimeInterval(viewAdjustAnimationTime)) {
            self.logInScene.layoutIfNeeded()
        }
    }
   
    // UIKeyboardWillShowNotification
    func keyboardWillShow(notification: NSNotification) {
        // make space for the keyboard if needed
        let keyboardFrame = (notification.userInfo![UIKeyboardFrameEndUserInfoKey] as! NSValue).CGRectValue()
        viewAdjustAnimationTime = notification.userInfo![UIKeyboardAnimationDurationUserInfoKey] as! Float
        let loginViewDistanceToBottom = logInScene.frame.height - logInEntryContainer.frame.origin.y - logInEntryContainer.frame.size.height
        let additionalKeyboardRoom = keyboardFrame.height - loginViewDistanceToBottom
        if (additionalKeyboardRoom > 0) {
            self.adjustLogInView(additionalKeyboardRoom)
        }
    }
    
    // UIKeyboardWillHideNotification
    func keyboardWillHide(notification: NSNotification) {
        // reposition login view if needed
        self.adjustLogInView(0.0)
    }

    // MARK: - Debug Config
    
    private var corners: [CGRect] = []
    private var cornersBool: [Bool] = []
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        if let touch = touches.first {
            
            let touchLocation = touch.locationInView(self.view)
            
            var i = 0
            for corner in corners {
                let viewFrame = self.view.convertRect(corner, fromView: self.view)
                
                if CGRectContainsPoint(viewFrame, touchLocation) {
                    cornersBool[i] = true
                    self.checkCorners()
                    return
                }
                
                i++
            }
        }
    }

    func checkCorners() {
        for cornerBool in cornersBool {
            if (!cornerBool) {
                return
            }
        }
        
        showServerActionSheet()
    }
    
    func showServerActionSheet() {
        for (var i = 0; i < corners.count; i++) {
            cornersBool[i] = false
        }
        
        let actionSheet = UIAlertController(title: "Server" + " (" + APIConnector.currentService! + ")", message: "", preferredStyle: .ActionSheet)
        for server in APIConnector.kServers {
            actionSheet.addAction(UIAlertAction(title: server.0, style: .Default, handler: { Void in
                let serverName = server.0
                let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
                appDelegate.switchToServer(serverName)
            }))
        }
        self.presentViewController(actionSheet, animated: true, completion: nil)
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
