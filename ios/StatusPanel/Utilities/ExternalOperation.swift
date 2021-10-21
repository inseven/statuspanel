// Copyright (c) 2018-2021 Jason Morley, Tom Sutcliffe
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

enum ExternalOperation: Equatable {

    case registerDevice(Device)
    case registerDeviceAndConfigureWiFi(Device, ssid: String)

    init?(url: URL) {

        guard let components = NSURLComponents(url: url, resolvingAgainstBaseURL: true),
            let operation = components.path,
            let params = components.queryItems else {
                return nil
            }

        var map: [String : String] = [:]
        for queryItem in params {
            if let val = queryItem.value {
                map[queryItem.name] = val
            }
        }

        switch operation {
        case "r":
            guard let id = map["id"],
                  let publicKey = map["pk"] else {
                      return nil
                  }
            let device = Device(id: id, publicKey: publicKey)
            if let ssid = map["s"] {
                self = .registerDeviceAndConfigureWiFi(device, ssid: ssid)
            } else {
                self = .registerDevice(device)
            }
            return
        default:
            return nil
        }

    }

    var url: URL {
        switch self {
        case .registerDevice(let device):
            return URL(string: "statuspanel:r")!.settingQueryItems([
                URLQueryItem(name: "id", value: device.id),
                URLQueryItem(name: "pk", value: device.publicKey),
            ])!
        case .registerDeviceAndConfigureWiFi(let device, ssid: let ssid):
            return URL(string: "statuspanel:r")!.settingQueryItems([
                URLQueryItem(name: "id", value: device.id),
                URLQueryItem(name: "pk", value: device.publicKey),
                URLQueryItem(name: "s", value: ssid),
            ])!
        }
    }

}
