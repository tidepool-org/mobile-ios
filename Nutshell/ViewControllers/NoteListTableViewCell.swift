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
import FLAnimatedImage
import CocoaLumberjack

class NoteListTableViewCell: BaseUITableViewCell, GraphContainerViewDelegate {

    var note: BlipNote?
    var expanded: Bool = false
    let kGraphHeight: CGFloat = 200.0
    
    @IBOutlet weak var dataVizView: TPIntrinsicSizeUIView!
    @IBOutlet weak var separatorView: TPRowSeparatorView!
    @IBOutlet weak var loadingAnimationView: UIView!
    @IBOutlet weak var imageContainer: UIView!
    
    @IBOutlet weak var noDataView: UIView!
    @IBOutlet weak var noteLabel: UILabel!
    @IBOutlet weak var dateLabel: NutshellUILabel!
    
    @IBOutlet weak var editButton: NutshellSimpleUIButton!
    @IBOutlet weak var editButtonLargeHitArea: UIButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        NSLog("setSelected \(selected) for \(String(describing: note?.messagetext))!")
        
        super.setSelected(selected, animated: animated)
        self.updateNoteFontStyling()
    }

    func openGraphView(_ open: Bool) {
        expanded = open
        // Change intrinsic size of dataVizView appropriately
        dataVizView.height = open ? 200.0 : 0.0
     }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        NSLog("setHighlighted \(highlighted) for \(String(describing: note?.messagetext))!")
        super.setHighlighted(highlighted, animated:animated)
        
        // Configure the view for the highlighted state
        updateNoteFontStyling()
        dateLabel.isHighlighted = highlighted
    }
    
    override func prepareForReuse() {
        removeGraphView()
    }
    
    func configureCell(_ note: BlipNote) {
        expanded = false
        openGraphView(false)
        self.note = note
        self.updateNoteFontStyling()
        dateLabel.text = NutUtils.standardUIDateString(note.timestamp)
        noteLabel.isHighlighted = false
        dateLabel.isHighlighted = false
    }
    
    private func updateNoteFontStyling() {
        if let note = note {
            let hashtagBolder = HashtagBolder()
            let attributedText = hashtagBolder.boldHashtags(note.messagetext as NSString, highlighted: self.isHighlighted)
            noteLabel.attributedText = attributedText
        }
    }
    
    private var graphContainerView: TidepoolGraphView?
    func removeGraphView() {
        if (graphContainerView != nil) {
        NSLog("Removing current graph view from cell: \(self)")
        graphContainerView?.removeFromSuperview();
        graphContainerView = nil;
        }
        showLoadAnimation(false)
        noDataView.isHidden = true
    }

    func configureGraphContainer() {
        NSLog("EventListVC: configureGraphContainer")
        removeGraphView()
        if let note = note {
            NSLog("Configuring graph for note id: \(note.id)")
            // TODO: assume all notes created in current timezone?
            let tzOffset = NSCalendar.current.timeZone.secondsFromGMT()
            var graphFrame = dataVizView.bounds
            graphFrame.size.height = kGraphHeight
            graphContainerView = TidepoolGraphView.init(frame: graphFrame, delegate: self, mainEventTime: note.timestamp, tzOffsetSecs: tzOffset)
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

    func syncGraph() {
        if let graphContainerView = graphContainerView {
            let dataStillLoading = DatabaseUtils.sharedInstance.isLoadingTidepoolEvents()
            var hideLoadingView = true
            var hideNoDataView = true
            if graphContainerView.dataFound() {
                // ensure loading and no data shown are off
                NSLog("\(#function) data found, show graph and grid")
                graphContainerView.displayGridLines(true)
            } else if dataStillLoading {
                // show loading animation...
                NSLog("\(#function) data still loading, show loading animation")
                graphContainerView.displayGridLines(false)
                hideLoadingView = false
            } else {
                // show no data found view...
                NSLog("\(#function) no data found!")
                graphContainerView.displayGridLines(false)
                hideNoDataView = false
            }
            
            showLoadAnimation(!hideLoadingView)
            noDataView.isHidden = hideNoDataView
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
    
    func pinchZoomEnded() {}
    func dataPointTapped(_ dataPoint: GraphDataType, tapLocationInView: CGPoint) {}
    func willDisplayGraphCell(_ cell: Int) {}
    func unhandledTapAtLocation(_ tapLocationInView: CGPoint, graphTimeOffset: TimeInterval) {}

}
