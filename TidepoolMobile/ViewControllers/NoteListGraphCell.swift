/*
 * Copyright (c) 2017, Tidepool Project
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
import FLAnimatedImage
import CocoaLumberjack

class NoteListGraphCell: UITableViewCell, GraphContainerViewDelegate {
    
    var note: BlipNote?
    let kGraphHeight: CGFloat = TPConstants.kGraphViewHeight
    
    @IBOutlet weak var dataVizView: TPIntrinsicSizeUIView!
    @IBOutlet weak var loadingAnimationView: UIView!
    @IBOutlet weak var imageContainer: UIView!
    
    @IBOutlet weak var noDataView: UIView!
    @IBOutlet weak var noDataLabel: UILabel!
    @IBOutlet weak var howToUploadButton: UIButton!
    @IBOutlet weak var dataIsComingLabel: UILabel!
    @IBOutlet var noDataViewsCollection: [UIView]!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        NSLog("setSelected \(selected) for \(String(describing: note?.messagetext))!")
        super.setSelected(selected, animated: animated)
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        NSLog("setHighlighted \(highlighted) for \(String(describing: note?.messagetext))!")
        super.setHighlighted(highlighted, animated:animated)
    }
    
    override func prepareForReuse() {
        removeGraphView()
    }
    
    func configureCell(_ note: BlipNote) {
        self.note = note
        configureNoData()
    }
    
    private var graphContainerView: TidepoolGraphView?
    func removeGraphView() {
        if (graphContainerView != nil) {
            NSLog("Removing current graph view from cell: \(self)")
            graphContainerView?.removeFromSuperview();
            graphContainerView = nil;
        }
        showLoadAnimation(false)
        hideNoDataViews(true)
    }
    
    func configureGraphContainer() {
        var lowBGBounds: Int?
        var highBGBounds: Int?
        let dataController = TidepoolMobileDataController.sharedInstance
        if let bgLowBounds = dataController.currentViewedUser?.bgTargetLow, let bgHighBounds = dataController.currentViewedUser?.bgTargetHigh {
            lowBGBounds = Int(bgLowBounds)
            highBGBounds = Int(bgHighBounds)
        }
        
        NSLog("NoteListGraphCell: configureGraphContainer")
        removeGraphView()
        if let note = note {
            // TODO: assume all notes created in current timezone?
            let tzOffset = NSCalendar.current.timeZone.secondsFromGMT()
            var graphFrame = self.bounds
            NSLog("Configuring graph for note id: \(note.id), frame: \(graphFrame)")
            graphFrame.size.height = kGraphHeight
            graphContainerView = TidepoolGraphView.init(frame: graphFrame, delegate: self, mainEventTime: note.timestamp, tzOffsetSecs: tzOffset, lowBGBounds: lowBGBounds, highBGBounds: highBGBounds)
            if let graphContainerView = graphContainerView {
                // while loading, and in between selections, put up loading view...
                graphContainerView.configureGraph()
                // delay to display notes until we get notified of data available...
                graphContainerView.configureNotesToDisplay([note])
                dataVizView.insertSubview(graphContainerView, at: 0)
                updateGraph()
            }
        }
    }
    
    func updateGraph() {
        if let graphContainerView = graphContainerView {
            graphContainerView.loadGraphData()
            // will get called back at containerCellUpdated when collection view has been updated
        }
    }
    
    let kDataDelay: TimeInterval = (60*60*3)    // 3 hours
    func configureNoData() {
        var dataIsComing = false
        if appHealthKitConfiguration.healthKitInterfaceEnabledForCurrentUser() {
            if let note = note {
                let passedTime = note.createdtime.timeIntervalSinceNow
                if passedTime > -kDataDelay {
                    dataIsComing = true
                }
            }
        }
        if dataIsComing {
            dataIsComingLabel.isHidden = false
            howToUploadButton.isHidden = true
            noDataLabel.isHidden = true
       } else {
            dataIsComingLabel.isHidden = true
            howToUploadButton.isHidden = false
            noDataLabel.isHidden = false
        }
    }
    
    func hideNoDataViews(_ hide: Bool) {
//        for view in noDataViewsCollection {
//            view.isHidden = hide
//        }
        
        noDataLabel.isHidden = hide
        howToUploadButton.isHidden = hide
        dataIsComingLabel.isHidden = hide
        
        if !hide {
            configureNoData()
        }
    }
    
    func syncGraph() {
        if let graphContainerView = graphContainerView {
            let dataStillLoading = DatabaseUtils.sharedInstance.isLoadingTidepoolEvents()
            var hideLoadingView = true
            var hideNoDataView = true
            if graphContainerView.dataFound() {
                // ensure loading and no data shown are off
                NSLog("\(#function) data found, show graph and grid")
                //graphContainerView.displayGridLines(true)
            } else if dataStillLoading {
                // show loading animation...
                NSLog("\(#function) data still loading, show loading animation")
                //graphContainerView.displayGridLines(false)
                hideLoadingView = false
            } else {
                // show no data found view...
                NSLog("\(#function) no data found!")
                //graphContainerView.displayGridLines(false)
                hideNoDataView = false
            }
            
            showLoadAnimation(!hideLoadingView)
            hideNoDataViews(hideNoDataView)
        }
    }
    
    private var animatedLoadingImage: FLAnimatedImageView?
    func showLoadAnimation(_ show: Bool) {
        if loadingAnimationView.isHidden != !show {
            if show {
                NSLog("show loading animation")
                if animatedLoadingImage == nil {
                    animatedLoadingImage = FLAnimatedImageView(frame: imageContainer.bounds)
                    imageContainer.insertSubview(animatedLoadingImage!, at: 0)
                    if let path = Bundle.main.path(forResource: "jump-jump-jump-jump", ofType: "gif") {
                        do {
                            let animatedImage = try FLAnimatedImage(animatedGIFData: Data(contentsOf: URL(fileURLWithPath: path)))
                            animatedLoadingImage?.animatedImage = animatedImage
                        } catch {
                            DDLogError("Unable to load animated gifs!")
                        }
                    }
                }
                animatedLoadingImage?.startAnimating()
                
            } else {
                NSLog("hide loading animation")
                animatedLoadingImage?.stopAnimating()
                animatedLoadingImage?.removeFromSuperview();
                animatedLoadingImage = nil
            }
            loadingAnimationView.isHidden = !show
        }
    }
    
    //
    // MARK: - GraphContainerViewDelegate
    //
    
    func containerCellUpdated() {
        syncGraph()
    }
    
    func pinchZoomEnded() {
        APIConnector.connector().trackMetric("Data viz zoom")
    }
    
    func dataPointTapped(_ dataPoint: GraphDataType, tapLocationInView: CGPoint) {
        //NSLog("dataPoint tapped")
    }
    
    func willDisplayGraphCell(_ cell: Int) {
        if TidepoolGraphLayout.cellNotInMainView(cell) {
            APIConnector.connector().trackMetric("Data viz panned")
        }
    }

    func unhandledTapAtLocation(_ tapLocationInView: CGPoint, graphTimeOffset: TimeInterval) {
        //NSLog("unhandledTapAtLocation \(tapLocationInView)")
    }
    
}

