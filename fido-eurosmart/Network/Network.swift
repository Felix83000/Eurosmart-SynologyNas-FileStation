//
//  Network.swift
//  fido-eurosmart
//
//  Created by FelixMac on 25/06/2019.
//  Copyright © 2019 Eurosmart. All rights reserved.
//
import UIKit

final class Network {
    fileprivate(set) var ip = "172.16.103.116"
    fileprivate(set) var port = "1987" // 1988 : https, 1987: http
    fileprivate(set) var httpType = "http"
    var sid = "none"
    
    init() {
        let preferences = UserDefaults.standard
        if(preferences.object(forKey: "sid") != nil){
            self.sid = preferences.object(forKey: "sid") as? String ?? "none"
        }else{
            self.sid = "none"
        }
    }
    
    func doLogin(_ viewController: ViewController,_ user:String,_ pwd:String)
    {
        viewController.activityIndicator.startAnimating()
        
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
                            viewController.activityIndicator.stopAnimating()
                            // create the alert
                            let alert = UIAlertController(title: "Identification problem", message: "The account or password is not valid. Please try again.", preferredStyle: .alert)
                            // add an action (button)
                            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                            // show the alert
                            viewController.present(alert, animated: true, completion: nil)
                            viewController.password.text = ""
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
                    //Setting the session key attribute
                    self.sid = session_data
                    DispatchQueue.main.async {
                        viewController.activityIndicator.stopAnimating()
                    }
                    DispatchQueue.main.async(
                        execute:viewController.loginDone
                    )
                }
            }
        })
        task.resume()
    }
    
    func createFolder(_ fileViewController: FileViewController,_ folderName: String){
        fileViewController.activityIndicator.startAnimating()

        var folderPath = fileViewController.currentPath
        if(folderPath == ""){
            folderPath = "/"
        }
        let urlOriginal = "\(httpType)://\(ip):\(port)/webapi/entry.cgi?api=SYNO.FileStation.CreateFolder&version=2&method=create&folder_path=\(folderPath)&name=\(folderName)&_sid=\(sid)"// À passer en https, avec cert let's encrypt
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
                    if (code == 1100){
                        DispatchQueue.main.async {
                            // create the alert
                            let alert = UIAlertController(title: "Folder Creation Problem", message: "Maybe there is a rights problem. Feel free to contact the administrator.", preferredStyle: .alert)
                            // add an action (button)
                            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                            // show the alert
                            fileViewController.present(alert, animated: true, completion: nil)
                        }
                    }
                    if (code == 400){
                        DispatchQueue.main.async {
                            // create the alert
                            let alert = UIAlertController(title: "Folder Creation Problem", message: "Please enter a name for the folder.", preferredStyle: .alert)
                            // add an action (button)
                            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                            // show the alert
                            fileViewController.present(alert, animated: true, completion: nil)
                        }
                    }
                    DispatchQueue.main.async {
                        fileViewController.activityIndicator.stopAnimating()
                    }
                }
            }
            if (server_response["data"] as? NSDictionary) != nil
            {
                DispatchQueue.main.async {
                    fileViewController.activityIndicator.stopAnimating()
                    self.fetchDirectoriesDetails(fileViewController,folderPath,noBackButton: true)
                }
            }
        })
        task.resume()
    }
    
    func fetchDirectories(_ fileViewController: FileViewController, refresh: Bool=false) {
        if(!refresh){
            fileViewController.activityIndicator.startAnimating()
        }
        
        let urlOriginal = "\(httpType)://\(ip):\(port)/webapi/entry.cgi?api=SYNO.FileStation.List&version=2&method=list_share&_sid=\(sid)"// À passer en https, avec cert let's encrypt
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
            if let data_block = server_response["data"] as? NSDictionary
            {
                if let JSON = data_block as? [String: Any] {
                    guard let jsonArray = JSON["shares"] as? [[String: Any]] else {
                        return
                    }
                    fileViewController.listDirFiles.removeAll()
                    for json in jsonArray
                    {
                        fileViewController.listDirFiles.append(DirFileData(json))
                    }
                    fileViewController.tabListDirFiles[0] = fileViewController.listDirFiles
                    DispatchQueue.main.async {
                        if(fileViewController.activityIndicator.isAnimating){
                            fileViewController.activityIndicator.stopAnimating()
                        }
                    }
                    DispatchQueue.main.async(
                        execute:fileViewController.fetchDone
                    )
                    if(refresh){
                        let deadLine = DispatchTime.now() + .milliseconds(700)
                        DispatchQueue.main.asyncAfter(deadline: deadLine){
                            fileViewController.refresher.endRefreshing()
                        }
                    }
                }
            }
        })
        task.resume()
    }
    
    func fetchDirectoriesDetails(_ fileViewController: FileViewController,_ folder_path: String, noBackButton: Bool, refresh: Bool=false) {
        if(!refresh){
            fileViewController.activityIndicator.startAnimating()
        }
        let urlOriginal = "\(httpType)://\(ip):\(port)/webapi/entry.cgi?api=SYNO.FileStation.List&version=2&method=list&folder_path=\(folder_path)&_sid=\(sid)"// À passer en https, avec cert let's encrypt
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
            if let data_block = server_response["data"] as? NSDictionary
            {
                if let JSON = data_block as? [String: Any] {
                    guard let jsonArray = JSON["files"] as? [[String: Any]] else {
                        return
                    }
                    if(!noBackButton){
                        fileViewController.lastId+=1
                        fileViewController.tabListDirFiles.insert(fileViewController.listDirFiles, at: fileViewController.lastId)
                    }
                    fileViewController.listDirFiles.removeAll()
                    for json in jsonArray
                    {
                        fileViewController.listDirFiles.append(DirFileData(json))
                    }
                    DispatchQueue.main.async {
                        if(fileViewController.activityIndicator.isAnimating){
                            fileViewController.activityIndicator.stopAnimating()
                        }
                    }
                    DispatchQueue.main.async(
                        execute:fileViewController.fetchDone
                    )
                    if(refresh){
                        let deadLine = DispatchTime.now() + .milliseconds(700)
                        DispatchQueue.main.asyncAfter(deadline: deadLine){
                            fileViewController.refresher.endRefreshing()
                        }
                    }
                }
            }
        })
        task.resume()
    }
    
    func uploadFile(_ fileViewController: FileViewController,_ urls: [URL]){
        guard let selectedFileURL = urls.first else {
            return
        }
        do {
            fileViewController.activityIndicator.startAnimating()
            // Lecture du fichier pour la représentation en data
            var documentData = Data()
            documentData.append(try Data(contentsOf: urls.first!))
            
            var folderPath = fileViewController.currentPath
            if(folderPath == ""){
                folderPath = "/"
            }
            
            let urlOriginal = "\(httpType)://\(ip):\(port)/webapi/entry.cgi"// À passer en https, avec cert let's encrypt
            let url = URL(string: urlOriginal.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? "")
            
            let session = URLSession.shared
            let boundary = "Boundary-\(UUID().uuidString)"
            
            var request = URLRequest(url: url!,cachePolicy: URLRequest.CachePolicy.useProtocolCachePolicy,timeoutInterval: 60)
            request.httpMethod = "POST"
            request.httpShouldHandleCookies = true
            let body = self.createBody(contentFile: documentData, folderPath, selectedFileURL,boundary)
            request.httpBody = body as Data
            request.addValue(String(describing: body.length), forHTTPHeaderField: "Content-Length")
            request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
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
                        if (code == 414){
                            DispatchQueue.main.async {
                                // create the alert
                                let alert = UIAlertController(title: "Upload Problem", message: "File already exists.", preferredStyle: .alert)
                                // add an action (button)
                                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                                // show the alert
                                fileViewController.present(alert, animated: true, completion: nil)
                            }
                        }
                        if (code == 407){
                            DispatchQueue.main.async {
                                // create the alert
                                let alert = UIAlertController(title: "Upload Problem", message: "Maybe there is a rights problem. Feel free to contact the administrator.", preferredStyle: .alert)
                                // add an action (button)
                                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                                // show the alert
                                fileViewController.present(alert, animated: true, completion: nil)
                            }
                        }
                        DispatchQueue.main.async {
                            fileViewController.activityIndicator.stopAnimating()
                        }
                    }
                }
                if (server_response["data"] as? NSDictionary) != nil
                {
                    DispatchQueue.main.async {
                        fileViewController.activityIndicator.stopAnimating()
                        self.fetchDirectoriesDetails(fileViewController,folderPath,noBackButton: true)
                    }
                }
            })
            task.resume()
            
        } catch {
            print("no data")
        }
    }
    
    func createBody(contentFile: Data,_ folderPath: String,_ selectedFileUrl: URL,_ boundary: String) -> NSMutableData {
        let body = NSMutableData()
        
        body.append(String("--\(boundary)\r\n").data(using: .utf8)!)
        body.append(String("content-disposition: form-data; name=\"api\"\r\n\r\nSYNO.FileStation.Upload").data(using: .utf8)!)
        
        body.append(String("\r\n--\(boundary)\r\n").data(using: .utf8)!)
        body.append(String("content-disposition: form-data; name=\"version\"\r\n\r\n2").data(using: .utf8)!)
        
        body.append(String("\r\n--\(boundary)\r\n").data(using: .utf8)!)
        body.append(String("content-disposition: form-data; name=\"method\"\r\n\r\nupload").data(using: .utf8)!)
        
        body.append(String("\r\n--\(boundary)\r\n").data(using: .utf8)!)
        body.append(String("content-disposition: form-data; name=\"_sid\"\r\n\r\n\(sid)").data(using: .utf8)!)
        
        body.append(String("\r\n--\(boundary)\r\n").data(using: .utf8)!)
        body.append(String("content-disposition: form-data; name=\"path\"\r\n\r\n\(folderPath)").data(using: .utf8)!)
        
        body.append(String("\r\n--\(boundary)\r\n").data(using: .utf8)!)
        body.append(String("content-disposition: form-data; name=\"create_parents\"\r\n\r\ntrue").data(using: .utf8)!)
        
        body.append(String("\r\n--\(boundary)\r\n").data(using: .utf8)!)
        print("selectedFileUrl.lastPathComponent : ",selectedFileUrl.lastPathComponent)
        body.append(String("content-disposition: form-data; name=\"\(selectedFileUrl.lastPathComponent)\";filename=\"\(selectedFileUrl.lastPathComponent)\"\r\n").data(using: .utf8)!)
        body.append(String("Content-Type: application/octet-stream\r\n\r\n").data(using: .utf8)!)
        body.append(contentFile)
        
        body.append(String("\r\n--\(boundary)--\r\n").data(using: .utf8)!)
        
        return body
    }
    
    func deleteFile(_ fileViewController: FileViewController,_ path: String){
        fileViewController.activityIndicator.startAnimating()
        
        let urlOriginal = "\(httpType)://\(ip):\(port)/webapi/entry.cgi?api=SYNO.FileStation.Delete&version=2&method=delete&path=\(path)&_sid=\(sid)"// À passer en https, avec cert let's encrypt
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
                    if (code == 900){
                        DispatchQueue.main.async {
                            // create the alert
                            let alert = UIAlertController(title: "Delete Problem", message: "Maybe there is a rights problem. Feel free to contact the administrator.", preferredStyle: .alert)
                            // add an action (button)
                            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                            // show the alert
                            fileViewController.present(alert, animated: true, completion: nil)
                        }
                    }
                    DispatchQueue.main.async {
                        fileViewController.activityIndicator.stopAnimating()
                    }
                }
            }else{
                DispatchQueue.main.async {
                    fileViewController.activityIndicator.stopAnimating()
                    self.fetchDirectoriesDetails(fileViewController,fileViewController.currentPath,noBackButton: true)
                }
            }
        })
        task.resume()
    }
}
