//
//  NetworkCheck.swift
//  fido-eurosmart
//
//  Created by FelixMac on 25/06/2019.
//  Copyright © 2019 Eurosmart. All rights reserved.
//

import Foundation
import Network

@available(iOS 12.0, *)
protocol NetworkCheckObserver: class {
    /**
     The network status change will trigger this function.
     - Parameter status: Network status
     */
    @available(iOS 12.0, *)
    func statusDidChange(status: NWPath.Status)
}

/// The purpose of the `NetworkCheck` class is to check in background the network status.
@available(iOS 12.0, *)
class NetworkCheck {
    
    struct NetworkChangeObservation {
        weak var observer: NetworkCheckObserver?
    }
    
    fileprivate var monitor = NWPathMonitor()
    fileprivate static let _sharedInstance = NetworkCheck()
    fileprivate var observations = [ObjectIdentifier: NetworkChangeObservation]()
    ///- The network status can be:
    ///   - .satisfied
    ///   - .unsatisfied
    ///   - .requiresConnection
    var currentStatus: NWPath.Status {
        get {
            return monitor.currentPath.status
        }
    }
    
    class func sharedInstance() -> NetworkCheck {
        return _sharedInstance
    }
    init() {
        monitor.pathUpdateHandler = { [unowned self] path in
            for (id, observations) in self.observations {
                
                //If any observer is nil, remove it from the list of observers
                guard let observer = observations.observer else {
                    self.observations.removeValue(forKey: id)
                    continue
                }
                
                DispatchQueue.main.async(execute: {
                    observer.statusDidChange(status: path.status)
                })
            }
        }
        monitor.start(queue: DispatchQueue.global(qos: .background))
    }
    
    func addObserver(observer: NetworkCheckObserver) {
        let id = ObjectIdentifier(observer)
        observations[id] = NetworkChangeObservation(observer: observer)
    }
    
    func removeObserver(observer: NetworkCheckObserver) {
        let id = ObjectIdentifier(observer)
        observations.removeValue(forKey: id)
    }
}
