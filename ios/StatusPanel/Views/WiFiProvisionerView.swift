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

import SwiftUI

struct WiFiProvisionerView: UIViewControllerRepresentable {

    class Coordinator: NSObject, WifiProvisionerViewControllerDelegate {

        let parent: WiFiProvisionerView

        init(_ parent: WiFiProvisionerView) {
            self.parent = parent
        }

        func wifiProvisionerViewController(_ wifiProvisionerViewController: WifiProvisionerViewController,
                                       didConfigureDevice device: Device) {
            parent.completion(device)
        }

        func wifiProvisionerViewControllerDidCancel(_ wifiProvisionerViewController: WifiProvisionerViewController) {
            parent.cancel()
        }

    }

    let device: Device
    let ssid: String

    let completion: (Device) -> Void
    let cancel: () -> Void

    func makeUIViewController(context: Context) -> some UIViewController {
        let viewController = WifiProvisionerViewController(device: device, ssid: ssid)
        viewController.delegate = context.coordinator
        return viewController
    }

    func updateUIViewController(_ viewController: UIViewControllerType, context: Context) {
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

}
