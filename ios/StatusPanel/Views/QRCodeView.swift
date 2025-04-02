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

import SwiftUI

struct QRCodeView: UIViewControllerRepresentable {

    class Coordinator: NSObject, QRCodeViewControllerDelegate {

        let parent: QRCodeView

        init(_ parent: QRCodeView) {
            self.parent = parent
        }

        func qrCodeViewController(_ qrCodeViewController: QRCodeViewController, didDetectURL url: URL) -> Bool {
            return parent.completion(url)
        }

        func qrCodeViewControllerDidCancel(_ qrCodeViewController: QRCodeViewController) {
        }

    }

    let completion: (URL) -> Bool

    func makeUIViewController(context: Context) -> some UIViewController {
        let viewController = QRCodeViewController()
        viewController.delegate = context.coordinator
        return viewController
    }

    func updateUIViewController(_ viewController: UIViewControllerType, context: Context) {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = UIColor.clear
        appearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)
        viewController.parent?.navigationItem.standardAppearance = appearance
        viewController.parent?.navigationItem.scrollEdgeAppearance = appearance
        viewController.parent?.navigationItem.compactAppearance = appearance
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

}
