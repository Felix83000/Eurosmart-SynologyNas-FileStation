//
//  AddFidoViewController.swift
//  fido-eurosmart
//
//  Created by FelixMac on 12/06/2019.
//  Copyright © 2019 Eurosmart. All rights reserved.
//

import UIKit

class AddFidoViewController: UIViewController {
    
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    @IBOutlet weak var scanButton: UIButton!
    @IBOutlet fileprivate weak var stateLabel: UILabel!
    @IBOutlet fileprivate weak var nameLabel: UILabel!
    @IBOutlet var actionButtons: [UIButton]!
    
    fileprivate lazy var bluetoothManager: BluetoothManager = {
        let manager = BluetoothManager()
        manager.onStateChanged = self.handleStateChanged
        manager.onDebugMessage = self.handleDebugMessage
        manager.onReceivedAPDU = self.handleReceivedAPDU
        return manager
    }()
    fileprivate var useInvalidApplicationParameter = false
    fileprivate var useInvalidKeyHandle = false
    fileprivate var currentAPDU: APDUType? = nil
    fileprivate var registerAPDU: RegisterAPDU? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        updateUI()
    }
    override func viewDidAppear(_ animated: Bool) {
        let preferences = UserDefaults.standard
        if(preferences.object(forKey: "sid") == nil){
            performSegue(withIdentifier: "logoutFido", sender: self)
        }
    }
    
    // MARK: Actions
    
    @IBAction func scanForDevice() {
        bluetoothManager.scanForDevice()
    }
    
    @IBAction func sendRegister() {
        guard let appDelegate =
            UIApplication.shared.delegate as? AppDelegate else {
                return
        }
        let managedContext = appDelegate.persistentContainer.viewContext
        
        var challenge: [UInt8] = []
        var applicationParameter: [UInt8] = []
        
        for i in 0..<32 {
            challenge.append(UInt8(i))
            applicationParameter.append(UInt8(i) | 0x80)
        }
        let challengeData = Data(_: challenge)
        let applicationParameterData = Data(_: applicationParameter)
        
        if let APDU = RegisterAPDU(challenge: challengeData, applicationParameter: applicationParameterData, managedContext: managedContext) {
            APDU.onDebugMessage = self.handleAPDUMessage
            let data = APDU.buildRequest()
            bluetoothManager.exchangeAPDU(data)
            currentAPDU = APDU
        }
        else {
            print("Unable to build REGISTER APDU")
        }
    }
    
    @IBAction func sendAuthenticate() {
        sendAuthenticate(checkOnly: false)
    }
    
    @IBAction func sendAuthenticateCheck() {
        sendAuthenticate(checkOnly: true)
    }
    
    fileprivate func sendAuthenticate(checkOnly: Bool) {
        guard
            let registerAPDU = registerAPDU,
            let originalKeyHandle = registerAPDU.keyHandle else {
                print("Unable to build AUTHENTICATE APDU, not yet REGISTERED")
                return
        }
        
        var challenge: [UInt8] = []
        var applicationParameter: [UInt8] = []
        let keyHandleData: Data
        
        for i in 0..<32 {
            challenge.append(UInt8(i) | 0x10)
            applicationParameter.append(UInt8(i) | 0x80)
        }
        if useInvalidApplicationParameter {
            applicationParameter[0] = 0xFF
        }
        if useInvalidKeyHandle {
            var data = NSData(data: originalKeyHandle as Data) as Data
            data.replaceSubrange(0..<2, with: [0xFF, 0xFF] as [UInt8], count: 2)
            data.replaceSubrange((data.count - 1)..<data.count, with: [0xFF] as [UInt8], count: 1)
            keyHandleData = data
        }
        else {
            keyHandleData = originalKeyHandle as Data
        }
        let challengeData = Data(_: challenge)
        let applicationParameterData = Data(_: applicationParameter)
        
        if let APDU = AuthenticateAPDU(registerAPDU: registerAPDU, challenge: challengeData, applicationParameter: applicationParameterData, keyHandle: keyHandleData, checkOnly: checkOnly) {
            APDU.onDebugMessage = self.handleAPDUMessage
            let data = APDU.buildRequest()
            bluetoothManager.exchangeAPDU(data)
            currentAPDU = APDU
        }
        else {
            print("Unable to build AUTHENTICATE APDU")
        }
    }
    
    // MARK: BluetoothManager
    
    fileprivate func handleStateChanged(_ manager: BluetoothManager, state: BluetoothManagerState) {
        updateUI()
        
        if state == .Disconnected {
            currentAPDU = nil
        }
    }
    
    fileprivate func handleDebugMessage(_ manager: BluetoothManager, message: String) {
        print(message)
    }
    
    fileprivate func handleReceivedAPDU(_ manager: BluetoothManager, data: Data) {
        if let success = currentAPDU?.parseResponse(data), success {
            print("Successfully parsed APDU response of kind \(currentAPDU as APDUType?)")
            if currentAPDU is RegisterAPDU {
                registerAPDU = currentAPDU as? RegisterAPDU
            }
        }
        else {
            print("Failed to parse APDU response of kind \(type(of: currentAPDU as APDUType?))")
        }
        currentAPDU = nil
    }
    
    // MARK: APDU
    
    fileprivate func handleAPDUMessage(_ APDU: APDUType, message: String) {
        print(message)
    }
 
    fileprivate func updateUI() {
        bluetoothManager.state == .Scanning ? loadingIndicator.startAnimating() : loadingIndicator.stopAnimating()
        stateLabel.text = bluetoothManager.state.rawValue
        scanButton.isEnabled = bluetoothManager.state == .Disconnected
        nameLabel.isHidden = bluetoothManager.state != .Connected
        nameLabel.text = bluetoothManager.deviceName
        actionButtons.forEach() { $0.isEnabled = bluetoothManager.state == .Connected }
    }
}
