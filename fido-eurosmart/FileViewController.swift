//
//  FileViewController.swift
//  fido-eurosmart
//
//  Created by FelixMac on 14/06/2019.
//  Copyright © 2019 Eurosmart. All rights reserved.
//

import UIKit

class FileViewController: UIViewController, UINavigationBarDelegate, UITableViewDelegate, UITableViewDataSource {

    var tabListDirFiles = [[DirFileData]()]// Tableau des différentes requêtes
    var lastId = 0
    var listDirFiles = [DirFileData]()
    let ip = "172.16.103.116"
    let port = "1987" // 1988 : https, 1987: http
    var sid = ""

    @IBOutlet weak var navBar: UINavigationBar!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var toolBar: UIToolbar!
    @IBOutlet weak var backButton: UIBarButtonItem!
    @IBOutlet weak var generalPath: UINavigationItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navBar.delegate = self

        initBackButton()
        
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
    
    func initBackButton(){
        backButton.title = ""
        // Alignement du boutton au centre
        toolBar.sizeToFit()
        let flexible = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: self, action: nil)
        toolBar.items = [flexible,backButton,flexible]
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
                        self.listDirFiles.append(DirFileData(json))
                    }
                    self.tabListDirFiles[0] = self.listDirFiles
                    DispatchQueue.main.async(
                        execute:self.fetchDone
                    )
                }
            }
        })
        task.resume()
    }
    
    func fetchDirectoriesDetails(_ folder_path:String) {
        backButton.title = "Back"
        let path = folder_path.replacingOccurrences(of: " ", with: "%20") // Gestion des espaces
        let url = URL(string: "http://\(ip):\(port)/webapi/entry.cgi?api=SYNO.FileStation.List&version=2&method=list&folder_path=\(path)&_sid=\(sid)") // À passer en https, avec cert let's encrypt
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
                    guard let jsonArray = JSON["files"] as? [[String: Any]] else {
                        return
                    }
                    self.lastId+=1
                    self.tabListDirFiles.insert(self.listDirFiles, at: self.lastId)
                    self.listDirFiles.removeAll()
                    for json in jsonArray
                    {
                        self.listDirFiles.append(DirFileData(json))
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
        return listDirFiles.count
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if(self.listDirFiles[indexPath.row].isDir == true){
            self.generalPath.title = self.listDirFiles[indexPath.row].path
            fetchDirectoriesDetails(self.listDirFiles[indexPath.row].path)
        }else{
            print("It is a file")
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let currentDir = listDirFiles[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as UITableViewCell
        if(currentDir.isDir == true){
            let image : UIImage = UIImage(named: "folderIcon100")!
            cell.imageView!.image = image
        }else{
            let image : UIImage = UIImage(named: "fileIcon100")!
            cell.imageView!.image = image
        }
        cell.textLabel?.text = currentDir.dirName
        return cell
    }
    
    @IBAction func backButton(_ sender: Any) {
        // Si on n'est pas au dossier racine
        if (self.lastId != 0){
            self.listDirFiles.removeAll()
            self.listDirFiles = self.tabListDirFiles[self.lastId]
            // On change le chemin affiché dans le titre de la navbar
            if (self.lastId != 1){
                var sub = self.tabListDirFiles[self.lastId].last?.path.split(separator: "/", maxSplits: 10, omittingEmptySubsequences:   true)
                sub?.removeLast()
                self.generalPath.title?.removeAll()
                for str in sub!{
                    if (String(str) as String?) != nil {
                        self.generalPath.title?.append("/")
                        self.generalPath.title?.append(String(str))
                    }
                }
            }else{
                self.generalPath.title = "/"
            }
            self.tableView.reloadData()
            self.lastId-=1
            // On fait disparaitre le bouton de retour si on est à la racine
            if (self.lastId == 0){
                backButton.title = ""
            }
        }
    }
    
    @IBAction func logout(_ sender: Any) {
        let preferences = UserDefaults.standard
        preferences.removeObject(forKey: "sid")
        performSegue(withIdentifier: "logout", sender: self)
    }
}

struct DirFileData {
    var isDir: Bool
    var dirName: String
    var path: String
    init(_ dictionary: [String: Any]) {
        self.isDir = dictionary["isdir"]! as! Bool
        self.dirName = dictionary["name"]! as! String
        self.path = dictionary["path"]! as! String
    }
}
