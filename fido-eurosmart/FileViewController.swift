//
//  FileViewController.swift
//  fido-eurosmart
//
//  Created by FelixMac on 14/06/2019.
//  Copyright © 2019 Eurosmart. All rights reserved.
//

import UIKit

class FileViewController: UIViewController, UINavigationBarDelegate {
    @IBOutlet weak var navBar: UINavigationBar!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navBar.delegate = self
    }
    
    override func viewDidAppear(_ animated: Bool) {
        let preferences = UserDefaults.standard
        print("Sid: ",preferences.object(forKey: "sid") ?? "")
        if(preferences.object(forKey: "sid") == nil){
            performSegue(withIdentifier: "logout", sender: self)
        }
    }
    
    // MARK: UiNavigationBarDelegate Methods
    func position(for bar: UIBarPositioning) -> UIBarPosition {
        return UIBarPosition.topAttached
    }
    
    @IBAction func logout(_ sender: Any) {
        let preferences = UserDefaults.standard
        preferences.removeObject(forKey: "sid")
        performSegue(withIdentifier: "logout", sender: self)
    }
}
