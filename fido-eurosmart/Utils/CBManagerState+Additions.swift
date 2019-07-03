//
//  CBManagerState+Additions.swift
//  fido-eurosmart
//
//  Created by FelixMac on 25/06/2019.
//  Copyright © 2019 Eurosmart. All rights reserved.
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
