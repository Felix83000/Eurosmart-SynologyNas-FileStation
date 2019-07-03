//
//  AddFidoViewController.swift
//  fido-eurosmart
//
//  Created by FelixMac on 12/06/2019.
//  Copyright © 2019 Eurosmart. All rights reserved.
//

import UIKit
import CoreData

class AddFidoViewController: UIViewController, UINavigationBarDelegate {
    
    @IBOutlet weak var loadingIndicator: UIActivityIndicatorView!
    @IBOutlet weak var scanButton: UIButton!
    @IBOutlet weak var scanButtonItem: UIBarButtonItem!
    @IBOutlet fileprivate weak var stateLabel: UILabel!
    @IBOutlet fileprivate weak var nameLabel: UILabel!
    @IBOutlet weak var registerButton: UIButton!
    @IBOutlet weak var authenticateButton: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var stopButton: UIButton!
    @IBOutlet weak var stopButtonItem: UIBarButtonItem!
    @IBOutlet weak var navBar: UINavigationBar!
    @IBOutlet weak var toolBar: UIToolbar!
    
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
    
    // MARK: UI updates
    func position(for bar: UIBarPositioning) -> UIBarPosition {
        return UIBarPosition.topAttached
    }
    
    // MARK: Action Buttons
    /**
     Scan bluetooth devices.
     */
    @IBAction func scanForDevice() {
        bluetoothManager.scanForDevice()
    }
    /**
     Stop the **bluetooth scan** or connection **session** with the MultiPass FIDO.
     */
    @IBAction func stopButton(_ sender: Any) {
        if (activityIndicator.isAnimating){
            activityIndicator.stopAnimating()
        }
        bluetoothManager.stopSession()
    }
    /**
     Perform the MultiPass FIDO registeration process.
     */
    @IBAction func sendRegister() {
        activityIndicator.startAnimating()
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
            print("APDU resitered")
        }
        else {
            print("Unable to build REGISTER APDU")
        }
    }
    /**
     Perform the MultiPass FIDO authentication verification.
     */
    @IBAction func sendAuthenticate() {
        activityIndicator.startAnimating()
        
        fetchCertificate()
        
        guard
            let registerAPDU = self.registerAPDU,
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
        
        if let APDU = AuthenticateAPDU(registerAPDU: registerAPDU,challenge: challengeData, applicationParameter: applicationParameterData, keyHandle: keyHandleData, checkOnly: false) {
            APDU.onDebugMessage = self.handleAPDUMessage
            let data = APDU.buildRequest()
            bluetoothManager.exchangeAPDU(data)
            currentAPDU = APDU
        }
        else {
            print("Unable to build AUTHENTICATE APDU")
        }
    }
    
    // MARK: DatabaseManager
    /**
     **Fetch** MultiPass FIDO Certificate **informations** into the Database and **set** these into **registerAPDU** instance.
     */
    func fetchCertificate(){
        let appDelegate = UIApplication.shared.delegate as? AppDelegate ?? AppDelegate()
        let managedContext = appDelegate.persistentContainer.viewContext
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "User")
        request.returnsObjectsAsFaults = false
        do {
            let preferences = UserDefaults.standard
            let username = String(describing: preferences.object(forKey: "username"))
            
            let result = try managedContext.fetch(request)
            for data in result as! [NSManagedObject] {
                // Checking if the user is in the Database
                let name = "Optional("+String(describing: data.value(forKey: "name") as? String ?? "Nothing")+")"
                if (name == username){
                    // Getting the user certificate in Database and setting it into the registerAPDU Class
                    self.registerAPDU = RegisterAPDU(managedContext: managedContext)
                    self.registerAPDU?.set_publicKey((data.value(forKey: "publickey") as? Data)!)
                    self.registerAPDU?.set_keyHandle((data.value(forKey: "keyhandle") as? Data)!)
                    self.registerAPDU?.set_certificate((data.value(forKey: "certificate") as? Data)!)
                    self.registerAPDU?.set_signature((data.value(forKey: "signature") as? Data)!)
                }
            }
        } catch {
            print("Failed Fetching FIDO Certificate in Database")
        }
        do {
            try managedContext.save()
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
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
            
            pushFidoRegistered()
            
            activityIndicator.stopAnimating()
            // The Multipass FIDO is now registered. Hence we can perform a segue to FileViewController
            performSegue(withIdentifier: "fileSegue", sender: self)
        }
        else {
            activityIndicator.stopAnimating()
            print("Failed to parse APDU response of kind \(type(of: currentAPDU as APDUType?))")
            // create the alert
            let alert = UIAlertController(title: "Identification problem", message: "This MultiPass FIDO is not the one you registered. Please try again.", preferredStyle: .alert)
            // add an action (button)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            // show the alert
            self.present(alert, animated: true, completion: nil)
        }
        currentAPDU = nil
    }
    /**
     Push the value **true** for the key **fidotoken** into the Database.
     */
    func pushFidoRegistered(){
        let appDelegate = UIApplication.shared.delegate as? AppDelegate ?? AppDelegate()
        let managedContext = appDelegate.persistentContainer.viewContext
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "User")
        request.returnsObjectsAsFaults = false
        do {
            let preferences = UserDefaults.standard
            let username = String(describing: preferences.object(forKey: "username"))
            
            let result = try managedContext.fetch(request)
            for data in result as! [NSManagedObject] {
                // Cheking if the user is in the Database
                let name = "Optional("+String(describing: data.value(forKey: "name") as? String ?? "Nothing")+")"
                if (name == username){
                    data.setValue(true, forKey: "fidotoken")
                }
            }
        } catch {
            print("Failed saving fidotoken boolean into the database")
        }
        do {
            try managedContext.save()
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
        }
    }
    
    // MARK: APDU
    fileprivate func handleAPDUMessage(_ APDU: APDUType, message: String) {
        print(message)
    }
    
    // MARK: UI updates
    fileprivate func updateUI() {
        // Alignement of scan and stop button
        toolBar.sizeToFit()
        let flexible = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: self, action: nil)
        toolBar.items = [flexible,scanButtonItem,flexible,flexible,stopButtonItem,flexible]
        
        bluetoothManager.state == .Scanning ? loadingIndicator.startAnimating() : loadingIndicator.stopAnimating()
        stateLabel.text = bluetoothManager.state.rawValue
        scanButton.isEnabled = bluetoothManager.state == .Disconnected
        stopButton.isEnabled = bluetoothManager.state == .Connecting || bluetoothManager.state == .Connected || bluetoothManager.state == .Scanning
        nameLabel.isHidden = bluetoothManager.state != .Connected
        nameLabel.text = bluetoothManager.deviceName
        if( bluetoothManager.state == .Connected ){
            isFidoRegistered(true)
        }else{
            isFidoRegistered(false)
        }
    }
    /**
     Perform the buttons change in case of if the fido is registered or not.
     */
    func isFidoRegistered(_ bool:Bool){
        let preferences = UserDefaults.standard
        if(Bool(preferences.object(forKey: "isFidoRegistered") as! String)!){
            registerButton.setTitle("", for: .normal)
            registerButton.isEnabled = false
            authenticateButton.isEnabled = bool
        }else{
            authenticateButton.setTitle("", for: .normal)
            authenticateButton.isEnabled = false
            registerButton.isEnabled = bool
        }
    }
}
