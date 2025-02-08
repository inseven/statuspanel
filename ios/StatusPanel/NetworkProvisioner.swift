// Copyright (c) 2018-2025 Jason Morley, Tom Sutcliffe
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import Foundation
import Network

enum NetworkProvisionerError: Error {
    case invalidAddress
    case invalidPort
    case cancelled
    case unknown
    case invalidResponse
    case badCredentials // The device reported the credentials didn't work
}

enum NetworkProvisionerResponse: String {
    case ok = "OK"
    case no = "NO"
}

class NetworkProvisioner {

    let address: String
    let port: UInt16
    let syncQueue: DispatchQueue
    let targetQueue = DispatchQueue.main
    private var connection: NWConnection?

    init(address: String, port: UInt16) {
        self.address = address
        self.port = port
        syncQueue = DispatchQueue(label: "syncQueue")
    }

    func configure(ssid: String, password: String, certificates: String, completion: @escaping (Result<Bool, Error>) -> Void) {

        var completed = false
        let targetQueueCompletion: ((Result<Bool, Error>) -> Void)! = { result in
            if !completed {
                completed = true
                self.connection?.cancel()
                self.connection = nil
                self.targetQueue.async {
                    completion(result)
                }
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
        self.connection = connection
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
                let payload = "\(ssid)\0\(password)\0\(certificates)\0".data(using: .utf8)
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
            @unknown default:
                print("wat")
            }
        }

        connection.receive(minimumIncompleteLength: 2, maximumLength: 65536) { (data, _, isComplete, error) in
            guard let data = data else {
                targetQueueCompletion(.failure(error ?? NetworkProvisionerError.unknown))
                return
            }
            let response = NetworkProvisionerResponse(rawValue: String(data: data, encoding: .utf8) ?? "")
            if response == .ok {
                targetQueueCompletion(.success(true))
            } else if response == .no {
                targetQueueCompletion(.failure(NetworkProvisionerError.badCredentials))
            } else {
                targetQueueCompletion(.failure(NetworkProvisionerError.invalidResponse))
            }
        }
        connection.start(queue: self.syncQueue)
    }

}
