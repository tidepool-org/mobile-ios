//
//  ShowPhotoViewController.swift
//  Nutshell
//
//  Created by Larry Kenyon on 10/28/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import UIKit

class ShowPhotoViewController: UIViewController {

    @IBOutlet weak var photoImageView: UIImageView!
    var imageUrl: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.

        if !imageUrl.isEmpty {
            if let image = UIImage(named: imageUrl) {
                photoImageView.image = image
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func backButtonHandler(sender: AnyObject) {
        
        photoImageView.hidden = true
        self.performSegueWithIdentifier("unwindSequeToDone", sender: self)
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
