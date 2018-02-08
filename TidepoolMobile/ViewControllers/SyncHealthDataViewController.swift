/*
 * Copyright (c) 2018, Tidepool Project
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
import CocoaLumberjack

class SyncHealthDataViewController: UIViewController {
    
    @IBOutlet weak var statusContainerView: UIStackView!
    @IBOutlet weak var healthStatusLine1: TidepoolMobileUILabel!
    @IBOutlet weak var healthStatusLine2: TidepoolMobileUILabel!
    
    @IBOutlet weak var instructionsContainerView: UIView!
    
    @IBOutlet weak var instructionsText: UITextView!
    
    @IBOutlet weak var buttonContainerView: UIView!
    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var syncLast2WeeksButton: UIButton!
    @IBOutlet weak var syncAllButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.healthStatusLine1.text = ""
        self.healthStatusLine2.text = ""

        NotificationCenter.default.addObserver(self, selector: #selector(SyncHealthDataViewController.handleStatsUpdatedNotification(_:)), name: NSNotification.Name(rawValue: HealthKitNotifications.Updated), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(SyncHealthDataViewController.handleTurnOffUploaderNotification(_:)), name: NSNotification.Name(rawValue: HealthKitNotifications.TurnOffUploader), object: nil)
        
        // Manual sync, initial setup (sync not in progress)
        configureLayout(initialSync: false, initialSetup: true)
        // Manual sync, sync in progress)
        //configureLayout(initialSync: false, initialSetup: false)
        // Initial sync, initial setup (sync not in progress)
        //configureLayout(initialSync: true, initialSetup: true)
        // Initial sync, sync in progress)
        //configureLayout(initialSync: true, initialSetup: false)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: nil, object: nil)
    }

    /// Configure layout for initial or manual sync, instructions or progress views...
    private func configureLayout(initialSync: Bool, initialSetup: Bool) {
        self.navigationItem.title = initialSync ? "Initial Sync" :
        "Manual Sync"
        
        if initialSync {
            instructionsContainerView.isHidden = true
            buttonContainerView.isHidden = true
            statusContainerView.isHidden = false
        } else {
            // manual sync
            // always show buttons at bottom; stop if in progress
            buttonContainerView.isHidden = false
            stopButton.isHidden = initialSetup
            syncLast2WeeksButton.isHidden = !initialSetup
            syncAllButton.isHidden = !initialSetup

            if initialSetup {
                configureInstructions()
            } else {
                updateProgress(0.0)
            }
            instructionsContainerView.isHidden = !initialSetup
            statusContainerView.isHidden = initialSetup
        }
    }
    
    @IBAction func backArrowButtonTapped(_ sender: Any) {
        // TODO: any cleanup?
        performSegue(withIdentifier: "unwindSegueToHome", sender: self)
    }
    
    @IBAction func syncAllButtonTapped(_ sender: Any) {
        startUploading(mode: HealthKitBloodGlucoseUploadReader.Mode.HistoricalAll)
        // TODO: other initialization?
        configureLayout(initialSync: false, initialSetup: false)
    }
    
    @IBAction func syncLastTwoWeeksButtonTapped(_ sender: Any) {
        self.startUploading(mode: HealthKitBloodGlucoseUploadReader.Mode.HistoricalLastTwoWeeks)
        // TODO: other initialization?
        configureLayout(initialSync: false, initialSetup: false)
    }
    
    @IBAction func stopButtonTapped(_ sender: Any) {
        self.stopUploadingAndReset()
        // exit?
        backArrowButtonTapped(self)
    }
    
    func handleStatsUpdatedNotification(_ notification: Notification) {
        let mode = notification.object as! HealthKitBloodGlucoseUploadReader.Mode
        if mode == HealthKitBloodGlucoseUploadReader.Mode.HistoricalAll || mode == HealthKitBloodGlucoseUploadReader.Mode.HistoricalLastTwoWeeks {
            let stats = HealthKitBloodGlucoseUploadManager.sharedInstance.stats[mode]!
            let healthKitUploadStatusDaysUploaded: String = "%d of %d days"
            var healthKitUploadStatusDaysUploadedText = ""
            var percentUploaded: CGFloat = 0.0
            if stats.totalDaysHistorical > 0 {
                percentUploaded = CGFloat((CGFloat)(stats.currentDayHistorical) / (CGFloat)(stats.totalDaysHistorical))
                healthKitUploadStatusDaysUploadedText = String(format: healthKitUploadStatusDaysUploaded, stats.currentDayHistorical, stats.totalDaysHistorical)
            }
            healthStatusLine2.text = healthKitUploadStatusDaysUploadedText
            updateProgress(percentUploaded)
        }
        self.updateHealthStatusLine1(mode: mode)
    }

    func handleTurnOffUploaderNotification(_ notification: Notification) {
        let reason = notification.userInfo!["reason"] as! HealthKitBloodGlucoseUploadReader.StoppedReason
        
        switch reason {
        case .turnOffInterface:
            self.healthStatusLine1.text = ""
            self.healthStatusLine2.text = "Stopped by user"
            break
        case .noResultsFromQuery:
            self.healthStatusLine2.text = "Finished"
            // TODO: review. Probably need an overall state enum...
            updateProgress(1.0)
            stopButton.isHidden = true
            break
        case .error(let error):
            self.healthStatusLine2.text = error.localizedDescription
            break
        default:
            
            break
        }        
    }

    func startUploading(mode: HealthKitBloodGlucoseUploadReader.Mode) {
        guard let currentUserId = TidepoolMobileDataController.sharedInstance.currentUserId else {
            return
        }
        
        HealthKitBloodGlucoseUploadManager.sharedInstance.startUploading(mode: mode, currentUserId: currentUserId)
        self.updateHealthStatusLine1(mode: mode)
    }
    
    func stopUploadingAndReset() {
        
        HealthKitBloodGlucoseUploadManager.sharedInstance.stopUploading(reason: HealthKitBloodGlucoseUploadReader.StoppedReason.turnOffInterface)
        
        HealthKitBloodGlucoseUploadManager.sharedInstance.resetPersistentState(mode: HealthKitBloodGlucoseUploadReader.Mode.HistoricalAll)
        HealthKitBloodGlucoseUploadManager.sharedInstance.resetPersistentState(mode: HealthKitBloodGlucoseUploadReader.Mode.HistoricalLastTwoWeeks)

        self.healthStatusLine1.text = ""
        self.healthStatusLine2.text = "Stopped by user"
    }

    @IBOutlet weak var progressView: UIView!
    @IBOutlet weak var indicatorViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var progressLabel: UILabel!
    
    // TODO: Hook up progress
    // Pass percentDone from 0.0 to 1.0
    func updateProgress(_ percentDone: CGFloat) {
        let progressString = String(Int(percentDone * 100))
        progressLabel.text = progressString + "%"
        let progressWidth = progressView.frame.width
        indicatorViewWidthConstraint.constant = progressWidth * percentDone
        statusContainerView.layoutIfNeeded()
    }
    
    func updateHealthStatusLine1(mode: HealthKitBloodGlucoseUploadReader.Mode) {
        if mode == HealthKitBloodGlucoseUploadReader.Mode.HistoricalAll {
            self.healthStatusLine1.text = "Syncing all Healthkit data:"

        } else if mode == HealthKitBloodGlucoseUploadReader.Mode.HistoricalLastTwoWeeks {
            self.healthStatusLine1.text = "Syncing last two weeks of Healthkit data"
        }
    }
    
    private func configureInstructions() {
        let regFont = UIFont(name: "OpenSans", size: 14.0)!
        let semiBoldFont = UIFont(name: "OpenSans-SemiBold", size: 14.0)!
        let textColor = UIColor(white: 61.0 / 255.0, alpha: 1.0)
        let textHighliteColor = UIColor(red: 40.0 / 255.0, green: 25.0 / 255.0, blue: 70.0 / 255.0, alpha: 1.0)
        
        let attributedString = NSMutableAttributedString(string: "If you’re having trouble seeing your blood glucose data in Tidepool or Tidepool Mobile, you can try a manual sync.\n\nBefore syncing: \n •  Open the Health app\n •  Tap the Sources tab\n •  Tap Dexcom\n •  Make sure ALLOW “DEXCOM” TO  \tWRITE DATA: Blood Glucose is enabled\n\nThen: \n •  Return to the Sources tab\n •  Tap Tidepool\n •  Make sure ALLOW “TIDEPOOL” TO \tREAD DATA: Blood Glucose is enabled\n\nIf you still can’t see your data, try syncing:", attributes: [
            NSFontAttributeName: regFont,
            NSForegroundColorAttributeName: textColor,
            NSKernAttributeName: -0.2
            ])
        attributedString.addAttributes([
            NSFontAttributeName: semiBoldFont,
            NSForegroundColorAttributeName: textHighliteColor
            ], range: NSRange(location: 146, length: 6))
        attributedString.addAttributes([
            NSFontAttributeName: semiBoldFont,
            NSForegroundColorAttributeName: textHighliteColor
            ], range: NSRange(location: 169, length: 7))
        attributedString.addAttributes([
            NSFontAttributeName: semiBoldFont,
            NSForegroundColorAttributeName: textHighliteColor
            ], range: NSRange(location: 189, length: 6))
        attributedString.addAttributes([
            NSFontAttributeName: semiBoldFont,
            NSForegroundColorAttributeName: textHighliteColor
            ], range: NSRange(location: 210, length: 45))
        attributedString.addAttributes([
            NSFontAttributeName: semiBoldFont,
            NSForegroundColorAttributeName: textHighliteColor
            ], range: NSRange(location: 293, length: 7))
        attributedString.addAttributes([
            NSFontAttributeName: semiBoldFont,
            NSForegroundColorAttributeName: textHighliteColor
            ], range: NSRange(location: 313, length: 8))
        attributedString.addAttributes([
            NSFontAttributeName: semiBoldFont,
            NSForegroundColorAttributeName: textHighliteColor
            ], range: NSRange(location: 336, length: 45))
        
        instructionsText.attributedText = attributedString
    }
}
