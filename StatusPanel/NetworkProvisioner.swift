//
//  NetworkProvisioner.swift
//  StatusPanel
//
//  Created by Jason Barrie Morley on 11/06/2020.
//  Copyright © 2020 Tom Sutcliffe. All rights reserved.
//

import Foundation
import Network

enum NetworkProvisionerError: Error {
    case invalidAddress
    case invalidPort
    case cancelled
    case unknown
    case invalidResponse
}

enum NetworkProvisionerResponse: String {
    case ok = "OK"
}

class NetworkProvisioner {

    let address: String
    let port: UInt16
    let syncQueue: DispatchQueue
    let targetQueue: DispatchQueue

    init(address: String, port: UInt16) {
        self.address = address
        self.port = port
        syncQueue = DispatchQueue(label: "syncQueue")
        targetQueue = DispatchQueue(label: "targetQueue", attributes: .concurrent)
    }

    func configure(ssid: String, password: String, completion: @escaping (Result<Bool, Error>) -> Void) {

        let targetQueueCompletion: ((Result<Bool, Error>) -> Void)! = { result in
            self.targetQueue.async {
                completion(result)
            }
        }

        guard let address = IPv4Address(address) else {
            targetQueueCompletion(.failure(NetworkProvisionerError.invalidAddress))
            return
        }
        guard let port = NWEndpoint.Port(rawValue: port) else {
            targetQueueCompletion(.failure(NetworkProvisionerError.invalidPort))
            return
        }

        let host = NWEndpoint.Host.ipv4(address)
        let params = NWParameters.tcp
        params.multipathServiceType = .disabled

        let connection = NWConnection(host: host, port: port, using: params)
        connection.stateUpdateHandler = { state in
            switch state {
            case .setup:
                print("The connection has been initialized but not started.")
            case .waiting(let error):
                print("The connection is waiting for a network path change with transient error '\(error)'.")
            case .preparing:
                print("The connection in the process of being established.")
            case .ready:
                print("The connection is established, and ready to send and receive data.")
                let payload = "\(ssid)\0\(password)".data(using: .utf8)
                connection.send(content: payload!, completion: .contentProcessed( { error in
                    if let error = error {
                        print("Failed to send message with error '\(error)'.")
                        return
                    }
                    print("Succesfully sent configuration message.")
                }))
            case .failed(let error):
                print("The connection has disconnected or encountered an error '\(error)'.")
                targetQueueCompletion(.failure(error))
            case .cancelled:
                print("The connection has been canceled.")
                targetQueueCompletion(.failure(NetworkProvisionerError.cancelled))
            }
        }

        connection.receive(minimumIncompleteLength: 2, maximumLength: 65536) { (data, _, isComplete, error) in
            guard let data = data else {
                targetQueueCompletion(.failure(error ?? NetworkProvisionerError.unknown))
                return
            }
            let response = String(data: data, encoding: .utf8)
            guard response == NetworkProvisionerResponse.ok.rawValue else {
                targetQueueCompletion(.failure(NetworkProvisionerError.invalidResponse))
                return
            }
            targetQueueCompletion(.success(true))
        }
        connection.start(queue: self.syncQueue)
    }

}
