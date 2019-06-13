//
//  DataWriter.swift
//  ledger-wallet-ios
//
//  Created by Nicolas Bigot on 15/02/2016.
//  Copyright © 2016 Ledger. All rights reserved.
//

import Foundation

final class DataWriter {
    
    fileprivate let internalData: NSMutableData
    
    var data: Data {
        return internalData.copy() as! Data
    }
    
    var dataLength: Int {
        return internalData.length
    }
    
    // MARK: Write methods

    func writeNextUInt8(_ value: UInt8) {
        writeNextInteger(value)
    }
    
    func writeNextInt8(_ value: Int8) {
        writeNextInteger(value)
    }
    
    func writeNextBigEndianUInt16(_ value: UInt16) {
        writeNextInteger(value, bigEndian: true)
    }
    
    func writeNextLittleEndianUInt16(_ value: UInt16) {
        writeNextInteger(value, bigEndian: false)
    }
    
    func writeNextBigEndianInt16(_ value: Int16) {
        writeNextInteger(value, bigEndian: true)
    }
    
    func writeNextLittleEndianInt16(_ value: Int16) {
        writeNextInteger(value, bigEndian: false)
    }
    
    func writeNextBigEndianUInt32(_ value: UInt32) {
        writeNextInteger(value, bigEndian: true)
    }

    func writeNextLittleEndianUInt32(_ value: UInt32) {
        writeNextInteger(value, bigEndian: false)
    }
    
    func writeNextBigEndianInt32(_ value: Int32) {
        writeNextInteger(value, bigEndian: true)
    }
    
    func writeNextLittleEndianInt32(_ value: Int32) {
        writeNextInteger(value, bigEndian: false)
    }
    
    func writeNextBigEndianUInt64(_ value: UInt64) {
        writeNextInteger(value, bigEndian: true)
    }
    
    func writeNextLittleEndianUInt64(_ value: UInt64) {
        writeNextInteger(value, bigEndian: false)
    }
    
    func writeNextBigEndianInt64(_ value: Int64) {
        writeNextInteger(value, bigEndian: true)
    }
    
    func writeNextLittleEndianInt64(_ value: Int64) {
        writeNextInteger(value, bigEndian: false)
    }
    
    func writeNextData(_ data: Data) {
        internalData.append(data)
    }
    
    fileprivate func writeNextInteger<T: BinaryInteger>(_ value: T) {
        var value = value
        internalData.append(&value, length: MemoryLayout<T>.size)
    }
    
    fileprivate func writeNextInteger<T: EndianConvertible>(_ value: T, bigEndian: Bool) {
        var value = value
        value = bigEndian ? value.bigEndian : value.littleEndian
        internalData.append(&value, length: MemoryLayout<T>.size)
    }
    
    // MARK: Initialization

    init() {
        self.internalData = NSMutableData()
    }
    
}
