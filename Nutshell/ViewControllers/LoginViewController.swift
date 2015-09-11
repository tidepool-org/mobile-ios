//
//  LoginViewController.swift
//  Nutshell
//
//  Created by Larry Kenyon on 9/9/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import UIKit

class LoginViewController: BaseViewController {

    @IBOutlet weak var emailTextField: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
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
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
