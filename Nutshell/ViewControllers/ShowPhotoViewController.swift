//
//  ShowPhotoViewController.swift
//  Nutshell
//
//  Created by Larry Kenyon on 10/28/15.
//  Copyright © 2015 Tidepool. All rights reserved.
//

import UIKit

class ShowPhotoViewController: UIViewController {

    var editAllowed = false
    var imageUrl: String = ""
    
    @IBOutlet weak var photoImageView: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // We use a custom back button so we can hide the photo to minimizing flashing. This tweaks the arrow positioning to match the iOS back arrow position
        self.navigationItem.leftBarButtonItem?.imageInsets = UIEdgeInsetsMake(0.0, -8.0, -1.0, 0.0)

        if !imageUrl.isEmpty {
            NutUtils.loadImage(imageUrl, imageView: photoImageView)
            if editAllowed {
                navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Trash, target: self, action: "deleteButtonHandler:")
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func backButtonHandler(sender: AnyObject) {
        photoImageView.hidden = true
        self.performSegueWithIdentifier(EventViewStoryboard.SegueIdentifiers.UnwindSegueFromShowPhoto, sender: self)
    }

    @IBAction func deleteButtonHandler(sender: AnyObject) {
        // setting url to an empty string sets up the EventAddOrEditVC to delete the photo when edits are saved...
        // use dialog to confirm delete with user!
        let alert = UIAlertController(title: NSLocalizedString("discardPhotoAlertTitle", comment:"Discard photo?"), message: NSLocalizedString("discardPhotoAlertMessage", comment:"If you discard this photo, your photo will be lost."), preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("discardAlertCancel", comment:"Cancel"), style: .Cancel, handler: { Void in
            return
        }))
        alert.addAction(UIAlertAction(title: NSLocalizedString("discardAlertOkay", comment:"Discard"), style: .Default, handler: { Void in
            self.imageUrl = ""
            self.backButtonHandler(sender)
        }))
        self.presentViewController(alert, animated: true, completion: nil)
       
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
