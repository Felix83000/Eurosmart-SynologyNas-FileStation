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
    fileprivate var imageViewEye: UIImageView? = nil
    /// Permit to choose between eye or closed-eye icon.
    fileprivate var eyeClosed: Bool = true
    
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
        
        addBtnEye()
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
        let username = self.username.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        let password = self.password.text
        
        if(username == "" || password == ""){
            return
        }
        
        self.network?.doLogin(self,username!,password!)
    }
    
    @objc
    /**
     Change eye icon (opened or closed) and toggle password UITextField SecureTextEntry.
     */
    func btnEyeAction(imageView: UIImageView) {
        if(self.eyeClosed){
            self.imageViewEye?.image = UIImage(named: "eye")
            self.eyeClosed = false
        }else{
            self.imageViewEye?.image = UIImage(named: "closed-eye")
            self.eyeClosed = true
        }
        password.isSecureTextEntry.toggle()
    }
    
    // MARK: Update UI
    /**
     Size and Place the eye icon in the password UITextField.
     */
    func addBtnEye(){
        let imageView = UIImageView()
        imageView.image = UIImage(named: "closed-eye")
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(btnEyeAction))
        imageView.isUserInteractionEnabled = true
        imageView.addGestureRecognizer(tapGestureRecognizer)
        self.imageViewEye = imageView
        
        imageView.frame = CGRect(x: -17, y: 2, width: 35, height: 35)
        imageView.contentMode = .scaleAspectFit
        
        let paddingView = UIView(frame: CGRect(x:0, y:0, width:25,height:password.frame.height))
        paddingView.addSubview(imageView)
        password.rightView = paddingView
        
        let paddingViewleft = UIView(frame: CGRect(x:0, y:0, width:25,height:password.frame.height))
        password.leftView = paddingViewleft
        
        password.rightViewMode = UITextField.ViewMode.whileEditing
        password.leftViewMode = UITextField.ViewMode.whileEditing
    }
    
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
     Limit the textFields characters at 35.
    */
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let currentText = textField.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        
        let updatedText = currentText.replacingCharacters(in: stringRange, with: string)
        
        return updatedText.count <= 35
    }
    
    /**
     Set the **username** and **FIDO multipass** verification in the **preferences** and perform a segue to **AddFidoViewController**.
     */
    func loginDone()
    {
        let preferences = UserDefaults.standard
        preferences.set(self.username.text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), forKey: "username")
        
        preferences.set(String(isFidoInBdd()), forKey: "isFidoRegistered")
        performSegue(withIdentifier: "addFidoSegue", sender: self)
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
        // No uppercase because Synology don't support them in username
        let user = self.username.text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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
                if (data.value(forKey: "name") as? String ?? "Nothing" == user){
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
        
        person.setValue(user, forKey: "name")
        
        do {
            try managedContext.save()
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
        }
        // User is not in bdd and do not have FIDO registered
        return false
    }
}

