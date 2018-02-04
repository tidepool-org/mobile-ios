//
//  BGDeviceViewController.swift
//  BGMTool
//
//  Copyright © 2018 Tidepool. All rights reserved.
//

import UIKit
import CoreBluetooth

class BGDeviceViewController: UIViewController, PeripheralControllerDelegate {
    
    @IBOutlet weak var connectSwitch: UISwitch!
    
    var nextSendTimer: Timer?
    let bleController = BLEController.sharedInstance

    @IBOutlet weak var sampleUpdates: UILabel!
    @IBOutlet weak var timeOfFirstSample: UILabel!
    @IBOutlet weak var timeOfLastSample: UILabel!

    /// Time of last device restart or nil
    var lastDeviceStart: Date? {
        set(newValue) {
            UserDefaults.standard.set(newValue, forKey: kLastDeviceStartKey)
            UserDefaults.standard.synchronize()
            _lastDeviceStart = nil
        }
        get {
            if _lastDeviceStart == nil {
                let curValue = UserDefaults.standard.object(forKey: kLastDeviceStartKey)
                if let date = curValue as? Date {
                    _lastDeviceStart = date
                }
            }
            return _lastDeviceStart
        }
    }
    private var _lastDeviceStart: Date?
    private let kLastDeviceStartKey = "kLastDeviceStartKey"
    private var samplesSentCount = 0

    override func viewDidLoad() {
        super.viewDidLoad()
     }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        connectSwitch.isOn = bleController.connectState == .peripheral
        // Keep screen from locking while BG Device is current screen
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        stopTimer()
        // Allow screen locking when this controller is gone...
        UIApplication.shared.isIdleTimerDisabled = false
        super.viewDidDisappear(animated)
    }
    
    deinit {
        // Allow screen locking when this controller is gone...
        UIApplication.shared.isIdleTimerDisabled = false
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //
    // MARK: - UI handling
    //

    func startTimer() {
        NSLog("\(#function)")
        // clear message cache in case start date has changed...
        messageToSend = nil
        if nextSendTimer == nil {
            nextSendTimer = Timer.scheduledTimer(timeInterval: kBGSampleSpacingSeconds, target: self, selector: #selector(BGDeviceViewController.checkNextSend), userInfo: nil, repeats: true)
        }
        
    }
    
    func stopTimer() {
        NSLog("\(#function)")
        nextSendTimer?.invalidate()
        nextSendTimer = nil
    }
    
    var messageToSend: Data? = nil
    @objc func checkNextSend() {
        NSLog("\(#function)")
        if messageToSend == nil {
            guard let startDate = lastDeviceStart else {
                NSLog("\(#function) No device start date set!")
                return
            }
            // cache formatted date we send...
            let formatter = DateFormatter()
            messageToSend = formatter.isoStringFromDate(startDate).data(using: String.Encoding.utf8)!
            // also put it in the UI
            let startDateString = DateFormatter.localizedString(from: startDate, dateStyle: .medium, timeStyle: .short)
            self.timeOfFirstSample.text = startDateString
        }
        self.bleController.sendData(messageToSend!)
        samplesSentCount += 1
        self.sampleUpdates.text = String(samplesSentCount)
         let currentDateString = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
        self.timeOfLastSample.text = currentDateString
    }
    
    @IBAction func connectSwitchChanged(_ sender: Any) {
        if connectSwitch.isOn {
            self.bleController.connectAsPeripheral(self)
            startSimulation()
        } else {
            bleController.disconnect()
            stopTimer()
        }
    }
    
    private func startSimulation() {
        samplesSentCount = 0
        
        if lastDeviceStart == nil {
            lastDeviceStart = Date()
            startTimer()
            return
        }
        
        let previousStartDate = lastDeviceStart!
        let previousStartDateString = DateFormatter.localizedString(from: previousStartDate, dateStyle: .medium, timeStyle: .short)
        let titleString = "Choose BG Simulation Start"
        let messageString = "Start from previous start date (\(previousStartDateString)) or from now?"
        let alert = UIAlertController(title: titleString, message: messageString, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Previous", style: .cancel, handler: { Void in
            self.startTimer()
        }))
        alert.addAction(UIAlertAction(title: "Now", style: .default, handler: { Void in
            self.lastDeviceStart = Date()
            self.startTimer()
        }))
        self.present(alert, animated: true, completion: nil)
    }

    //
    // MARK: - BLEControllerDelegate
    //
    func didSubscribe() {
        startTimer()
    }
    
    func readyToSend() {
        NSLog("\(#function)")
    }
  
    func didUnsubscribe() {
        stopTimer()
    }
    
}

