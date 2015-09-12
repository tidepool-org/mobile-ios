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

class LoginViewController: BaseViewController {

    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
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
        APIConnector.login(emailTextField.text!, password: passwordTextField.text!) { loginSuccessful in
            self.loginIndicator.stopAnimating()
            if (loginSuccessful) {
                print("login success!")
                let appDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
                appDelegate.setupUIForLoginSuccess()
            } else {
                print("login failed!")
            }
        }
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
