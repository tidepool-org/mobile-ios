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


class EventDetailViewController: BaseUIViewController {

    var eventItem: NutMeal?
    var eventGroup: NutEvent?

    var graphView: GraphUIView?
    private var graphCenterTime: NSDate?
    
    @IBOutlet weak var graphSectionView: UIView!
    @IBOutlet weak var missingDataAdvisoryView: UIView!
    
    @IBOutlet weak var photoUIImageView: UIImageView!

    @IBOutlet weak var missingPhotoView: UIView!
    
    @IBOutlet weak var eventNotes: NutshellUILabel!
    
    @IBOutlet weak var eventDate: NutshellUILabel!
    @IBOutlet weak var leftArrow: UIButton!
    
    @IBOutlet weak var rightArrow: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureDetailView()
    }

    private func configureDetailView() {
        if let eventItem = eventItem {
            eventNotes.text = eventItem.notes
            let df = NSDateFormatter()
            df.dateFormat = Styles.uniformDateFormat
            eventDate.text = df.stringFromDate(eventItem.time)
            print("timezone is \(df.timeZone)")
            graphCenterTime = eventItem.time
            if eventItem.photo.characters.count > 0 {
                if let image = UIImage(named: eventItem.photo) {
                    missingPhotoView.hidden = true
                    photoUIImageView.hidden = false
                    photoUIImageView.image = image
                }
            } else {
                missingPhotoView.hidden = false
                photoUIImageView.hidden = true
            }
            configureArrows()
        }
    }
    
    private func deleteGraphView() {
        if (graphView != nil) {
            graphView?.removeFromSuperview();
            graphView = nil;
        }
    }
    
    private func configureGraphViewIfNil() {
        if (graphView == nil) {
            
            // self.view's direct subviews are laid out.
            // force my subview to layout its subviews:
            graphSectionView.setNeedsLayout()
            graphSectionView.layoutIfNeeded()
            
            if let eventTime = graphCenterTime {
                // need about 60 pixels per hour... so divide by 60, and multiply by 60x60
                let interval = NSTimeInterval(graphSectionView.bounds.width*60)
                graphView = GraphUIView.init(frame: graphSectionView.bounds, centerTime: eventTime, timeIntervalForView: interval)
                graphView!.configure()
                graphSectionView.addSubview(graphView!)
                graphSectionView.sendSubviewToBack(graphView!)
                
                missingDataAdvisoryView.hidden = (graphView?.dataFound())!
            }
        }    }
    
    override func viewDidLayoutSubviews() {
        
        if (graphView != nil) {
            if (graphView!.frame.size != graphSectionView.frame.size) {
                deleteGraphView()
            }
        }
        configureGraphViewIfNil()

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
  
    // MARK: - Deal with layout changes

    private func reloadForNewEvent() {
        configureDetailView()
        deleteGraphView()
        configureGraphViewIfNil()
    }
    
    private func leftAndRightItems() -> (NutMeal?, NutMeal?) {
        var result = (eventItem, eventItem)
        var sawCurrentItem = false
        if let eventItem = eventItem {
            for item in (eventGroup?.itemArray)! {
                if item.time == eventItem.time {
                    sawCurrentItem = true
                } else if !sawCurrentItem {
                    result.0 = item
                } else {
                    result.1 = item
                    break
                }
            }
        }
        return result
    }
    
    private func configureArrows() {
        if !AppDelegate.testMode {
            leftArrow.hidden = true
            rightArrow.hidden = true
            
//            let leftAndRight = leftAndRightItems()
//            leftArrow.hidden = leftAndRight.0?.time == eventItem?.time
//            rightArrow.hidden = leftAndRight.1?.time == eventItem?.time
        }
    }
    
    // MARK: - Button handlers

    // TEMP for testing...
    private func scrollInTime(scrollTime: NSTimeInterval) {
        
        if graphView != nil {
            graphView!.removeFromSuperview();
            graphView = nil;
         }
        
        if graphCenterTime != nil {
            graphCenterTime = NSDate(timeInterval: scrollTime, sinceDate: graphCenterTime!)
            // need about 60 pixels per hour... so divide by 60, and multiply by 60x60
            let interval = NSTimeInterval(graphSectionView.bounds.width*60)
            graphView = GraphUIView.init(frame: graphSectionView.bounds, centerTime: graphCenterTime!, timeIntervalForView: interval)
            graphView!.configure()
            graphSectionView.addSubview(graphView!)
            graphSectionView.sendSubviewToBack(graphView!)
            
            missingDataAdvisoryView.hidden = (graphView?.dataFound())!
        }
        
    }
    
    @IBAction func leftArrowButtonHandler(sender: AnyObject) {
        if AppDelegate.testMode {
            scrollInTime(-60*60*3)
        } else {
            let leftAndRight = leftAndRightItems()
            self.eventItem = leftAndRight.0
            reloadForNewEvent()
        }
    }

    @IBAction func rightArrowButtonHandler(sender: AnyObject) {
        if AppDelegate.testMode {
            scrollInTime(60*60*3)
        } else {
            let leftAndRight = leftAndRightItems()
            self.eventItem = leftAndRight.1
            reloadForNewEvent()
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
