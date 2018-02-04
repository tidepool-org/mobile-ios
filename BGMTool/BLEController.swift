//
//  BLEController.swift
//  BGMTool
//
//  Copyright © 2018 Tidepool. All rights reserved.
//

import Foundation
import CoreBluetooth

public protocol CentralControllerDelegate {
    func didConnect()
    func dataReady(_ text: String?)
    func disconnected()
}

public protocol PeripheralControllerDelegate {
    func didSubscribe()
    func readyToSend()
    func didUnsubscribe()
}

class BLEController: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate, CBPeripheralManagerDelegate {
    
    static let sharedInstance = BLEController()
    var peripheralDelegate: PeripheralControllerDelegate? = nil
    var centralDelegate: CentralControllerDelegate? = nil

    enum BLEConnectState {
        case disconnected
        case peripheral
        case central
    }
    
    var connectState: BLEConnectState = .disconnected
    var lastMessageText: String? = nil

    //
    // MARK: - Central role vars
    //
    private var centralManager: CBCentralManager?
    private var discoveredPeripheral: CBPeripheral?
    private let data = NSMutableData()

    //
    // MARK: - Peripheral role vars
    //
    private var peripheralManager: CBPeripheralManager?
    private var transferCharacteristic: CBMutableCharacteristic?
    private var dataToSend: Data = Data()
    private var sendDataIndex: Int = 0
    /// the background thread on which CoreBluetooth runs
    //private let blePeripheral_queue = DispatchQueue.global(qos: .default)

    override private init() {
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil) //blePeripheral_queue)
        // Start up the CBCentralManager
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }

    func disconnect() {
        if connectState == .peripheral {
            self.cleanUpPeripheral()
            self.peripheralDelegate = nil
        } else if connectState == .central {
            self.cleanupCentral()
            self.centralDelegate = nil
        }
        self.connectState = .disconnected
    }
    
    func connectAsCentral(_ delegate: CentralControllerDelegate) {
        self.centralDelegate = delegate
        if connectState == .central {
            return
        }
        disconnect()
        connectState = .central
        
        scan()
    }
  
    func connectAsPeripheral(_ delegate: PeripheralControllerDelegate) {
        self.peripheralDelegate = delegate
        if connectState == .peripheral {
            return
        }
        disconnect()
        connectState = .peripheral
        // All we advertise is our service's UUID
        peripheralManager?.startAdvertising([CBAdvertisementDataServiceUUIDsKey: [transferServiceUUID]])
    }

    //
    // MARK: - Central role public methods
    //

    //
    // MARK: - Peripheral role public methods
    //
    func sendData(_ data: Data) {
        dataToSend = data
        // Reset the index
        sendDataIndex = 0
        // Start sending
        sendData()
    }

    //
    // MARK: - Central role private methods
    //
    // centralManagerDidUpdateState is a required protocol method.
    // Usually, you'd check for other states to make sure the current device supports LE, is powered on, etc. In this instance, we're just using it to wait for CBCentralManagerStatePoweredOn, which indicates the Central is ready to be used.
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        NSLog("\(#function)")
        // The state must be CBCentralManagerStatePoweredOn...
        if central.state != .poweredOn {
            // In a real app, you'd deal with all the states correctly
            return
        }
        
        if connectState == .central {
            // if we are in central mode, start scanning
            scan()
        }
    }
    
    // Scan for peripherals - specifically for our service's 128bit CBUUID
    private func scan() {
        NSLog("\(#function)")
        centralManager?.scanForPeripherals(withServices: [transferServiceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: NSNumber(value: true)])
        NSLog("Scanning started")
    }
    
    /** This callback comes whenever a peripheral that is advertising the TRANSFER_SERVICE_UUID is discovered.
     *  We check the RSSI, to make sure it's close enough that we're interested in it, and if it is,
     *  we start the connection process
     */
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        NSLog("Discovered \(peripheral.name ?? "") at \(RSSI)")
        // Reject any where the value is above reasonable range
        if RSSI.intValue > -15 {
            NSLog("Peripheral rejected, signal > -15")
            return
        }
        // Reject if the signal strength is too low to be close enough (Close is around -22dB)
        // TODO: I see values of around -60, but that is ok! What is the motivation for this code? Ignoring devices that are far away, so you get the one the user probably wants?
        //if RSSI.intValue < -35 {
        //    NSLog("Peripheral rejected, signal < -35")
        //    return
        //}
        
        // Ok, it's in range - have we already seen it?
        if (self.discoveredPeripheral != peripheral) {
            // Save a local copy of the peripheral, so CoreBluetooth doesn't get rid of it
            self.discoveredPeripheral = peripheral
            // And connect
            NSLog("Connecting to peripheral \(peripheral)")
            centralManager?.connect(peripheral, options:nil)
        }
    }
    
    // To Do: provide user feedback if the connection fails for whatever reason.
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        NSLog("Failed to connect to \(peripheral), error: \(error?.localizedDescription ?? "")")
        centralDelegate?.disconnected()
        cleanupCentral()
    }
    
    // We've connected to the peripheral, now we need to discover the services and characteristics to find the 'transfer' characteristic.
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        NSLog("Peripheral Connected")
        centralDelegate?.didConnect()
        
        // Stop scanning
        centralManager?.stopScan()
        NSLog("Scanning stopped")
        
        // Clear the data that we may already have
        data.length = 0
        
        // Make sure we get the discovery callbacks
        peripheral.delegate = self
        
        // Search only for services that match our UUID
        peripheral.discoverServices([transferServiceUUID])
    }
    
    // Once the disconnection happens, we need to clean up our local copy of the peripheral
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        NSLog("Peripheral Disconnected")
        discoveredPeripheral = nil
        // We're disconnected, so start scanning again
        // TODO: will we really disconnect? Shouldn't we stay "connected" so that the BLE manager will automatically reconnect when device comes back in range?
        scan()
    }
    
    //
    // MARK: - CBPeripheralDelegate methods
    //
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            NSLog("Error discovering services: \(error.localizedDescription)")
            cleanupCentral()
            return
        }
        
        guard let services = peripheral.services else {
            return
        }
        
        // Discover the characteristic we want...
        // Loop through the newly filled peripheral.services array, just in case there's more than one.
        for service in services {
            peripheral.discoverCharacteristics([transferCharacteristicUUID], for: service)
        }
    }
    
    // The Transfer characteristic was discovered.
    // Once this has been found, we want to subscribe to it, which lets the peripheral know we want the data it contains
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        // Deal with errors (if any)
        if let error = error {
            NSLog("Error discovering characteristics: \(error.localizedDescription)")
            cleanupCentral()
            return
        }
        
        guard let characteristics = service.characteristics else {
            return
        }
        
        // Again, we loop through the array, just in case.
        for characteristic in characteristics {
            
            // And check if it's the right one
            if characteristic.uuid.isEqual(transferCharacteristicUUID) {
                // If it is, subscribe to it
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
        
        // Once this is complete, we just need to wait for the data to come in.
    }
    
    // This callback lets us know more data has arrived via notification on the characteristic
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        // Just note errors for now
        if let error = error {
            NSLog("Error in didUpdateValueFor characteristic: \(error.localizedDescription)")
            return
        }
        guard let stringFromData = NSString.init(data: characteristic.value!, encoding: String.Encoding.utf8.rawValue) else {
            NSLog("didUpdateValueFor data not valid")
            return
        }
        
        // Have we got everything we need?
        if stringFromData == "EOM" {
            // TODO: right now we just display the data. Need to actually store a BG value in HK here!
            // We have, so show the data,
            lastMessageText = String(data: data as Data, encoding: String.Encoding.utf8)
            centralDelegate?.dataReady(lastMessageText)
            // reset data for next message...
            self.data.length = 0
        } else {
            // Otherwise, just add the data on to what we already have
            self.data.append(characteristic.value!)
            // Log it
            NSLog("Received: \(stringFromData)")
        }
    }
    
    // The peripheral letting us know whether our subscribe/unsubscribe happened or not
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        // Just note errors for now
        if let error = error {
            NSLog("Error changing notification state: \(error.localizedDescription)")
        }
        
        // Exit if it's not the transfer characteristic
        if !characteristic.uuid.isEqual(transferCharacteristicUUID) {
            return
        }
        
        // Notification has started
        if (characteristic.isNotifying) {
            NSLog("Notification began on \(characteristic)")
        } else {
            // Notification has stopped, so disconnect from the peripheral
            NSLog("Notification stopped on \(characteristic).  Disconnecting")
            self.centralManager?.cancelPeripheralConnection(peripheral)
        }
    }

    private func cleanupCentral() {
        // Don't do anything if we're not connected
        if discoveredPeripheral?.state != .connected {
            self.connectState = .disconnected
            centralDelegate?.disconnected()
            NSLog("Central mode already disconnected...")
            return
        }
        
        // See if we are subscribed to a characteristic on the peripheral
        if let services = discoveredPeripheral?.services {
            for service in services {
                if let characteristics = service.characteristics {
                    for characteristic in characteristics {
                        if characteristic.uuid.isEqual(transferCharacteristicUUID) && characteristic.isNotifying {
                            // It is notifying, so unsubscribe
                            discoveredPeripheral?.setNotifyValue(false, for: characteristic)
                            // And we're done.
                            self.connectState = .disconnected
                            centralDelegate?.disconnected()
                            NSLog("Central mode disconnected from peripheral...")
                            return
                        }
                    }
                }
            }
        }
        
        // If we've got this far, we're connected, but we're not subscribed, so we just disconnect
        centralManager?.cancelPeripheralConnection(discoveredPeripheral!)
        self.connectState = .disconnected
        centralDelegate?.disconnected()
        NSLog("Central mode disconnected, no peripheral disconnect...")
    }
    
    //
    // MARK: - Peripheral role private methods
    //

    // Required protocol method.  A full app should take care of all the possible states, but we're just waiting to know when the CBPeripheralManager is ready
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        // Opt out from any other state
        if (peripheral.state != .poweredOn) {
            return
        }
        // We're in CBPeripheralManagerStatePoweredOn state...
        NSLog("self.peripheralManager powered on.")
        
        // ... so build our service.
        
        // Start with the CBMutableCharacteristic
        transferCharacteristic = CBMutableCharacteristic(
            type: transferCharacteristicUUID,
            properties: CBCharacteristicProperties.notify,
            value: nil,
            permissions: CBAttributePermissions.readable)
        
        // Then the service
        let transferService = CBMutableService(
            type: transferServiceUUID,
            primary: true)
        
        // Add the characteristic to the service
        transferService.characteristics = [transferCharacteristic!]
        
        // And add it to the peripheral manager
        peripheralManager!.add(transferService)
        
    }
    
    var maxDataPacketSize = NOTIFY_MTU
    // Catch when someone subscribes to our characteristic, then start sending them data
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        maxDataPacketSize = central.maximumUpdateValueLength
        NSLog("Central subscribed to characteristic, max update length: \(maxDataPacketSize)")
        peripheralDelegate?.didSubscribe()
    }
    
    // Recognise when the central unsubscribes
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        NSLog("Central unsubscribed from characteristic")
        peripheralDelegate?.didUnsubscribe()
        //stopTimer()
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            NSLog("\(#function) Error: \(error)")
        } else {
            NSLog("\(#function)")
        }
    }
    
    // This callback comes in when the PeripheralManager is ready to send the next chunk of data. This is to ensure that packets will arrive in the order they are sent
    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        // Start sending again
        sendData()
    }
    
    //
    // MARK: - Data transfer methods
    //
    
    // First up, check if we're meant to be sending an EOM
    private var sendingEOM = false
    
    /** Sends the next amount of data to the connected central
     */
    fileprivate func sendData() {
        if sendingEOM {
            // send it
            let didSend = peripheralManager?.updateValue(
                "EOM".data(using: String.Encoding.utf8)!,
                for: transferCharacteristic!,
                onSubscribedCentrals: nil
            )
            
            // Did it send?
            if (didSend == true) {
                // It did, so mark it as sent
                sendingEOM = false
                NSLog("Sent: EOM")
            }
            
            // It didn't send, so we'll exit and wait for peripheralManagerIsReadyToUpdateSubscribers to call sendData again
            return
        }
        
        // We're not sending an EOM, so we're sending data
        
        // Is there any left to send?
        if sendDataIndex >= dataToSend.count {
            // No data left.  Do nothing
            return
        }
        
        // There's data left, so send until the callback fails, or we're done.
        var didSend = true
        
        while didSend {
            // Make the next chunk
            
            // Work out how big it should be
            var amountToSend = dataToSend.count - sendDataIndex
            
            // Can't be longer than max data length from the connected central
            if (amountToSend > maxDataPacketSize) {
                amountToSend = maxDataPacketSize;
            }
            
            // Copy out the data we want
            let chunk = dataToSend.withUnsafeBytes{(body: UnsafePointer<UInt8>) in
                return Data(
                    bytes: body + sendDataIndex,
                    count: amountToSend
                )
            }
            
            // Send it
            didSend = peripheralManager!.updateValue(
                chunk as Data,
                for: transferCharacteristic!,
                onSubscribedCentrals: nil
            )
            
            // If it didn't work, drop out and wait for the callback
            if (!didSend) {
                return
            }
            
            let stringFromData = NSString(
                data: chunk as Data,
                encoding: String.Encoding.utf8.rawValue
            )
            
            NSLog("Sent: \(stringFromData ?? "")")
            
            // It did send, so update our index
            sendDataIndex += amountToSend;
            
            // Was it the last one?
            if (sendDataIndex >= dataToSend.count) {
                
                // It was - send an EOM
                
                // Set this so if the send fails, we'll send it next time
                sendingEOM = true
                
                // Send it
                let eomSent = peripheralManager!.updateValue(
                    "EOM".data(using: String.Encoding.utf8)!,
                    for: transferCharacteristic!,
                    onSubscribedCentrals: nil
                )
                
                if (eomSent) {
                    // It sent, we're all done
                    sendingEOM = false
                    NSLog("Sent: EOM")
                }
                
                return
            }
        }
    }

    func cleanUpPeripheral() {
        if connectState == .peripheral {
            peripheralManager?.stopAdvertising()
            connectState = .disconnected
            NSLog("Peripheral mode disconnected...")
        }
    }
}
