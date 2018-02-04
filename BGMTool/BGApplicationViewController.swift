//
//  BGApplicationViewController.swift
//  BGMTool
//
//  Copyright © 2018 Tidepool. All rights reserved.
//
//  Based on Apple BTLE Transfer sample, BTLECentralViewController.m in Objective C.

// TODO:
// - Actually generate and store BG value in HK on message arrivals
// - Provide a way to cancel a connection (or just swipe off the app for now)

import UIKit
import HealthKit

/// Implements the "central" BLE role. Looks for a "BGMSimulator" peripheral to connect to, and then connects to it. The peripheral drives "BGM" events.
class BGApplicationViewController: UIViewController, CentralControllerDelegate {
    
    @IBOutlet weak var connectSwitch: UISwitch!

    @IBOutlet weak var deviceStartTimeValue: UILabel!
    @IBOutlet weak var timeOfLastSampleLabel: UILabel!
    @IBOutlet weak var countOfSamples: UILabel!
    @IBOutlet weak var minBgSampleSlider: UISlider!
    @IBOutlet weak var minBgSampleValue: UILabel!
    @IBOutlet weak var maxBgSampleSlider: UISlider!
    @IBOutlet weak var maxBgSampleValue: UILabel!
    @IBOutlet weak var lastSampleValueUILabel: UILabel!
    
    let bleController = BLEController.sharedInstance
    let defaults = ToolUserDefaults.sharedInstance
    private var sampleCount = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        updateBgmSliderAndLabel(minBgSampleSlider, minBgSampleValue, defaults.bgMinValue.intValue)
        updateBgmSliderAndLabel(maxBgSampleSlider, maxBgSampleValue, defaults.bgMaxValue.intValue)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        connectSwitch.isOn = bleController.connectState == .central
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
  
    //
    // MARK: - Slider and switch handling
    //

    @IBAction func connectSwitchChanged(_ sender: Any) {
        if connectSwitch.isOn {
            self.configureHKInterface()
            if self.bleController.connectState != .central {
                deviceStartTimeValue.text = "connecting..."
             self.bleController.connectAsCentral(self)
            }
         } else {
            self.bleController.disconnect()
            sampleCount = 0
            countOfSamples.text = ""
        }
    }
    
    @IBAction func minBGSliderChanged(_ sender: Any) {
        updateBgmLabelFromSlider(minBgSampleSlider, minBgSampleValue, defaults.bgMinValue)
    }
    
    @IBAction func maxBGSliderChanged(_ sender: Any) {
        updateBgmLabelFromSlider(maxBgSampleSlider, maxBgSampleValue, defaults.bgMaxValue)
    }

    func updateBgmSliderAndLabel(_ slider: UISlider, _ label: UILabel, _ bgmValue: Int) {
        let sliderValue = Float(bgmValue)
        slider.value = sliderValue
        label.text = String(bgmValue)
    }
    
    func updateBgmLabelFromSlider(_ slider: UISlider, _ label: UILabel, _ setting: ToolIntSetting) {
        let bgmValue = Int(slider.value)
        label.text = String(bgmValue)
        // also persist this
        setting.intValue = bgmValue
    }

    //
    // MARK: - HealthKit methods
    //
    
    private var hkEnabled = false
    
    /// Last time we checked for and pushed data to HealthKit or nil if never pushed
    var lastPushToHK: Date? {
        set(newValue) {
            UserDefaults.standard.set(newValue, forKey: kLastPushOfDataToHKKey)
            UserDefaults.standard.synchronize()
            _lastPushToHK = nil
        }
        get {
            if _lastPushToHK == nil {
                let curValue = UserDefaults.standard.object(forKey: kLastPushOfDataToHKKey)
                if let date = curValue as? Date {
                    _lastPushToHK = date
                }
            }
            return _lastPushToHK
        }
    }
    private var _lastPushToHK: Date?
    private let kLastPushOfDataToHKKey = "kLastPushOfDataToHKKey"

    // If we aren't configured for HK, do so now...
    private func configureHKInterface() {
        hkEnabled = appHealthKitConfiguration.healthKitInterfaceEnabledForCurrentUser()
        if !hkEnabled {
            HealthKitManager.sharedInstance.authorize(shouldAuthorizeBloodGlucoseSampleReads: true, shouldAuthorizeBloodGlucoseSampleWrites: true, shouldAuthorizeWorkoutSamples: false) {
                success, error -> Void in
                DispatchQueue.main.async(execute: {
                    if (error == nil) {
                        self.hkEnabled = true
                    } else {
                        NSLog("Error authorizing health data \(String(describing: error)), \(error!.userInfo)")
                    }
                })
            }
        }
    }

    var lastSampleDate: Date? = nil
    private func processNewSamples() {
        let formatter = DateFormatter()
        guard !pushToHKInProgress else {
            NSLog("\(#function) push to HK already in progess")
            return
        }
        // ensure valid iso text date received
        guard let bgmStartDateText = deviceStartTimeValue.text else {
            NSLog("\(#function) no text")
            return
        }
        guard let bgmStartDate = formatter.dateFromISOString(bgmStartDateText) else {
            NSLog("\(#function) no end date")
            return
        }
        // first sample sets a base...
        if lastPushToHK == nil {
            // back date so first sample is processed!
            lastPushToHK = bgmStartDate.addingTimeInterval(-kBGSampleSpacingSeconds)
        }
        // add enough samples to "catch up" to current time (use a little slop to deal with communication timing so 5 minutes minus a second is still one sample)
        var nextSampleTime = lastPushToHK!.addingTimeInterval(kBGSampleSpacingSeconds + 1)
        let sampleInterval = Date().timeIntervalSince(lastPushToHK!)
        let newSamplesCount = Int(sampleInterval/kBGSampleSpacingSeconds)
        if newSamplesCount <= 0 {
            NSLog("\(#function): No new samples, sample interval = \(sampleInterval)")
            return
        }

        NSLog("\(#function): Add \(newSamplesCount) samples starting at time \(nextSampleTime)")
        // gen up the next samples
        var newSamples = [HKQuantitySample]()
        for _ in 0..<newSamplesCount {
            let nextSample = nextItemForHealthKit(nextSampleTime)
            newSamples.append(nextSample)
            nextSampleTime = nextSampleTime.addingTimeInterval(kBGSampleSpacingSeconds)
        }
            
        // push them on to HealthKit
        self.pushItemsToHK(newSamples) {
            (itemsPushed) -> Void in
            NSLog("Finished push of \(itemsPushed) samples to HealthKit!")
            // remember sample time of last sample we pushed...
            self.lastPushToHK = nextSampleTime
        }
    }
    
    private var pushToHKInProgress = false
    private func pushItemsToHK(_ samples: [HKQuantitySample], completion: @escaping (Int) -> Void) {
        // If there are any new items, push them to HealthKit now...
        if !samples.isEmpty {
            pushToHKInProgress = true
            let itemsToPush = samples.count
            HealthKitManager.sharedInstance.healthStore!.save(samples, withCompletion: { (success, error) -> Void in
                if( error != nil ) {
                    NSLog("Error pushing \(itemsToPush) glucose samples to HealthKit: \(error!.localizedDescription)")
                    self.finishPush(itemsPushed: -1, completion: completion)
                } else {
                    NSLog("\(itemsToPush) Blood glucose samples pushed to HealthKit successfully!")
                    self.finishPush(itemsPushed: itemsToPush, completion: completion)
                    self.sampleCount += itemsToPush
                    self.countOfSamples.text = String(self.sampleCount)
                }
            })
        } else {
            NSLog("no new items to push to HealthKit!")
            self.finishPush(itemsPushed: 0, completion: completion)
        }
    }
    
    private func finishPush(itemsPushed: Int, completion: (Int) -> Void) {
        pushToHKInProgress = false
        completion(itemsPushed)
    }

    var lastBgValue: Int = 120
    private func nextBgValue() -> Int {
        // randomly add up to +-5 to the lastBgValue
        let randomChange = randomNumber(inRange: -5...5)
        var nextValue = lastBgValue + randomChange
        if nextValue > defaults.bgMaxValue.intValue {
            nextValue = defaults.bgMaxValue.intValue
        } else if nextValue < defaults.bgMinValue.intValue {
            nextValue = defaults.bgMinValue.intValue
        }
        NSLog("new bg: \(nextValue), change: \(randomChange), last bg: \(lastBgValue)")
        lastBgValue = nextValue
        lastSampleValueUILabel.text = String(nextValue)
        return lastBgValue
    }
 
    private func randomNumber<T : SignedInteger>(inRange range: ClosedRange<T> = 1...6) -> T {
        let length = Int64(range.upperBound - range.lowerBound + 1)
        let value = Int64(arc4random()) % length + Int64(range.lowerBound)
        return T(value)
    }
    
    /// Turns a Tidepool event into an HKQuantitySample event for HealthKit, adding it to the itemsToPush array.
    var bgmDevice: HKDevice? = nil

    fileprivate func nextItemForHealthKit(_ eventTime: Date) -> HKQuantitySample {
        let bgValue = Double(nextBgValue())
        let bgType = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bloodGlucose)
        let bgQuantity = HKQuantity(unit: HKUnit(from: "mg/dL"), doubleValue: bgValue)
        var metadata = [String: AnyObject]()
        metadata[HKMetadataKeyWasUserEntered] = false as AnyObject
        if bgmDevice == nil {
            bgmDevice = HKDevice(name: "BGMSim", manufacturer: "Tidepool", model: "1.0", hardwareVersion: nil, firmwareVersion: nil, softwareVersion: "1.0", localIdentifier: nil, udiDeviceIdentifier: nil)
        }
        let bgSample = HKQuantitySample(type: bgType!, quantity: bgQuantity, start: eventTime, end: eventTime, device: bgmDevice, metadata: metadata)
        return bgSample
    }

    //
    // MARK: - BLEControllerDelegate
    //
    func didConnect() {
        deviceStartTimeValue.text = "connected"
    }
    
    func disconnected() {
        deviceStartTimeValue.text = "disconnected"
    }

    // Called when BG Device message has been received; this includes start date of BG Device monitoring, and prompts us to add samples, spaced at 5 minutes, for the time between that start and now.
    func dataReady(_ text: String?) {
        if let text = text {
            if text != deviceStartTimeValue.text {
                deviceStartTimeValue.text = text
            }
            let curDateString = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
            self.timeOfLastSampleLabel.text = curDateString
            processNewSamples()
        }
    }

}

