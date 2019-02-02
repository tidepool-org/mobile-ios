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
    
    enum SyncUIState {
        case initialStart
        case manualStart
        case syncing
        case complete
    }

    // Top screen views
    @IBOutlet weak var syncHealthTitle: UILabel!
    @IBOutlet weak var syncHealthSubtitle: UILabel!
    let kSyncTitleInitial = "Make Tidepool even better with Apple Health"
    let kSyncTitleManual = "Manual Health Sync"
    let kSyncTitleSyncing = "Syncing now"
    let kSyncTitleComplete = "Sync complete"
    let kSyncSubtitleInitial = "Automatically sync your diabetes data from your phone to Tidepool."

    // Middle screen views
    // (1) Show for SyncUIState.syncing
    @IBOutlet weak var statusContainerView: UIView!
    @IBOutlet weak var healthStatusLine2: UILabel!
    
    // (2) Show for SyncUIState.manualStart
    @IBOutlet weak var instructionsContainerView: UIView!
    @IBOutlet weak var instructionsText: UITextView!

    // Bottom screen views
    // (1) Show for SyncUIState.manualStart & SyncUIState.initialStart
    @IBOutlet weak var syncHealthDataButton: UIButton!
    // (2) Show for SyncUIState.syncing
    @IBOutlet weak var redLineNote: UILabel!
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var cancelButtonOutline: UIView!
    // (3) Show for SyncUIState.complete
    @IBOutlet weak var continueButton: UIButton!

    private var syncCompletedPercentUploaded: CGFloat = 0.0
    private var syncCompletedStatusText: String = ""
    private var lastErrorString: String? = nil
    private var maxHistoricalDays: Int = 0
    private var syncUIState: SyncUIState = .initialStart
    
    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(self, selector: #selector(SyncHealthDataViewController.handleStatsUpdatedNotification(_:)), name: Notification.Name(rawValue: HealthKitNotifications.Updated), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(SyncHealthDataViewController.handleTurnOffUploaderNotification(_:)), name: Notification.Name(rawValue: HealthKitNotifications.TurnOffUploader), object: nil)

        // Determine if this is the initial sync or just a manual sync...
        let manualSync = HealthKitUploadManager.sharedInstance.hasPresentedSyncUI
        self.syncUIState = manualSync ? .manualStart : .initialStart
        self.navigationItem.title = manualSync ? "Manual Sync" : "Initial Sync"

        // Remember that we've presented the sync UI before
        HealthKitUploadManager.sharedInstance.hasPresentedSyncUI = true
        
        // Determine if this is initial setup, or if a sync is in progress
        let historicalSync = historicalSyncModeInProgress()
        if historicalSync != nil {
            self.syncUIState = .syncing
        }

        // Round some corners
        cancelButton.layer.cornerRadius = 10
        cancelButtonOutline.layer.cornerRadius = 10
        continueButton.layer.cornerRadius = 10
        syncHealthDataButton.layer.cornerRadius = 10
        progressView.layer.cornerRadius = 10
        progressViewInset.layer.cornerRadius = 10

        // Configure UI for initial sync and initial setup
        configureLayout()
        
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
    private func configureLayout() {
        var title: String
        switch syncUIState {
        case .initialStart:
            title = kSyncTitleInitial
            updateProgress(0.0)
        case .manualStart:
            title = kSyncTitleManual
            updateProgress(0.0)
            configureInstructions()
        case .syncing:
            title = kSyncTitleSyncing
        case .complete:
            title = kSyncTitleComplete
        }
        syncHealthTitle.text = title
        syncHealthSubtitle.text = syncUIState == .initialStart ? kSyncSubtitleInitial : ""

        statusContainerView.isHidden = syncUIState != .syncing && syncUIState != .complete
        healthStatusLine2.isHidden = syncUIState != .syncing && syncUIState != .complete
        instructionsContainerView.isHidden = syncUIState != .manualStart
        
        syncHealthDataButton.isHidden = syncUIState != .manualStart && syncUIState != .initialStart
        redLineNote.isHidden = syncUIState != .syncing
        cancelButton.isHidden = syncUIState != .syncing
        cancelButtonOutline.isHidden = cancelButton.isHidden
        continueButton.isHidden = syncUIState != .complete
    }
    
    @IBAction func backArrowButtonTapped(_ sender: Any) {
        performSegue(withIdentifier: "unwindSegueToHome", sender: self)
    }
    
    @IBAction func syncHealthDataButtonTapped(_ sender: Any) {
        startUploading(mode: HealthKitUploadReader.Mode.HistoricalAll)
        self.syncUIState = .syncing
        configureLayout()
    }
    
    @IBAction func continueButtonTapped(_ sender: Any) {
        self.backArrowButtonTapped(self)
    }

    @IBAction func cancelButtonTapped(_ sender: Any) {
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
        DispatchQueue.main.async {
            //let mode = notification.object as! HealthKitUploadReader.Mode
            let userInfo = notification.userInfo!
            let mode = userInfo["mode"] as! HealthKitUploadReader.Mode
            let type = userInfo["type"] as! String
            DDLogInfo("Type: \(type), Mode: \(mode)")
            if mode == HealthKitUploadReader.Mode.HistoricalAll
                || mode == HealthKitUploadReader.Mode.HistoricalLastTwoWeeks {
                self.updateForStatsUpdate(mode: mode, type: type)
            }
        }
    }

    @objc func handleTurnOffUploaderNotification(_ notification: Notification) {
        DispatchQueue.main.async {
            //let mode = notification.object as! HealthKitUploadReader.Mode
            let userInfo = notification.userInfo!
            let mode = userInfo["mode"] as! HealthKitUploadReader.Mode
            let type = userInfo["type"] as! String
            let reason = userInfo["reason"] as! HealthKitUploadReader.StoppedReason
            DDLogInfo("Type: \(type), Mode: \(mode), Reason: \(reason)")

            if mode == HealthKitUploadReader.Mode.HistoricalAll
                || mode == HealthKitUploadReader.Mode.HistoricalLastTwoWeeks {
                // Update status
                switch reason {
                case .turnOffInterface:
                    break
                case .noResultsFromQuery:
                    self.checkForComplete()
                    break
                case .error(let error):
                    self.lastErrorString = String("\(type) upload error: \(error.localizedDescription.prefix(50))")
                    self.healthStatusLine2.text = self.lastErrorString
                    self.checkForComplete()
                    break
                default:
                    break
                }
            }
        }
    }
    
    private func checkForComplete() {
        // Only complete when all types are complete!
        if historicalSyncModeInProgress() == nil {
            updateProgress(1.0)
            //cancelButton.isHidden = true
            //cancelButtonOutline.isHidden = true
            var completedStr = "Day \(maxHistoricalDays) of \(maxHistoricalDays)"
            if lastErrorString != nil {
                completedStr = "Unable to complete due to upload errors!"
            }
            //redLineNote.isHidden = true
            self.healthStatusLine2.text = completedStr
            self.syncCompletedStatusText = completedStr
            self.syncUIState = .complete
            configureLayout()
            DDLogInfo("Complete!")
        }
    }

    private func startUploading(mode: HealthKitUploadReader.Mode) {
        guard let currentUserId = TidepoolMobileDataController.sharedInstance.currentUserId else {
            return
        }
        
        HealthKitUploadManager.sharedInstance.startUploading(mode: mode, currentUserId: currentUserId)
    }
    
    private func stopUploadingAndReset() {
        
        HealthKitUploadManager.sharedInstance.stopUploading(reason: HealthKitUploadReader.StoppedReason.turnOffInterface)
        
        HealthKitUploadManager.sharedInstance.resetPersistentStateForMode(HealthKitUploadReader.Mode.HistoricalAll)
        HealthKitUploadManager.sharedInstance.resetPersistentStateForMode(HealthKitUploadReader.Mode.HistoricalLastTwoWeeks)
    }
    
    @IBOutlet weak var indicatorViewRounded: UIView!
    @IBOutlet weak var indicatorView: UIView!
    @IBOutlet weak var progressView: UIView!
    @IBOutlet weak var progressViewInset: UIView!
    @IBOutlet weak var indicatorViewWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var progressLabel: UILabel!
    
    private func historicalSyncModeInProgress() -> HealthKitUploadReader.Mode? {
        //NSLog("\(#function)")
        let uploadManager = HealthKitUploadManager.sharedInstance
        if uploadManager.isUploadInProgressForMode(HealthKitUploadReader.Mode.HistoricalAll) {
            //NSLog("historicalSyncModeInProgress: still uploading for mode HistoricalAll")
            return HealthKitUploadReader.Mode.HistoricalAll
        }
        if uploadManager.isUploadInProgressForMode(HealthKitUploadReader.Mode.HistoricalLastTwoWeeks) {
            //NSLog("historicalSyncModeInProgress: still uploading for mode HistoricalLastTwoWeeks")
            return HealthKitUploadReader.Mode.HistoricalLastTwoWeeks
        }
        //NSLog("historicalSyncModeInProgress: no longer still uploading for historical modes")

        return nil
    }
    
    func updateForStatsUpdate(mode: HealthKitUploadReader.Mode, type: String? = nil) {
        //NSLog("\(#function). Mode: \(mode)")
        if historicalSyncModeInProgress() != nil {
            // Disable idle timer when sync is in progress
            UIApplication.shared.isIdleTimerDisabled = true
            
            // Determine percent progress and upload healthStatusLine2 text
            let stats = HealthKitUploadManager.sharedInstance.statsForMode(mode)
            var healthKitUploadStatusDaysUploadedText = ""
            var percentUploaded: CGFloat = 0.0
            
            if stats.totalDaysHistorical > 0 {
                percentUploaded = CGFloat((CGFloat)(stats.currentDayHistorical) / (CGFloat)(stats.totalDaysHistorical))
                healthKitUploadStatusDaysUploadedText = String("Day \(stats.currentDayHistorical) of \(stats.totalDaysHistorical)")
            }
            
            if stats.totalDaysHistorical > maxHistoricalDays {
                maxHistoricalDays = stats.totalDaysHistorical
            }
            
            // Update progress
            updateProgress(percentUploaded)
            
            // Update status lines
            if !healthKitUploadStatusDaysUploadedText.isEmpty {
                healthStatusLine2.text = healthKitUploadStatusDaysUploadedText
                //NSLog("Progress update: \(healthKitUploadStatusDaysUploadedText)")
            }
        } else {
            // Re-enable idle timer when there is no sync in progress
            UIApplication.shared.isIdleTimerDisabled = false

            // Update progress
            updateProgress(self.syncCompletedPercentUploaded)
            
            // Update status lines
            healthStatusLine2.text = self.syncCompletedStatusText
        }
    }

    // Pass percentDone from 0.0 to 1.0
    func updateProgress(_ percentDone: CGFloat) {
        let progressString = String(Int(percentDone * 100))
        progressLabel.text = progressString + "%"
        let progressWidth = progressViewInset.frame.width * percentDone
        indicatorViewWidthConstraint.constant = progressWidth
        statusContainerView.layoutIfNeeded()
    }
    
    private func configureInstructions() {
        let regFont = UIFont(name: "OpenSans", size: 16.0)!
        let semiBoldFont = UIFont(name: "OpenSans-SemiBold", size: 16.0)!
        let textColor = UIColor(white: 61.0 / 255.0, alpha: 1.0)
        let textHighliteColor = UIColor(red: 40.0 / 255.0, green: 25.0 / 255.0, blue: 70.0 / 255.0, alpha: 1.0)
        
        
        let attributedString = NSMutableAttributedString(string: "If you’re having trouble seeing your diabetes data in Tidepool or Tidepool Mobile, you can try a manual sync.\n\nBefore syncing: \n •  Open the Health app\n •  Tap the Sources tab\n •  Tap Tidepool\n •  Turn on any switches you want to sync with Tidepool (blood glucose, nutrition, insulin, etc)", attributes: [
            NSAttributedString.Key.font: regFont,
            NSAttributedString.Key.foregroundColor: textColor,
            NSAttributedString.Key.kern: -0.2
            ])
        attributedString.addAttributes([
            NSAttributedString.Key.font: semiBoldFont,
            NSAttributedString.Key.foregroundColor: textHighliteColor
            ], range: NSRange(location: 141, length: 6))
        attributedString.addAttributes([
            NSAttributedString.Key.font: semiBoldFont,
            NSAttributedString.Key.foregroundColor: textHighliteColor
            ], range: NSRange(location: 164, length: 7))
        attributedString.addAttributes([
            NSAttributedString.Key.font: semiBoldFont,
            NSAttributedString.Key.foregroundColor: textHighliteColor
            ], range: NSRange(location: 184, length: 8))
        instructionsText.attributedText = attributedString
    }
    
}
