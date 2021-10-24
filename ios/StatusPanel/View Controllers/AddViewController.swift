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

import UIKit

protocol AddViewControllerDelegate: AnyObject {

    func addViewControllerDidCancel(_ addViewController: AddViewController)
    func addViewController(_ addViewController: AddViewController, didConfigureDevice device: Device)

}

class AddViewController: UINavigationController {

    weak var addDelegate: AddViewControllerDelegate? = nil

    private var qrCodeViewController: QRCodeViewController

    init() {
        qrCodeViewController = QRCodeViewController(scheme: "statuspanel")
        super.init(rootViewController: qrCodeViewController)
        qrCodeViewController.delegate = self
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

extension AddViewController: QRCodeViewConrollerDelegate {

    func qrCodeViewController(_ qrCodeViewController: QRCodeViewController, didDetectURL url: URL) {

        guard let operation = ExternalOperation(url: url) else {
            print("Failed to parse URL '\(url)'.")
            dismiss(animated: true) {
                AppDelegate.shared.qrcodeParseFailed(url)
            }
            return
        }

        switch operation {
        case .registerDevice(let device):
            self.addDelegate?.addViewController(self, didConfigureDevice: device)
            return
        case .registerDeviceAndConfigureWiFi(let device, ssid: let ssid):
            let viewController = WifiProvisionerController(device: device, ssid: ssid)
            viewController.navigationItem.leftBarButtonItem = nil
            viewController.delegate = self
            self.pushViewController(viewController, animated: true)
        }
    }

    func qrCodeViewControllerDidCancel(_ qrCodeViewController: QRCodeViewController) {
        dismiss(animated: true) {
            self.addDelegate?.addViewControllerDidCancel(self)
        }

    }

}

extension AddViewController: WifiProvisionerControllerDelegate {

    func wifiProvisionerController(_ wifiProvisionerController: WifiProvisionerController,
                                   didConfigureDevice device: Device) {
        self.addDelegate?.addViewController(self, didConfigureDevice: device)
    }

    func wifiProvisionerControllerDidCancel(_ wifiProvisionerController: WifiProvisionerController) {
        self.addDelegate?.addViewControllerDidCancel(self)
    }

}
