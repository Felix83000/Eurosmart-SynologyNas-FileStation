//
//  FileViewController.swift
//  fido-eurosmart
//
//  Created by FelixMac on 14/06/2019.
//  Copyright © 2019 Eurosmart. All rights reserved.
//

import UIKit

class FileViewController: UIViewController, UINavigationBarDelegate, UITableViewDelegate, UITableViewDataSource {

    var dirList = [DirData]()
    let ip = "172.16.103.116"
    let port = "1987" // 1988 : https, 1987: http
    var sid = ""
    
    @IBOutlet weak var navBar: UINavigationBar!
    @IBOutlet weak var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navBar.delegate = self
        
        let preferences = UserDefaults.standard
        sid = String(describing: preferences.object(forKey: "sid") ?? "")
        print("Sid: ",sid)
        
        fetchDirectories()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        let preferences = UserDefaults.standard
        if(preferences.object(forKey: "sid") == nil){
            performSegue(withIdentifier: "logout", sender: self)
        }
    }
    
    // MARK: UiNavigationBarDelegate Methods
    func position(for bar: UIBarPositioning) -> UIBarPosition {
        return UIBarPosition.topAttached
    }
    
    func fetchDirectories() {
        let url = URL(string: "http://\(ip):\(port)/webapi/entry.cgi?api=SYNO.FileStation.List&version=2&method=list_share&_sid=\(sid)") // À passer en https, avec cert let's encrypt
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
            
            if let data_block = server_response["data"] as? NSDictionary
            {
                if let JSON = data_block as? [String: Any] {
                    guard let jsonArray = JSON["shares"] as? [[String: Any]] else {
                        return
                    }
                    for json in jsonArray
                    {
                        self.dirList.append(DirData(json))
                    }
                    DispatchQueue.main.async(
                        execute:self.fetchDone
                    )
                }
            }
        })
        task.resume()
    }
    
    func fetchDone(){
        self.tableView.reloadData()
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dirList.count
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let currentDir = dirList[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as UITableViewCell
        cell.textLabel?.text = currentDir.dirName
        cell.detailTextLabel?.text = currentDir.path
        return cell
    }
    
    @IBAction func logout(_ sender: Any) {
        let preferences = UserDefaults.standard
        preferences.removeObject(forKey: "sid")
        performSegue(withIdentifier: "logout", sender: self)
    }
}

struct DirData {
    var dirName: String
    var path: String
    init(_ dictionary: [String: Any]) {
        self.dirName = dictionary["name"]! as! String
        self.path = dictionary["path"]! as! String
    }
}
