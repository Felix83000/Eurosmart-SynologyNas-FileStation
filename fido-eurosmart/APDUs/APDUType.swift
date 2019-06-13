//
//  APDUType.swift
//  u2f-ble-test-ios
//
//  Created by Nicolas Bigot on 16/05/2016.
//  Copyright © 2016 Ledger. All rights reserved.
//

import Foundation

protocol APDUType {
    
    var onDebugMessage: ((APDUType, String) -> Void)? { get set }
    func buildRequest() -> Data
    func parseResponse(_ data: Data) -> Bool
    
}
