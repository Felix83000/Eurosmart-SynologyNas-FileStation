//
//  ViewController.swift
//  fido-eurosmart
//
//  Created by FelixMac on 11/06/2019.
//  Copyright © 2019 Eurosmart. All rights reserved.
//

import UIKit
import CoreData

class ViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var username: UITextField!
    @IBOutlet weak var password: UITextField!
    @IBOutlet weak var submit_button: UIButton!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    
    fileprivate let ip = "172.16.103.116"
    fileprivate let port = "1987" // 1988 : https, 1987: http
    fileprivate let httpType = "http"
    fileprivate var first = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        username.becomeFirstResponder()
        username.delegate = self
        
        let preferences = UserDefaults.standard
        let success = String(describing: preferences.object(forKey: "success"))
    
        
        if(preferences.object(forKey: "sid") != nil && success == "true")
        {
            LoginDone()
        }
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return .portrait
        } else {
            return .all
        }
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if (first){
            username.resignFirstResponder()
            password.becomeFirstResponder()
            password.delegate = self
            first = false
        }else{
            password.resignFirstResponder()
            first = true
            submit(self)
        }
        // On retourne false pour dire qu'on ne veut pas que le boutton retour fasse un retour de base
        return false
    }

    @IBAction func submit(_ sender: Any) {
        let username = self.username.text
        let password = self.password.text
        
        if(username == "" || password == ""){
            return
        }
        
        DoLogin(username!,password!)
    }
    
    func DoLogin(_ user:String,_ pwd:String)
    {
        self.activityIndicator.startAnimating()
        
        let urlOriginal = "\(httpType)://\(ip):\(port)/webapi/auth.cgi?api=SYNO.API.Auth&version=3&method=login&account=\(user)&passwd=\(pwd)&session=FileStation&format=sid"// À passer en https, avec cert let's encrypt
        let url = URL(string: urlOriginal.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? "")
        
        let session = URLSession.shared
        
        let request = NSMutableURLRequest(url: url!)
        request.httpMethod = "GET"
        
        let task = session.dataTask(with: request as URLRequest, completionHandler: {
            (data, response, error) in
            guard let _:Data = data else
            {
                return
            }
            
            let json:Any?
            
            do
            {
                json = try JSONSerialization.jsonObject(with: data!, options: [])
            }
            catch
            {
                return
            }
            
            guard let server_response = json as? NSDictionary else
            {
                return
            }
            
            if let error = server_response["error"] as? NSDictionary
            {
                if let code = error["code"] as? Int
                {
                    if (code == 400){
                        DispatchQueue.main.async {
                            self.activityIndicator.stopAnimating()
                            // create the alert
                            let alert = UIAlertController(title: "Identification problem", message: "The account or password is not valid. Please try again.", preferredStyle: .alert)
                            // add an action (button)
                            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                            // show the alert
                            self.present(alert, animated: true, completion: nil)
                            self.password.text = ""
                        }
                    }
                }
            }
            
            if let data_block = server_response["data"] as? NSDictionary
            {
                if let session_data = data_block["sid"] as? String
                {
                    let preferences = UserDefaults.standard
                    preferences.set(session_data, forKey: "sid")
                    preferences.set(server_response["success"], forKey: "success")
                    DispatchQueue.main.async {
                        self.activityIndicator.stopAnimating()
                    }
                    DispatchQueue.main.async(
                        execute:self.LoginDone
                    )
                }
            }
        })
        
        task.resume()
    }
    
    func LoginDone()
    {
        print("Connection successful : \(username.text!)")
        let preferences = UserDefaults.standard
        preferences.set(username.text, forKey: "username")
        
        preferences.set(String(IsFidoInBdd()), forKey: "isFidoRegistered")
        performSegue(withIdentifier: "addFidoSegue", sender: self)
        //performSegue(withIdentifier: "directToFiles", sender: self)
    }
    
    // L'utilisateur à un token fido dans la BDD -> true
    // L'utilisateur n'a pas de token fido dans la BDD -> false
    //
    // Si l'utilisateur n'existe pas dans la BDD local on l'ajoute 
    func IsFidoInBdd() -> Bool
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
                // Vérification si l'utilisateur est dans la BDD
                if (data.value(forKey: "name") as? String ?? "Nothing" == username.text){
                    // Fido dans la BDD ?
                    return data.value(forKey: "fidotoken") as? Bool ?? false
                }
            }
        } catch {
            print("Failed")
        }
        
        
        // Stockage de l'utilisateur en BDD local
        let entity = NSEntityDescription.entity(forEntityName: "User", in: managedContext)!
        let person = NSManagedObject(entity: entity, insertInto: managedContext)
        
        person.setValue(username.text, forKey: "name")
        
        do {
            try managedContext.save()
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
        }
        // On retourne false car l'utilisateur n'est pas dans la base et ne possède pas de token
        return false
    }
}

