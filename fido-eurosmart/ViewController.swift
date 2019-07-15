//
//  ViewController.swift
//  fido-eurosmart
//
//  Created by FelixMac on 11/06/2019.
//  Copyright © 2019 Eurosmart. All rights reserved.
//

import UIKit
import CoreData
import Network

/// The purpose of the `ViewController` ViewController is to manage the View Controller **Login Page** hierarchy.
class ViewController: UIViewController, UITextFieldDelegate, NetworkCheckObserver {

    @IBOutlet weak var username: UITextField!
    @IBOutlet weak var password: UITextField!
    @IBOutlet weak var submit_button: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    fileprivate var network: Network? = nil
    fileprivate var networkCheck: Any?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.network = Network()
        username.becomeFirstResponder()
        username.delegate = self
        password.delegate = self
        
        let preferences = UserDefaults.standard
        
        if(preferences.object(forKey: "sid") != nil)
        {
            loginDone()
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if #available(iOS 12.0, *) {
            self.networkCheck = NetworkCheck.sharedInstance()
            if ((networkCheck as! NetworkCheck).currentStatus == .unsatisfied){
                alertNetwork()
            }
            (networkCheck as! NetworkCheck).addObserver(observer: self)
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        if #available(iOS 12.0, *) {
            (networkCheck as! NetworkCheck).removeObserver(observer: self)
        }
        super.viewWillDisappear(animated)
    }
    
    @available(iOS 12.0, *)
    func statusDidChange(status: NWPath.Status) {
        if ((networkCheck as! NetworkCheck).currentStatus == .unsatisfied){
            alertNetwork()
        }
    }
    
    func alertNetwork(){
        let alert = UIAlertController(title: "Network problem", message: "Check your network connection.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .portrait
        } else {
            return .all
        }
    }
    
    // MARK: Action Buttons
    @IBAction func submit(_ sender: Any) {
        let username = self.username.text
        let password = self.password.text
        
        if(username == "" || password == ""){
            return
        }
        
        self.network?.doLogin(self,username!,password!)
    }
    
    // MARK: Update UI
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        switch textField {
        case username:
            username.resignFirstResponder()
            password.becomeFirstResponder()
        case password:
            password.resignFirstResponder()
            submit(self)
        default:
            username.resignFirstResponder()
            password.resignFirstResponder()
        }
        return false
    }
    
    /**
     Set the **username** and **FIDO multipass** verification in the **preferences** and perform a segue to **AddFidoViewController**
     */
    func loginDone()
    {
        print("Connection successful : \(username.text!)")
        let preferences = UserDefaults.standard
        preferences.set(username.text, forKey: "username")
        
        preferences.set(String(isFidoInBdd()), forKey: "isFidoRegistered")
        performSegue(withIdentifier: "addFidoSegue", sender: self)
        //performSegue(withIdentifier: "directToFiles", sender: self)
    }
    // MARK: DatabaseManager
    /**
     Check if the user exist in database and if he has already register a FIDO multipass or not.
     If the user does not exist in the local database, he is added.
     
     - Returns:
        - **true**: The user has a fido token in the Database
        - **false**: The user does not have a fido token in the Database or does not exist
     */
    func isFidoInBdd() -> Bool
    {
        guard let appDelegate =
            UIApplication.shared.delegate as? AppDelegate else {
                return false
        }
        let managedContext = appDelegate.persistentContainer.viewContext
        
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "User")
        request.returnsObjectsAsFaults = false
        do {
            let result = try managedContext.fetch(request)
            for data in result as! [NSManagedObject] {
                // Checking if the user is in the Database
                if (data.value(forKey: "name") as? String ?? "Nothing" == username.text){
                    // Is fido registered?
                    return data.value(forKey: "fidotoken") as? Bool ?? false
                }
            }
        } catch {
            print("Failed")
        }
        
        // Storing the user in the local database
        let entity = NSEntityDescription.entity(forEntityName: "User", in: managedContext)!
        let person = NSManagedObject(entity: entity, insertInto: managedContext)
        
        person.setValue(username.text, forKey: "name")
        
        do {
            try managedContext.save()
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
        }
        // User is not in bdd and do not have FIDO registered
        return false
    }
}

