//
//  APDUType.swift
//  fido-eurosmart
//
//  Created by FelixMac on 25/06/2019.
//  Copyright © 2019 Eurosmart. All rights reserved.
//

import Foundation

protocol APDUType {
    var onDebugMessage: ((APDUType, String) -> Void)? { get set }
    func buildRequest() -> Data
    func parseResponse(_ data: Data) -> Bool
}
