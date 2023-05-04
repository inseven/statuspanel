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

import AVFoundation
import UIKit

protocol QRCodeViewControllerDelegate: AnyObject {

    func qrCodeViewController(_ qrCodeViewController: QRCodeViewController, didDetectURL url: URL) -> Bool
    func qrCodeViewControllerDidCancel(_ qrCodeViewController: QRCodeViewController)

}

class QRCodeViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    weak var delegate: QRCodeViewControllerDelegate? = nil

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?

    private var running = false
    private var isActive = true

    private lazy var cancelButtonItem: UIBarButtonItem = {
        let cancelButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel,
                                               target: self,
                                               action: #selector(cancelTapped(sender:)))
        return cancelButtonItem
    }()

    init() {
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        do {
            guard let captureDevice = AVCaptureDevice.default(for: .video) else {
                print("Failed to get capture device.")
                return
            }

            let input = try AVCaptureDeviceInput(device: captureDevice)
            session.addInput(input)

            let output = AVCaptureMetadataOutput()
            session.addOutput(output)

            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]

            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            previewLayer.frame = view.layer.bounds
            view.layer.addSublayer(previewLayer)
            self.previewLayer = previewLayer

        } catch {
            print("Failed to initialize camera with error \(error).")
        }
    }

    override func viewWillTransition(to size: CGSize,
                                     with transitionCoordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: transitionCoordinator)
        guard let connection = previewLayer?.connection,
              connection.isVideoOrientationSupported
        else {
            return
        }
        switch (UIDevice.current.orientation) {
        case .portrait:
            connection.videoOrientation = .portrait
        case .landscapeRight:
            connection.videoOrientation = .landscapeLeft
        case .landscapeLeft:
            connection.videoOrientation = .landscapeRight
        case .portraitUpsideDown:
            connection.videoOrientation = .portraitUpsideDown
        default:
            connection.videoOrientation = .portrait
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.layer.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        start()
        super.viewWillAppear(animated)
    }

    override func viewDidDisappear(_ animated: Bool) {
        stop()
        super.viewDidDisappear(animated)
    }

    @objc func cancelTapped(sender: UIBarButtonItem) {
        delegate?.qrCodeViewControllerDidCancel(self)
    }

    func start() {
        guard !running else {
            return
        }
        running = true
        isActive = true
        DispatchQueue.global().async {
            // AVCaptureSession is apparently meant to be started on a background thread to avoid blocking in the UI.
            self.session.startRunning()
        }
    }

    func stop() {
        guard running else {
            return
        }
        running = false
        session.stopRunning()
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        dispatchPrecondition(condition: .onQueue(.main))
        guard isActive else {
            return
        }
        if let metaDataObject = metadataObjects.first {
            guard let readableObject = metaDataObject as? AVMetadataMachineReadableCodeObject,
                  let content = readableObject.stringValue,
                  let url = URL(string: content),
                  url.scheme == "statuspanel"
            else {
                return
            }
            guard let delegate else {
                isActive = false
                return
            }
            isActive = !delegate.qrCodeViewController(self, didDetectURL: url)
        }
    }

}
