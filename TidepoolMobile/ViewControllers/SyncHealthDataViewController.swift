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
    
    @IBOutlet weak var healthStatusLine1: TidepoolMobileUILabel!
    @IBOutlet weak var healthStatusLine2: TidepoolMobileUILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.healthStatusLine1.text = ""
        self.healthStatusLine2.text = ""

        NotificationCenter.default.addObserver(self, selector: #selector(SyncHealthDataViewController.handleStatsUpdatedNotification(_:)), name: NSNotification.Name(rawValue: HealthKitNotifications.Updated), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(SyncHealthDataViewController.handleTurnOffUploaderNotification(_:)), name: NSNotification.Name(rawValue: HealthKitNotifications.TurnOffUploader), object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: nil, object: nil)
    }

    @IBAction func syncAllButtonTapped(_ sender: Any) {
        startUploading(mode: HealthKitBloodGlucoseUploadReader.Mode.HistoricalAll)
    }
    
    @IBAction func syncLastTwoWeeksButtonTapped(_ sender: Any) {
        self.startUploading(mode: HealthKitBloodGlucoseUploadReader.Mode.HistoricalLastTwoWeeks)
    }
    
    @IBAction func stopButtonTapped(_ sender: Any) {
        self.stopUploadingAndReset()
    }
    
    func handleStatsUpdatedNotification(_ notification: Notification) {
        let mode = notification.object as! HealthKitBloodGlucoseUploadReader.Mode
        if mode == HealthKitBloodGlucoseUploadReader.Mode.HistoricalAll || mode == HealthKitBloodGlucoseUploadReader.Mode.HistoricalLastTwoWeeks {
            let stats = HealthKitBloodGlucoseUploadManager.sharedInstance.stats[mode]!
            let healthKitUploadStatusDaysUploaded: String = "%d of %d days"
            var healthKitUploadStatusDaysUploadedText = ""
            if stats.totalDaysHistorical > 0 {
                healthKitUploadStatusDaysUploadedText = String(format: healthKitUploadStatusDaysUploaded, stats.currentDayHistorical, stats.totalDaysHistorical)
            }
            healthStatusLine2.text = healthKitUploadStatusDaysUploadedText
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
        var mode = HealthKitBloodGlucoseUploadReader.Mode.HistoricalAll
        HealthKitBloodGlucoseUploadManager.sharedInstance.stopUploading(mode: mode, reason: HealthKitBloodGlucoseUploadReader.StoppedReason.turnOffInterface)
        HealthKitBloodGlucoseUploadManager.sharedInstance.resetPersistentState(mode: mode)
        
        mode = HealthKitBloodGlucoseUploadReader.Mode.HistoricalLastTwoWeeks
        HealthKitBloodGlucoseUploadManager.sharedInstance.stopUploading(mode: mode, reason: HealthKitBloodGlucoseUploadReader.StoppedReason.turnOffInterface)

        self.healthStatusLine1.text = ""
        self.healthStatusLine2.text = "Stopped by user"
    }

    func updateHealthStatusLine1(mode: HealthKitBloodGlucoseUploadReader.Mode) {
        if mode == HealthKitBloodGlucoseUploadReader.Mode.HistoricalAll {
            self.healthStatusLine1.text = "Syncing all Health data"

        } else if mode == HealthKitBloodGlucoseUploadReader.Mode.HistoricalLastTwoWeeks {
            self.healthStatusLine1.text = "Syncing last two weeks of Health data"
        }
    }
}
