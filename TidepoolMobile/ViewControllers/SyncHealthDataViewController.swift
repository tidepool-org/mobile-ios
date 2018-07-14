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

        NotificationCenter.default.addObserver(self, selector: #selector(SyncHealthDataViewController.handleStatsUpdatedNotification(_:)), name: NSNotification.Name(rawValue: HealthKitNotifications.Updated), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(SyncHealthDataViewController.handleTurnOffUploaderNotification(_:)), name: NSNotification.Name(rawValue: HealthKitNotifications.TurnOffUploader), object: nil)

        // Determine if this is the initial sync
        self.isInitialSync = !HealthKitUploadManager.sharedInstance.hasPresentedSyncUI

        // Remember that we've presented the sync UI before
        HealthKitUploadManager.sharedInstance.hasPresentedSyncUI = true
        
        // Determine if this is initial setup, or if a sync is in progress
        let historicalSync = historicalSyncModeInProgress()
        let syncIsInProgress = historicalSync != nil

        // Configure UI for initial sync and initial setup
        configureLayout(isInitialSync: self.isInitialSync, isInitialSetup: !syncIsInProgress)
        
        if let currentSyncMode = historicalSync {
            // Update stats
            updateForStatsUpdate(mode: currentSyncMode)

            // Disable idle timer when sync is in progress
            UIApplication.shared.isIdleTimerDisabled = true
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: nil, object: nil)

        // Re-enable idle timer (screen locking) when the controller is gone
        UIApplication.shared.isIdleTimerDisabled = false
    }

    /// Configure layout for initial or manual sync, instructions or progress views...
    private func configureLayout(isInitialSync: Bool, isInitialSetup: Bool) {
        self.navigationItem.title = isInitialSync ? "Initial Sync" : "Manual Sync"
        buttonContainerView.isHidden = false
        stopButton.isHidden = isInitialSetup
        syncLast2WeeksButton.isHidden = !isInitialSetup
        syncAllButton.isHidden = !isInitialSetup
        instructionsContainerView.isHidden = !isInitialSetup
        statusContainerView.isHidden = isInitialSetup
        if isInitialSetup {
            configureInstructions(isInitialSync: isInitialSync)
        } else {
            updateProgress(0.0)
        }
    }
    
    @IBAction func backArrowButtonTapped(_ sender: Any) {
        performSegue(withIdentifier: "unwindSegueToHome", sender: self)
    }
    
    @IBAction func syncAllButtonTapped(_ sender: Any) {
        startUploading(mode: HealthKitUploadReader.Mode.HistoricalAll)
        configureLayout(isInitialSync: self.isInitialSync, isInitialSetup: false)
    }
    
    @IBAction func syncLastTwoWeeksButtonTapped(_ sender: Any) {
        self.startUploading(mode: HealthKitUploadReader.Mode.HistoricalLastTwoWeeks)
        configureLayout(isInitialSync: self.isInitialSync, isInitialSetup: false)
    }
    
    @IBAction func stopButtonTapped(_ sender: Any) {
        let alert = UIAlertController(title: stopSyncingTitle, message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: stopSyncingCancel, style: .cancel, handler: { Void in
        }))
        alert.addAction(UIAlertAction(title: stopSyncingOkay, style: .default, handler: { Void in
            self.stopUploadingAndReset()
            self.backArrowButtonTapped(self)
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    @objc func handleStatsUpdatedNotification(_ notification: Notification) {
        let mode = notification.object as! HealthKitUploadReader.Mode
        if mode == HealthKitUploadReader.Mode.HistoricalAll
            || mode == HealthKitUploadReader.Mode.HistoricalLastTwoWeeks {
            updateForStatsUpdate(mode: mode)
        }
    }

    @objc func handleTurnOffUploaderNotification(_ notification: Notification) {
        let mode = notification.object as! HealthKitUploadReader.Mode
        
        if mode == HealthKitUploadReader.Mode.HistoricalAll
            || mode == HealthKitUploadReader.Mode.HistoricalLastTwoWeeks {
            // Update status
            let reason = notification.userInfo!["reason"] as! HealthKitUploadReader.StoppedReason
            switch reason {
            case .turnOffInterface:
                break
            case .noResultsFromQuery:
                updateProgress(1.0)
                stopButton.isHidden = true
                break
            case .error(let error):
                self.healthStatusLine2.text = error.localizedDescription
                self.syncCompletedStatusText = error.localizedDescription
                stopButton.isHidden = true
                break
            default:
                break
            }
        }
    }

    func startUploading(mode: HealthKitUploadReader.Mode) {
        guard let currentUserId = TidepoolMobileDataController.sharedInstance.currentUserId else {
            return
        }
        
        HealthKitUploadManager.sharedInstance.startUploading(mode: mode, currentUserId: currentUserId)
        self.updateHealthStatusLine1(mode: mode)
    }
    
    func stopUploadingAndReset() {
        
        HealthKitUploadManager.sharedInstance.stopUploading(reason: HealthKitUploadReader.StoppedReason.turnOffInterface)
        
        HealthKitUploadManager.sharedInstance.resetPersistentStateForMode(HealthKitUploadReader.Mode.HistoricalAll)
        HealthKitUploadManager.sharedInstance.resetPersistentStateForMode(HealthKitUploadReader.Mode.HistoricalLastTwoWeeks)
    }

    @IBOutlet weak var progressView: UIView!
    @IBOutlet weak var indicatorViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var progressLabel: UILabel!
    
    private func historicalSyncModeInProgress() -> HealthKitUploadReader.Mode? {
        let uploadManager = HealthKitUploadManager.sharedInstance
        if uploadManager.isUploadInProgressForMode(HealthKitUploadReader.Mode.HistoricalAll) {
            return HealthKitUploadReader.Mode.HistoricalAll
        }
        if uploadManager.isUploadInProgressForMode(HealthKitUploadReader.Mode.HistoricalLastTwoWeeks) {
            return HealthKitUploadReader.Mode.HistoricalLastTwoWeeks
        }
        return nil
    }
    
    func updateForStatsUpdate(mode: HealthKitUploadReader.Mode) {
        if historicalSyncModeInProgress() != nil {
            // Disable idle timer when sync is in progress
            UIApplication.shared.isIdleTimerDisabled = true
            
            // Determine percent progress and upload healthStatusLine2 text
            let stats = HealthKitUploadManager.sharedInstance.statsForMode(mode)
            var healthKitUploadStatusDaysUploadedText = ""
            var percentUploaded: CGFloat = 0.0
            if stats.totalDaysHistorical > 0 {
                percentUploaded = CGFloat((CGFloat)(stats.currentDayHistorical) / (CGFloat)(stats.totalDaysHistorical))
                let healthKitUploadStatusDaysUploaded: String = "%d of %d days"
                healthKitUploadStatusDaysUploadedText = String(format: healthKitUploadStatusDaysUploaded, stats.currentDayHistorical, stats.totalDaysHistorical)
            }
            
            // In case data has been written to HealthKit in non-sequential order (e.g. multiple sources?), keep tack of final upload percent and status text and use that when sync is complete
            if percentUploaded > self.syncCompletedPercentUploaded {
                self.syncCompletedPercentUploaded = percentUploaded
                self.syncCompletedStatusText = healthKitUploadStatusDaysUploadedText
            }
            
            // Update progress
            updateProgress(percentUploaded)
            
            // Update status lines
            updateHealthStatusLine1(mode: mode)
            healthStatusLine2.text = healthKitUploadStatusDaysUploadedText
        } else {
            // Re-enable idle timer when there is no sync in progress
            UIApplication.shared.isIdleTimerDisabled = false

            // Update progress
            updateProgress(self.syncCompletedPercentUploaded)
            
            // Update status lines
            updateHealthStatusLine1(mode: mode)
            healthStatusLine2.text = self.syncCompletedStatusText
        }
    }

    // Pass percentDone from 0.0 to 1.0
    func updateProgress(_ percentDone: CGFloat) {
        let progressString = String(Int(percentDone * 100))
        progressLabel.text = progressString + "%"
        let progressWidth = progressView.frame.width
        indicatorViewWidthConstraint.constant = progressWidth * percentDone
        statusContainerView.layoutIfNeeded()
    }
    
    func updateHealthStatusLine1(mode: HealthKitUploadReader.Mode) {
        if mode == HealthKitUploadReader.Mode.HistoricalAll {
            self.healthStatusLine1.text = "Syncing all Health data"

        } else if mode == HealthKitUploadReader.Mode.HistoricalLastTwoWeeks {
            self.healthStatusLine1.text = "Syncing last two weeks of Health data"
        }
    }
    
    private func configureInstructions(isInitialSync: Bool) {
        let regFont = UIFont(name: "OpenSans", size: 14.0)!
        let semiBoldFont = UIFont(name: "OpenSans-SemiBold", size: 14.0)!
        let textColor = UIColor(white: 61.0 / 255.0, alpha: 1.0)
        let textHighliteColor = UIColor(red: 40.0 / 255.0, green: 25.0 / 255.0, blue: 70.0 / 255.0, alpha: 1.0)
        
        if isInitialSync {
            let attributedString = NSMutableAttributedString(string: "In order to see your Blood Glucose data in Tidepool and Tidepool Mobile, we need to sync your Health data.\n\nWe suggest syncing the past 2 weeks now (roughly 1 min to sync).\n\nYou can also sync all Blood Glucose data immediately (may take more than an hour to sync).", attributes: [
                NSAttributedStringKey.font: regFont,
                NSAttributedStringKey.foregroundColor: textColor,
                NSAttributedStringKey.kern: -0.2
                ])
            instructionsText.attributedText = attributedString
        } else {
            let attributedString = NSMutableAttributedString(string: "If you’re having trouble seeing your blood glucose data in Tidepool or Tidepool Mobile, you can try a manual sync.\n\nBefore syncing: \n •  Open the Health app\n •  Tap the Sources tab\n •  Tap Dexcom\n •  Make sure ALLOW “DEXCOM” TO WRITE DATA: Blood Glucose is enabled\n\nThen: \n •  Return to the Sources tab\n •  Tap Tidepool\n •  Make sure ALLOW “TIDEPOOL” TO READ DATA: Blood Glucose is enabled\n\nIf you still can’t see your data, try syncing:", attributes: [
                NSAttributedStringKey.font: regFont,
                NSAttributedStringKey.foregroundColor: textColor,
                NSAttributedStringKey.kern: -0.2
                ])
            attributedString.addAttributes([
                NSAttributedStringKey.font: semiBoldFont,
                NSAttributedStringKey.foregroundColor: textHighliteColor
                ], range: NSRange(location: 146, length: 6))
            attributedString.addAttributes([
                NSAttributedStringKey.font: semiBoldFont,
                NSAttributedStringKey.foregroundColor: textHighliteColor
                ], range: NSRange(location: 169, length: 7))
            attributedString.addAttributes([
                NSAttributedStringKey.font: semiBoldFont,
                NSAttributedStringKey.foregroundColor: textHighliteColor
                ], range: NSRange(location: 189, length: 6))
            attributedString.addAttributes([
                NSAttributedStringKey.font: semiBoldFont,
                NSAttributedStringKey.foregroundColor: textHighliteColor
                ], range: NSRange(location: 210, length: 43))
            attributedString.addAttributes([
                NSAttributedStringKey.font: semiBoldFont,
                NSAttributedStringKey.foregroundColor: textHighliteColor
                ], range: NSRange(location: 291, length: 7))
            attributedString.addAttributes([
                NSAttributedStringKey.font: semiBoldFont,
                NSAttributedStringKey.foregroundColor: textHighliteColor
                ], range: NSRange(location: 311, length: 8))
            attributedString.addAttributes([
                NSAttributedStringKey.font: semiBoldFont,
                NSAttributedStringKey.foregroundColor: textHighliteColor
                ], range: NSRange(location: 334, length: 44))
            instructionsText.attributedText = attributedString
        }
    }
    
    fileprivate var isInitialSync = false
    fileprivate var syncCompletedPercentUploaded: CGFloat = 0.0
    fileprivate var syncCompletedStatusText = ""
}
