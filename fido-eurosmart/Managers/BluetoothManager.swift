//
//  BluetoothManager.swift
//  u2f-ble-test-ios
//
//  Created by Nicolas Bigot on 13/05/2016.
//  Copyright © 2016 Ledger. All rights reserved.
//

import Foundation
import CoreBluetooth

enum BluetoothManagerState: String {
    case Scanning
    case Connecting
    case Connected
    case Disconnecting
    case Disconnected
}

final class BluetoothManager: NSObject {
    
    var onStateChanged: ((BluetoothManager, BluetoothManagerState) -> Void)?
    var onDebugMessage: ((BluetoothManager, String) -> Void)?
    var onReceivedAPDU: ((BluetoothManager, Data) -> Void)?
    var deviceName: String? { return deviceManager?.deviceName }
    
    fileprivate var centralManager: CBCentralManager?
    fileprivate var deviceManager: DeviceManager?
    fileprivate(set) var state = BluetoothManagerState.Disconnected {
        didSet {
            onStateChanged?(self, self.state)
            onDebugMessage?(self, "New state: \(self.state.rawValue)")
        }
    }
    
    func scanForDevice() {
        guard centralManager == nil else { return }
        
        // create central
        centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: NSNumber(value: true as Bool)])
        state = .Scanning
    }
    
    func stopSession() {
        guard let centralManager = centralManager else { return }
        
        // handle disconnection
        if state == .Scanning {
            centralManager.stopScan()
            self.centralManager = nil
            state = .Disconnected
        }
        else if state == .Connecting || state == .Connected, let device = deviceManager?.peripheral {
            centralManager.cancelPeripheralConnection(device)
            state = .Disconnecting
        }
    }
    
    func exchangeAPDU(_ data: Data) {
        guard state == .Connected else { return }
        
        // send data
        onDebugMessage?(self, "Exchanging APDU = \(data)")
        deviceManager?.exchangeAPDU(data)
    }
    
    fileprivate func handleDeviceManagerStateChanged(_ deviceManager: DeviceManager, state: DeviceManagerState) {
        if state == .Bound {
            onDebugMessage?(self, "Successfully connected device \(deviceManager.peripheral.identifier.uuidString)")
            self.state = .Connected
        }
        else if state == .Binding {
            onDebugMessage?(self, "Binding to device \(deviceManager.peripheral.identifier.uuidString)...")
        }
        else if state == .NotBound {
            onDebugMessage?(self, "Something when wrong with device \(deviceManager.peripheral.identifier.uuidString)")
            stopSession()
        }
    }
    
    fileprivate func handleDeviceManagerDebugMessage(_ deviceManager: DeviceManager, message: String) {
        onDebugMessage?(self, message)
    }
    
    fileprivate func handleDeviceManagerReceivedAPDU(_ deviceManager: DeviceManager, data: Data) {
        onReceivedAPDU?(self, data)
    }
    
    fileprivate func resetState() {
        deviceManager = nil
        centralManager = nil
        state = .Disconnected
    }
    
}

extension BluetoothManager: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn && state == .Scanning {
            // bluetooth stack is ready, start scanning
            onDebugMessage?(self, "Bluetooth stack is ready, scanning devices...")
            let serviceUUID = CBUUID(string: DeviceManager.deviceServiceUUID)
            central.scanForPeripherals(withServices: [serviceUUID], options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        guard state == .Scanning else { return }
        guard let connectable = advertisementData[CBAdvertisementDataIsConnectable] as? NSNumber, connectable.boolValue == true else { return }
        
        // a device has been found
        onDebugMessage?(self, "Found connectable device \"\(peripheral.name as String?)\", connecting \(peripheral.identifier.uuidString)...")
        deviceManager = DeviceManager(peripheral: peripheral)
        deviceManager?.onStateChanged = handleDeviceManagerStateChanged
        deviceManager?.onDebugMessage = handleDeviceManagerDebugMessage
        deviceManager?.onAPDUReceived = handleDeviceManagerReceivedAPDU
        central.stopScan()
        central.connect(peripheral, options: nil)
        state = .Connecting
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        guard state == .Connecting, let deviceManager = deviceManager else { return }
        
        // we're connected, bind to characteristics
        deviceManager.bindForReadWrite()
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        guard state == .Connecting, let _ = deviceManager else { return }
        
        // failed to connect
        onDebugMessage?(self, "Failed to connect device \(peripheral.identifier.uuidString), error: \(error?.localizedDescription as String?)")
        resetState()
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard state == .Connecting || state == .Connected || state == .Disconnecting, let _ = deviceManager else { return }
        
        // destroy central
        onDebugMessage?(self, "Disconnected device \(peripheral.identifier.uuidString), error: \(error?.localizedDescription as String?)")
        resetState()
    }

}
