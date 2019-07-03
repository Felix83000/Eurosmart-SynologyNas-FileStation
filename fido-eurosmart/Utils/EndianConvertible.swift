//
//  EndianConvertible.swift
//  fido-eurosmart
//
//  Created by FelixMac on 25/06/2019.
//  Copyright © 2019 Eurosmart. All rights reserved.
//

import Foundation

protocol EndianConvertible: BinaryInteger {
    
    var bigEndian: Self { get }
    var littleEndian: Self { get }
    var byteSwapped: Self { get }
    
}

extension Int16: EndianConvertible {}
extension UInt16: EndianConvertible {}
extension Int32: EndianConvertible {}
extension UInt32: EndianConvertible {}
extension Int64: EndianConvertible {}
extension UInt64: EndianConvertible {}
