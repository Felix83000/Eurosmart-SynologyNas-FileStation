//
//  CBCentralManagerState+Additions.swift
//  u2f-ble-test-ios
//
//  Created by Nicolas Bigot on 13/05/2016.
//  Copyright © 2016 Ledger. All rights reserved.
//

import CoreBluetooth

extension CBManagerState: CustomStringConvertible {
    
    public var description: String {
        switch self {
        case .poweredOff: return "PoweredOff"
        case .poweredOn: return "PoweredOn"
        case .resetting: return "Resetting"
        case .unauthorized: return "Unauthorized"
        case .unsupported: return "Unsupported"
        case .unknown: return "Unknown"
        @unknown default:
            print("Error in CBManagerState")
            return ""
        }
    }
}
