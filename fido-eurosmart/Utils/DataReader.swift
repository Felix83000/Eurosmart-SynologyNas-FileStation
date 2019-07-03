//
//  DataReader.swift
//  fido-eurosmart
//
//  Created by FelixMac on 25/06/2019.
//  Copyright © 2019 Eurosmart. All rights reserved.
//

import Foundation

final class DataReader {
    
    fileprivate let internalData: NSMutableData
    
    var remainingBytesLength: Int {
        return internalData.length
    }
    
    // MARK: Read methods
    func readNextInt8() -> Int8? {
        return readNextInteger()
    }
    
    func readNextUInt8() -> UInt8? {
        return readNextInteger()
    }
    
    func readNextBigEndianUInt16() -> UInt16? {
        return readNextInteger(bigEndian: true)
    }

    func readNextLittleEndianUInt16() -> UInt16? {
        return readNextInteger(bigEndian: false)
    }
    
    func readNextBigEndianInt16() -> Int16? {
        return readNextInteger(bigEndian: true)
    }
    
    func readNextLittleEndianInt16() -> Int16? {
        return readNextInteger(bigEndian: false)
    }
    
    func readNextBigEndianUInt32() -> UInt32? {
        return readNextInteger(bigEndian: true)
    }
    
    func readNextLittleEndianUInt32() -> UInt32? {
        return readNextInteger(bigEndian: false)
    }
    
    func readNextBigEndianInt32() -> Int32? {
        return readNextInteger(bigEndian: true)
    }
    
    func readNextLittleEndianInt32() -> Int32? {
        return readNextInteger(bigEndian: false)
    }
    
    func readNextBigEndianUInt64() -> UInt64? {
        return readNextInteger(bigEndian: true)
    }
    
    func readNextLittleEndianUInt64() -> UInt64? {
        return readNextInteger(bigEndian: false)
    }
    
    func readNextBigEndianInt64() -> Int64? {
        return readNextInteger(bigEndian: true)
    }
    
    func readNextLittleEndianInt64() -> Int64? {
        return readNextInteger(bigEndian: false)
    }

    func readNextAvailableData() -> Data? {
        return readNextDataOfLength(remainingBytesLength)
    }

    func readNextDataOfLength(_ length: Int) -> Data? {
        guard length > 0 else { return nil }
        guard internalData.length >= length else { return nil }
        
        let data = internalData.subdata(with: NSMakeRange(0, length))
        internalData.replaceBytes(in: NSMakeRange(0, length), withBytes: nil, length: 0)
        return data
    }
    
    func readNextMutableDataOfLength(_ length: Int) -> NSMutableData? {
        if let data = readNextDataOfLength(length) {
            return NSMutableData(data: data)
        }
        return nil
    }

    // MARK: Internal methods
    
    fileprivate func readNextInteger<T: BinaryInteger>() -> T? {
        guard let data = readNextDataOfLength(MemoryLayout<T>.size) else { return nil }
        
        var value: T = T(0)
        (data as NSData).getBytes(&value, length: MemoryLayout<T>.size)
        return value
    }
    
    fileprivate func readNextInteger<T: EndianConvertible>(bigEndian: Bool) -> T? {
        guard let data = readNextDataOfLength(MemoryLayout<T>.size) else { return nil }
        
        var value: T = T(0)
        (data as NSData).getBytes(&value, length: MemoryLayout<T>.size)
        return bigEndian ? value.bigEndian : value.littleEndian
    }
    
    // MARK: Initialization
    
    init(data: Data) {
        self.internalData = NSMutableData(data: data)
    }
    
}
