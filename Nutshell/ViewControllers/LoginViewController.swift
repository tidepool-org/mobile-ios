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

    @IBOutlet weak var emailTextField: NutshellUITextField!
    @IBOutlet weak var passwordTextField: NutshellUITextField!
    @IBOutlet weak var loginButton: UIButton!
    @IBOutlet weak var loginIndicator: UIActivityIndicatorView!
    @IBOutlet weak var rememberMeButton: UIButton!
    @IBOutlet weak var errorFeedbackLabel: NutshellUILabel!
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    deinit {
        let nc = NSNotificationCenter.defaultCenter()
        nc.removeObserver(self, name: nil, object: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "textFieldDidChange", name: UITextFieldTextDidChangeNotification, object: nil)
        updateButtonStates()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func passwordEnterHandler(sender: AnyObject) {
        passwordTextField.resignFirstResponder()
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
                        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
                        let moc = appDelegate.managedObjectContext
                        
                        // Save the user in the database
                        DatabaseUtils.updateUser(moc, user: user)
                        
                        print("login success: \(user)")
                        appDelegate.setupUIForLoginSuccess()

                        // Update the database with the current user info
                        appDelegate.API?.getUserData(user.userid!, completion: { (result) -> (Void) in
                            if result.isSuccess {
                                DatabaseUtils.updateEvents(moc, eventsJSON: result.value!)
                            } else {
                                print("Failed to get events for user. Error: \(result.error!)")
                            }
                        })
                    } else {
                        // This should not happen- we should not succeed without a user!
                        print("Fatal error: No user returned!")
                    }
                } else {
                    print("login failed! Error: " + result.error.debugDescription)
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
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
