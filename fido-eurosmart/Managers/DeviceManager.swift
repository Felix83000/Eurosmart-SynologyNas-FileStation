//
//  DeviceManager.swift
//  fido-eurosmart
//
//  Created by FelixMac on 25/06/2019.
//  Copyright © 2019 Eurosmart. All rights reserved.
//

import Foundation
import CoreBluetooth

enum DeviceManagerState: String {
    case NotBound
    case Binding
    case Bound
}

final class DeviceManager: NSObject {
    
    static let deviceServiceUUID = "0000FFFD-0000-1000-8000-00805F9B34FB"
    static let writeCharacteristicUUID = "F1D0FFF1-DEAA-ECEE-B42F-C9BA7ED623BB"
    static let notifyCharacteristicUUID = "F1D0FFF2-DEAA-ECEE-B42F-C9BA7ED623BB"
    static let controlpointLengthCharacteristicUUID = "F1D0FFF3-DEAA-ECEE-B42F-C9BA7ED623BB"
    
    let peripheral: CBPeripheral
    var deviceName: String? { return peripheral.name }
    var onStateChanged: ((DeviceManager, DeviceManagerState) -> Void)?
    var onDebugMessage: ((DeviceManager, String) -> Void)?
    var onAPDUReceived: ((DeviceManager, Data) -> Void)?
    
    fileprivate var chunksize = 0
    fileprivate var pendingOutput: [Data] = []
    fileprivate var pendingInput: [Data] = []
    fileprivate var writeCharacteristic: CBCharacteristic?
    fileprivate var notifyCharacteristic: CBCharacteristic?
    fileprivate var controlpointLengthCharacteristic: CBCharacteristic?
    fileprivate(set) var state = DeviceManagerState.NotBound {
        didSet {
            onStateChanged?(self, self.state)
        }
    }
    
    init(peripheral: CBPeripheral) {
        self.peripheral = peripheral
        super.init()
        self.peripheral.delegate = self
    }
    
    func bindForReadWrite() {
        guard state == .NotBound else {
            onDebugMessage?(self, "Trying to bind but alreay busy")
            return
        }
        
        // Discover services
        onDebugMessage?(self, "Discovering services...")
        state = .Binding
        let serviceUUID = CBUUID(string: type(of: self).deviceServiceUUID)
        peripheral.discoverServices([serviceUUID])
    }
    
    func exchangeAPDU(_ data: Data) {
        guard state == .Bound else {
            onDebugMessage?(self, "Trying to send APDU \(data) but not bound yet")
            return
        }
        
        // Slice APDU
        onDebugMessage?(self, "Trying to split APDU into chunks...")
        if let chunks = TransportHelper.split(data, command: .message, chuncksize: chunksize), chunks.count > 0 {
            onDebugMessage?(self, "Successfully split APDU into \(chunks.count) part(s)")
            pendingOutput = chunks
            writeNextPendingChunk()
        }
        else {
            onDebugMessage?(self, "Unable to split APDU into chunks")
            resetState()
        }
    }
    
    fileprivate func writeNextPendingChunk() {
        guard pendingOutput.count > 0 else {
            onDebugMessage?(self, "Trying to write pending chunk but nothing left to write")
            return
        }
        
        let chunk = pendingOutput.removeFirst()
        onDebugMessage?(self, "Writing pending chunk = \(chunk)")
        peripheral.writeValue(chunk, for: writeCharacteristic!, type: .withResponse)
    }
    
    fileprivate func handleReceivedChunk(_ chunk: Data) {
        // get chunk type
        switch TransportHelper.getChunkType(chunk) {
        case .continuation:
            //onDebugMessage?(self, "Received CONTINUATION chunk")
            break
        case .message:
            //onDebugMessage?(self, "Received MESSAGE chunk")
            break
        case .error:
            //onDebugMessage?(self, "Received ERROR chunk")
            return
        case .keepAlive:
            //onDebugMessage?(self, "Received KEEPALIVE chunk")
            return
        default:
            //onDebugMessage?(self, "Received UNKNOWN chunk")
            break
        }
        
        // Join APDU
        pendingInput.append(chunk)
        if let APDU = TransportHelper.join(pendingInput, command: .message) {
            onDebugMessage?(self, "Successfully joined APDU = \(APDU)")
            pendingInput.removeAll()
            onAPDUReceived?(self, APDU)
        }
    }
    
    fileprivate func resetState() {
        writeCharacteristic = nil
        notifyCharacteristic = nil
        controlpointLengthCharacteristic = nil
        chunksize = 0
        state = .NotBound
    }
    
}

extension DeviceManager: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard state == .Binding else { return }
        guard
            let services = peripheral.services, services.count > 0,
            let service = services.first
        else {
            onDebugMessage?(self, "Unable to discover services")
            resetState()
            return
        }
        
        // Discover characteristics
        onDebugMessage?(self, "Successfully discovered services")
        let writeCharacteristicUUID = CBUUID(string: type(of: self).writeCharacteristicUUID)
        let notifyCharacteristicUUID = CBUUID(string: type(of: self).notifyCharacteristicUUID)
        let controlpointLengthCharacteristicUUID = CBUUID(string: type(of: self).controlpointLengthCharacteristicUUID)
        onDebugMessage?(self, "Discovering characteristics...")
        peripheral.discoverCharacteristics([writeCharacteristicUUID, notifyCharacteristicUUID, controlpointLengthCharacteristicUUID], for: service)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard state == .Binding else { return }
        guard
            let characteristics = service.characteristics, characteristics.count >= 3,
            let writeCharacteristic = characteristics.filter({ $0.uuid.uuidString == type(of: self).writeCharacteristicUUID }).first,
            let notifyCharacteristic = characteristics.filter({ $0.uuid.uuidString == type(of: self).notifyCharacteristicUUID }).first,
            let controlpointLengthCharacteristic = characteristics.filter({ $0.uuid.uuidString == type(of: self).controlpointLengthCharacteristicUUID }).first
        else {
            onDebugMessage?(self, "Unable to discover characteristics")
            resetState()
            return
        }
    
        // Retain characteristics
        onDebugMessage?(self, "Successfully discovered characteristics")
        self.writeCharacteristic = writeCharacteristic
        self.notifyCharacteristic = notifyCharacteristic
        self.controlpointLengthCharacteristic = controlpointLengthCharacteristic
        
        // Ask for notifications
        onDebugMessage?(self, "Enabling notifications...")
        peripheral.setNotifyValue(true, for: notifyCharacteristic)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard state == .Binding else { return }
        guard characteristic == notifyCharacteristic && characteristic.isNotifying && error == nil else {
            onDebugMessage?(self, "Unable to enable notifications, error = \(error as Error?)")
            resetState()
            return
        }
        
        // Ask for chunksize
        onDebugMessage?(self, "Successfully enabled notifications")
        onDebugMessage?(self, "Reading chunksize...")
        peripheral.readValue(for: self.controlpointLengthCharacteristic!)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard state == .Bound || state == .Binding else { return }
        guard
            (characteristic == notifyCharacteristic || characteristic == controlpointLengthCharacteristic) && error == nil,
            let data = characteristic.value
        else {
            onDebugMessage?(self, "Unable to read data, error = \(error as Error?), data = \(characteristic.value as Data?)")
            resetState()
            return
        }
        
        // Received data
        onDebugMessage?(self, "Received data of size \(data.count) = \(data)")
        
        if characteristic == controlpointLengthCharacteristic {
            // extract chunksize
            let reader = DataReader(data: data)
            guard let chunksize = reader.readNextBigEndianUInt16() else {
                onDebugMessage?(self, "Unable to read chunksize")
                resetState()
                return
            }
            
            // Successfully bound
            onDebugMessage?(self, "Successfully read chuncksize = \(chunksize)")
            self.chunksize = Int(chunksize)
            state = .Bound
        }
        else if characteristic == notifyCharacteristic {
            // Handle received data
            handleReceivedChunk(data)
        }
        else {
            // Unknown characteristic
            onDebugMessage?(self, "Received data from unknown characteristic, ignoring")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard state == .Bound else { return }
        guard characteristic == writeCharacteristic && error == nil else {
            onDebugMessage?(self, "Unable to write data, error = \(error as Error?)")
            resetState()
            return
        }
        
        // Write pending chunks
        writeNextPendingChunk()
    }
    
}
