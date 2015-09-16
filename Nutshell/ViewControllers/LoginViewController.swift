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
    }
    
    @IBAction func login_button_tapped(sender: AnyObject) {
        updateButtonStates()
        loginIndicator.startAnimating()
        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        
        appDelegate.API?.login(emailTextField.text!,
            password: passwordTextField.text!,
            completion: { (result:(Alamofire.Result<User>)) -> (Void) in
                print("Login result: \(result)")
                if ( result.isSuccess ) {
                    if let user=result.value {
                        let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
                        let moc = appDelegate.managedObjectContext
                        
                        // Save the user in the database
                        moc.insertObject(user)
                        // Save the database
                        do {
                            try moc.save()
                        } catch let error as NSError {
                            print("Failed to save MOC: \(error)")
                        }
                        
                        print("login success: \(user)")
                        appDelegate.setupUIForLoginSuccess()

                        // Update the database with the current user info
                        appDelegate.API?.getUserData(user.userid!, completion: { (result) -> (Void) in
                            if result.isSuccess {
                                // We get back an array of JSON objects. Iterate through the array and insert the objects
                                // into the database
                                if let json = result.value {
                                    for (_, subJson) in json {
                                        if let obj = CommonData.fromJSON(subJson, moc: moc) {
                                            moc.insertObject(obj)
                                        }
                                    }
                                    
                                    // Save the database
                                    do {
                                        try moc.save()
                                    } catch let error as NSError {
                                        print("Failed to save MOC: \(error)")
                                    }
                                }
                            }
                        })
                    } else {
                        // This should not happen- we should not succeed without a user!
                        print("Fatal error: No user returned!")
                    }
                } else {
                    print("login failed! Error: " + result.error.debugDescription)
                }
        })
    }
    
    func textFieldDidChange() {
        updateButtonStates()
    }

    private func updateButtonStates() {
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
