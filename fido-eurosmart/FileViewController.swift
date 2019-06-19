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
    let httpType = "http"
    var sid = ""
    
    /// Creating UIDocumentInteractionController instance.
    let documentInteractionController = UIDocumentInteractionController()

    @IBOutlet weak var navBar: UINavigationBar!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var toolBar: UIToolbar!
    @IBOutlet weak var backButton: UIBarButtonItem!
    @IBOutlet weak var generalPath: UINavigationItem!
    @IBOutlet weak var actvityIndicator: UIActivityIndicatorView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navBar.delegate = self
        
        /// Setting UIDocumentInteractionController delegate.
        documentInteractionController.delegate = self
        
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
        self.actvityIndicator.startAnimating()
        let preferences = UserDefaults.standard
        self.sid = String(describing:preferences.object(forKey: "sid")!)
        let url = URL(string: "\(httpType)://\(ip):\(port)/webapi/entry.cgi?api=SYNO.FileStation.List&version=2&method=list_share&_sid=\(sid)") // À passer en https, avec cert let's encrypt
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
                    DispatchQueue.main.async {
                        self.actvityIndicator.stopAnimating()
                    }
                    DispatchQueue.main.async(
                        execute:self.fetchDone
                    )
                }
            }
        })
        task.resume()
    }
    
    func fetchDirectoriesDetails(_ folder_path:String) {
        self.actvityIndicator.startAnimating()
        backButton.title = "Back"
        let path = folder_path.replacingOccurrences(of: " ", with: "%20") // Gestion des espaces
        let url = URL(string: "\(httpType)://\(ip):\(port)/webapi/entry.cgi?api=SYNO.FileStation.List&version=2&method=list&folder_path=\(path)&_sid=\(sid)") // À passer en https, avec cert let's encrypt
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
                    DispatchQueue.main.async {
                        self.actvityIndicator.stopAnimating()
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
            // On ouvre le fichier
            let fileName = String(self.listDirFiles[indexPath.row].path.split(separator: "/", maxSplits: 20, omittingEmptySubsequences:   true).last ?? "file.txt")
            /// Passing the remote URL of the file, to be stored and then opted with mutliple actions for the user to perform
            let path = self.listDirFiles[indexPath.row].path.replacingOccurrences(of: " ", with: "%20") // Gestion des espaces
            storeAndShare(withURLString: "\(httpType)://\(ip):\(port)/webapi/entry.cgi?api=SYNO.FileStation.Download&version=2&method=download&path=\(path)&mode=open&_sid=\(sid)",fileName: fileName)
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let currentDir = listDirFiles[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as UITableViewCell
        if(currentDir.isDir == true){
            let image : UIImage = UIImage(named: "folderIcon")!
            cell.imageView!.image = image
        }else{
            let image : UIImage = UIImage(named: "fileIcon")!
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
                var sub = self.tabListDirFiles[self.lastId].last?.path.split(separator: "/", maxSplits: 20, omittingEmptySubsequences:   true)
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

extension FileViewController {
    /// This function will set all the required properties, and then provide a preview for the document
    func share(url: URL) {
        documentInteractionController.url = url
        documentInteractionController.uti = url.typeIdentifier ?? "public.data, public.content"
        documentInteractionController.name = url.localizedName ?? url.lastPathComponent
        documentInteractionController.presentPreview(animated: true)
    }
    
    /// This function will store your document to some temporary URL and then provide sharing, copying, printing, saving options to the user
    func storeAndShare(withURLString: String, fileName: String) {
        self.actvityIndicator.startAnimating()
        guard let url = URL(string: withURLString) else { return }
        /// START YOUR ACTIVITY INDICATOR HERE
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else { return }
            let tmpURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(fileName)
            do {
                try data.write(to: tmpURL)
            } catch {
                print(error)
            }
            DispatchQueue.main.async {
                /// STOP YOUR ACTIVITY INDICATOR HERE
                self.actvityIndicator.stopAnimating()
                self.share(url: tmpURL)
            }
            }.resume()
    }
}

extension FileViewController: UIDocumentInteractionControllerDelegate {
    /// If presenting atop a navigation stack, provide the navigation controller in order to animate in a manner consistent with the rest of the platform
    func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        guard let navVC = self.navigationController else {
            return self
        }
        return navVC
    }
}

extension URL {
    var typeIdentifier: String? {
        return (try? resourceValues(forKeys: [.typeIdentifierKey]))?.typeIdentifier
    }
    var localizedName: String? {
        return (try? resourceValues(forKeys: [.localizedNameKey]))?.localizedName
    }
}
