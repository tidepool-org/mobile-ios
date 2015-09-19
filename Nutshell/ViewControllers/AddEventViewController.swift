//
//  AddEventViewController.swift
//  Nutshell
//
//  Created by Larry Kenyon on 9/18/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import UIKit

class AddEventViewController: UIViewController {

    @IBOutlet weak var photoUIImageView: UIImageView!
    
    @IBOutlet weak var titleEventButton: NutshellUIButton!
    @IBOutlet weak var missingPhotoView: UIView!
    
    @IBOutlet weak var titleTextField: NutshellUITextField!
    @IBOutlet weak var notesTextField: NutshellUITextField!
    
    @IBOutlet weak var eventDate: NutshellUILabel!

    @IBOutlet weak var saveButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()

        saveButton.hidden = true
        let df = NSDateFormatter()
        df.dateFormat = uniformDateFormat
        eventDate.text = df.stringFromDate(NSDate())
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func titleEventButtonHandler(sender: NutshellUIButton) {
        titleTextField.becomeFirstResponder()
        titleEventButton.hidden = true
    }
    
    func textFieldDidBeginEditing(textField: UITextField) {
        notesTextField.becomeFirstResponder()
        notesTextField.selectAll(nil)
    }
    
    @IBAction func titleTextDidEnd(sender: AnyObject) {
        if titleTextField.text?.characters.count == 0 {
            titleEventButton.hidden = false
            saveButton.hidden = true
        } else {
             saveButton.hidden = false
        }
    }
    
    @IBAction func notesEditingDidEnd(sender: AnyObject) {
        notesTextField.resignFirstResponder()
    }
    
    @IBAction func notesEditingDidBegin(sender: AnyObject) {
    }
    

    @IBAction func saveButtonHandler(sender: AnyObject) {
        print("Need to save to database here!")
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
