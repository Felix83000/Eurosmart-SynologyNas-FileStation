//
//  FileViewController.swift
//  fido-eurosmart
//
//  Created by FelixMac on 14/06/2019.
//  Copyright © 2019 Eurosmart. All rights reserved.
//

import UIKit
import MobileCoreServices

class FileViewController: UIViewController, UINavigationBarDelegate, UITableViewDelegate, UITableViewDataSource {

    var tabListDirFiles = [[DirFileData]()]// Tableau des différentes requêtes
    var listDirFiles = [DirFileData]()
    var lastId = 0
    fileprivate(set) var currentPath = ""
    fileprivate var network: Network? = nil
    
    /// Creating UIDocumentInteractionController instance.
    fileprivate let documentInteractionController = UIDocumentInteractionController()

    @IBOutlet weak var navBar: UINavigationBar!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var toolBar: UIToolbar!
    @IBOutlet weak var backButton: UIBarButtonItem!
    @IBOutlet weak var generalPath: UINavigationItem!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var addButton: UIBarButtonItem!
    @IBOutlet weak var moreButton: UIBarButtonItem!
    
    lazy var refresher: UIRefreshControl = {
        let refreshControl = UIRefreshControl()
        refreshControl.tintColor = .gray
        refreshControl.addTarget(self, action: #selector(callRefresh), for: .valueChanged)
        return refreshControl
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        /// Setting UIDocumentInteractionController delegate.
        documentInteractionController.delegate = self
        
        tableView.refreshControl = refresher
        
        self.network = Network()
        
        initButtons()
        
        self.network?.fetchDirectories(self)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        let preferences = UserDefaults.standard
        if(preferences.object(forKey: "sid") == nil){
            performSegue(withIdentifier: "logout", sender: self)
        }
    }
    
    @objc
    func callRefresh(){
        if (self.currentPath == "" || self.currentPath == "/"){
            self.network?.fetchDirectories(self,refresh: true)
        }else{
            self.network?.fetchDirectoriesDetails(self, self.currentPath,noBackButton: true,refresh: true)
        }
    }
    
    // MARK: UiNavigationBarDelegate Methods
    func position(for bar: UIBarPositioning) -> UIBarPosition {
        return UIBarPosition.topAttached
    }
    
    func initButtons(){
        backButton.isEnabled = false
        addButton.isEnabled = false
        // Alignement du boutton au centre
        toolBar.sizeToFit()
        let flexible = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: self, action: nil)
        toolBar.items = [flexible,backButton,flexible,flexible,moreButton,flexible]
    }
    
    @IBAction func moreButton(_ sender: Any) {
        // create the alert
        let alert = UIAlertController(title: "About", message: "Félix Herrenschmidt developped this application for Eurosmart as an Intern.", preferredStyle: .alert)
        // add an action (button)
        let linkAction = UIAlertAction(title: "Check his LinkedIn", style: .default) { (_) in
            let linkedinHooks = "linkedin://in/felix-herrenschmidt/"
            if (UIApplication.shared.canOpenURL(URL(string: linkedinHooks)!)){
                UIApplication.shared.open(URL(string: linkedinHooks)!)
            }else{
                UIApplication.shared.open(URL(string:"https://www.linkedin.com/in/felix-herrenschmidt/")!)
            }
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(linkAction)
        // show the alert
        self.present(alert, animated: true, completion: nil)
    }
    
    @IBAction func addButton(_ sender: Any) {
        // TODO: Check permissions to write in the folder path
        
        let alert = UIAlertController(title: "What do you want to do?", message: "Please Select an Option", preferredStyle: .actionSheet)

        alert.addAction(UIAlertAction(title: "Create a Folder", style: .default, handler: { (_) in
            self.showAlertWithTextField()
        }))
        
        alert.addAction(UIAlertAction(title: "Upload a File", style: .default, handler: { (_) in
            let docTypes = [
                "public.data",
                "public.content"
            ]
            let documentPicker = UIDocumentPickerViewController(documentTypes: docTypes, in: .import)
            documentPicker.delegate = self
            self.present(documentPicker, animated: true, completion: nil)
        }))
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler: { (_) in
        }))
        
        self.present(alert, animated: true, completion: {
        })
    }
    
    func showAlertWithTextField() {
        let alertController = UIAlertController(title: "Create a Folder", message: nil, preferredStyle: .alert)
        alertController.textFields?.first?.returnKeyType = UIReturnKeyType.done //Marche pas
        let confirmAction = UIAlertAction(title: "Create", style: .default) { (_) in
            if let txtField = alertController.textFields?.first, let folder = txtField.text {
                // When the user enter the folder name and press "Create"
                self.network?.createFolder(self,folder)
            }
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (_) in }
        alertController.addTextField { (textField) in
            textField.placeholder = "Folder Name"
        }
        alertController.addAction(confirmAction)
        alertController.addAction(cancelAction)
        self.present(alertController, animated: true, completion: nil)
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
            self.currentPath = self.listDirFiles[indexPath.row].path
            backButton.isEnabled = true
            addButton.isEnabled = true
            self.network?.fetchDirectoriesDetails(self,self.listDirFiles[indexPath.row].path,noBackButton: false)
        }else{
            // On ouvre le fichier
            let fileName = String(self.listDirFiles[indexPath.row].path.split(separator: "/", maxSplits: 20, omittingEmptySubsequences:   true).last ?? "file.txt")
            
            // Passing the remote URL of the file, to be stored and then opted with mutliple actions for the user to perform
            let path = self.listDirFiles[indexPath.row].path
            storeAndShare(withURLString: "\(network!.httpType)://\(network!.ip):\(network!.port)/webapi/entry.cgi?api=SYNO.FileStation.Download&version=2&method=download&path=\(path)&mode=open&_sid=\(network!.sid)",fileName: fileName)
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
                self.currentPath = ""
                for str in sub!{
                    if (String(str) as String?) != nil {
                        self.generalPath.title?.append("/")
                        self.currentPath.append("/")
                        self.generalPath.title?.append(String(str))
                        self.currentPath.append(String(str))
                    }
                }
            }else{
                self.generalPath.title = "/"
                self.currentPath = "/"
            }
            self.tableView.reloadData()
            self.lastId-=1
            // On fait disparaitre le bouton de retour si on est à la racine
            if (self.lastId == 0){
                backButton.isEnabled = false
                addButton.isEnabled = false
            }
        }
    }
    
    @IBAction func logout(_ sender: Any) {
        let alertController = UIAlertController(title: "Logout", message: "Are you sure you want to log out?", preferredStyle: .alert)
        let confirmAction = UIAlertAction(title: "Yes", style: .destructive) { (_) in
            let preferences = UserDefaults.standard
            preferences.removeObject(forKey: "sid")
            self.performSegue(withIdentifier: "logout", sender: self)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { (_) in }
        alertController.addAction(cancelAction)
        alertController.addAction(confirmAction)
        self.present(alertController, animated: true, completion: nil)
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

extension FileViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        self.network?.uploadFile(self,urls)
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
        let urlEncoded = URL(string: withURLString.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? "")
        
        guard let url = urlEncoded else { return }
        self.activityIndicator.startAnimating()
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
                self.activityIndicator.stopAnimating()
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
