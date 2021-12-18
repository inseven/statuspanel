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

import SwiftUI
import UIKit

protocol IntroductionViewControllerDelegate: AnyObject {

    func introductionViewControllerDidCancel(_ introductionViewController: IntroductionViewController)
    func introductionViewControllerDidAddDummyDevice(_ introductionViewController: IntroductionViewController)
    func introductionViewControllerDidContinue(_ introductionViewController: IntroductionViewController)

}

class IntroductionViewController: UIHostingController<IntroductionView> {

    class Model: IntroductionViewModel {

        weak var viewController: IntroductionViewController? = nil

        func addDummyDevice() {
            viewController?.add()
        }

        func next() {
            viewController?.next()
        }
    }

    let model = Model()

    lazy var cancelBarButtonItem: UIBarButtonItem = {
        let barButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel,
                                            target: self,
                                            action: #selector(cancelTapped(sender:)))
        return barButtonItem
    }()

    var delegate: IntroductionViewControllerDelegate?

    init() {
        super.init(rootView: IntroductionView(model: model))
        navigationItem.leftBarButtonItem = cancelBarButtonItem
        model.viewController = self
    }

    @objc required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc func cancelTapped(sender: UIBarButtonItem) {
        delegate?.introductionViewControllerDidCancel(self)
    }

    func add() {
        delegate?.introductionViewControllerDidAddDummyDevice(self)
    }

    func next() {
        delegate?.introductionViewControllerDidContinue(self)
    }

}

protocol AddViewControllerDelegate: AnyObject {

    func addViewControllerDidCancel(_ addViewController: AddViewController)
    func addViewController(_ addViewController: AddViewController, didConfigureDevice device: Device)

}

class AddViewController: UINavigationController {

    weak var addDelegate: AddViewControllerDelegate? = nil

    init() {
        let introductionViewController = IntroductionViewController()
        super.init(rootViewController: introductionViewController)
        introductionViewController.delegate = self

    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}

extension AddViewController: IntroductionViewControllerDelegate {

    func introductionViewControllerDidCancel(_ introductionViewController: IntroductionViewController) {
        self.addDelegate?.addViewControllerDidCancel(self)
    }

    func introductionViewControllerDidContinue(_ introductionViewController: IntroductionViewController) {
        let qrCodeViewController = QRCodeViewController(scheme: "statuspanel")
        qrCodeViewController.delegate = self
        qrCodeViewController.navigationItem.leftBarButtonItem = nil
        pushViewController(qrCodeViewController, animated: true)
    }

    func introductionViewControllerDidAddDummyDevice(_ introductionViewController: IntroductionViewController) {
        print("Add dummy device")
    }

}

extension AddViewController: QRCodeViewConrollerDelegate {

    func qrCodeViewController(_ qrCodeViewController: QRCodeViewController, didDetectURL url: URL) {

        guard let operation = ExternalOperation(url: url) else {
            print("Failed to parse URL '\(url)'.")
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
        self.addDelegate?.addViewControllerDidCancel(self)
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
