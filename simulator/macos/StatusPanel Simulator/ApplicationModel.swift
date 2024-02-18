// Copyright (c) 2018-2024 Jason Morley, Tom Sutcliffe
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

import Sodium

// TODO: MainActor?
class ApplicationModel: ObservableObject {

    @MainActor @Published var devices: [DeviceModel] = [] {
        didSet {
            do {
                let configurations = devices
                    .map { $0.configuration }
                let encoder = JSONEncoder()
                let data = try encoder.encode(configurations)
                UserDefaults.standard.set(data, forKey: "configurations")
            } catch {
                print("Failed to store configurations with error \(error).")
            }
        }
    }

    init() {
        DispatchQueue.main.async {
            self.start()
        }
    }

    @MainActor func start() {
        if let data = UserDefaults.standard.object(forKey: "configurations") as? Data,
           let configurations = try? JSONDecoder().decode([DeviceConfiguration].self, from: data) {
            devices = configurations
                .map { DeviceModel(identifier: $0) }
        } else {
            devices = [DeviceModel(identifier: DeviceConfiguration(kind: .einkV1))]
        }
        devices.forEach { deviceModel in
            deviceModel.start()
        }
    }

    @MainActor func remove(device: DeviceModel) {
        devices.removeAll { $0.configuration == device.configuration }
    }

}
