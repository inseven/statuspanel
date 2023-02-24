// Copyright (c) 2018-2023 Jason Morley, Tom Sutcliffe
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

import Combine
import SwiftUI

import DataStream
import Sodium

// TODO: MainActor?
class ApplicationModel: ObservableObject {

    @Published var identifier: DeviceIdentifier? = nil
    @Published var code: NSImage? = nil
    @Published var lastUpdate: Service.Update? = nil
    @Published var index: Int = 0

    private var cancellables: Set<AnyCancellable> = []

    init() {
        let userDefaults = UserDefaults.standard
        if let publicKey = userDefaults.object(forKey: "publicKey") as? Data,
           let secretKey = userDefaults.object(forKey: "secretKey") as? Data {
            identifier = DeviceIdentifier(id: "aaaaaaaa",
                                          keyPair: Box.KeyPair(publicKey: Array(publicKey),
                                                               secretKey: Array(secretKey)))
        } else {
            let sodium = Sodium()
            let keyPair = sodium.box.keyPair()!
            userDefaults.set(Data(keyPair.publicKey), forKey: "publicKey")
            userDefaults.set(Data(keyPair.secretKey), forKey: "secretKey")
            identifier = DeviceIdentifier(id: "aaaaaaaa", keyPair: keyPair)
        }

        start()
        refresh()
    }

    func start() {

        // TODO: Update the QR code on a different queue
        // TODO: Handle failures more cleanly.
        $identifier
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .map { identifier in
                let sodium = Sodium()
                let publicKeyBase64 = sodium.utils.bin2base64(identifier.keyPair.publicKey, variant: .ORIGINAL)!

                var components = URLComponents()
                components.scheme = "statuspanel"
                components.path = "r2"
                components.queryItems = [
                    URLQueryItem(name: "id", value: "aaaaaaaa"),
                    URLQueryItem(name: "pk", value: publicKeyBase64),
                ]

                return components.url!
            }
            .map { (url: URL) in
                return NSImage.generateQRCode(from: url.absoluteString)!
            }
            .sink { [weak self] image in
                guard let self else { return }
                self.code = image
            }
            .store(in: &cancellables)
    }

    func refresh() {
        Task {
            do {
                let identifier = await MainActor.run {
                    return self.identifier
                }
                guard let identifier = identifier else {
                    return
                }
                let update = try await Service.update(identifier: identifier)
                await MainActor.run {
                    self.lastUpdate = update
                }
            } catch {
                // TODO: Handle the error
                print("Failed to update with error \(error)")
            }
        }
    }

    @MainActor func action() {
        guard let lastUpdate else { return }
        index = (index + 1) % lastUpdate.images.count
    }

}