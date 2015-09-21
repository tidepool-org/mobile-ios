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

    var eventItem: Food?
    var graphView: GraphUIView?

    @IBOutlet weak var graphSectionView: UIView!
    @IBOutlet weak var missingDataAdvisoryView: UIView!
    
    @IBOutlet weak var photoUIImageView: UIImageView!

    @IBOutlet weak var missingPhotoView: UIView!
    
    @IBOutlet weak var eventNotes: NutshellUILabel!
    
    @IBOutlet weak var eventDate: NutshellUILabel!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let eventItem = eventItem {
            eventNotes.text = eventItem.location
            let df = NSDateFormatter()
            df.dateFormat = uniformDateFormat
            eventDate.text = df.stringFromDate(eventItem.time!)
        }
    }

    override func viewDidLayoutSubviews() {
        
        if (graphView != nil) {
            if (graphView!.frame.size != graphSectionView.frame.size) {
                graphView?.removeFromSuperview();
                graphView = nil;
            }
        }
        
        if (graphView == nil) {
            
            // self.view's direct subviews are laid out.
            // force my subview to layout its subviews:
            graphSectionView.setNeedsLayout()
            graphSectionView.layoutIfNeeded()
            
            // here we can get the frame of subviews of mySubView
            // and do useful things with that...
            if let eventTime = eventItem?.time {
                graphView = GraphUIView(frame: graphSectionView.bounds)
                graphView!.configureTimeFrame(eventTime, timeIntervalForView: 60*60*6)
                graphSectionView.addSubview(graphView!)
                graphSectionView.sendSubviewToBack(graphView!)
            }
            
            // Do any additional setup after loading the view.
//            var image = GraphViews.imageOfGraphBackground(viewSize: graphSectionView.frame.size)
//            graphBackground = UIImageView(image: image)
//            graphSectionView.addSubview(graphBackground!)
//            graphSectionView.sendSubviewToBack(graphBackground!)
//            
//            image = GraphViews.imageOfHealthEvent(0.15, graphSize:graphSectionView.frame.size)
//            // need to offset the middle of this view precisely at the time offset of the event
//            // assume time start of 0, time width of the graph 6 hours, and time offset of 3 hours
//            let graphTotalSecs: CGFloat = 6*60*60
//            let pixelsPerSecond = graphSectionView.frame.size.width/graphTotalSecs
//            let eventOffsetTime: CGFloat = 3*60*60
//            var eventOffsetPixels = pixelsPerSecond * eventOffsetTime
//            // offset for width of the event bar: the middle of the bar is where the event line is!
//            eventOffsetPixels = floor(eventOffsetPixels - 0.5 * image.size.width)
//            
//            let frame = CGRectMake(eventOffsetPixels, 0, image.size.width, image.size.height)
//            let healthEvent = UIImageView(frame: frame)
//            healthEvent.image = image
//            graphBackground?.addSubview(healthEvent)
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
