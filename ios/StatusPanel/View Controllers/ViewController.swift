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

import UIKit
import EventKit

import Sodium

class ViewController: UIViewController, SettingsViewControllerDelegate {

    private var image: UIImage?
    private var redactedImage: UIImage?

    var sourceController: DataSourceController!

    private lazy var settingsButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(image: UIImage(systemName: "gear"),
                               style: .plain,
                               target: self,
                               action: #selector(settingsTapped(sender:)))
    }()

    private lazy var refreshButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .refresh,
                               target: self,
                               action: #selector(refreshTapped(sender:)))
    }()

    private lazy var addButtonItem: UIBarButtonItem = {
        let configuration = UIImage.SymbolConfiguration(pointSize: 24)
        let image = UIImage(systemName: "plus", withConfiguration: configuration)!
        let button = UIButton()
        button.setImage(image, for: .normal)
        button.addTarget(self, action: #selector(addTapped(sender:)), for: .touchUpInside)
        button.addGestureRecognizer(UILongPressGestureRecognizer(target: self,
                                                                 action: #selector(addLongPress(sender:))))
        return UIBarButtonItem(customView: button)
    }()

    private lazy var activityIndicator: UIActivityIndicatorView = {
        let activityIndicator = UIActivityIndicatorView()
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        activityIndicator.color = .systemGray
        activityIndicator.hidesWhenStopped = true
        return activityIndicator
    }()

    private lazy var imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isUserInteractionEnabled = true
        imageView.contentMode = .scaleAspectFit
        return imageView
    }()

    private lazy var longPressGestureRecognizer: UIGestureRecognizer = {
        let gestureRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(imageTapped(recognizer:)))
        gestureRecognizer.minimumPressDuration = 0
        return gestureRecognizer
    }()

    init() {
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = .systemGroupedBackground
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        sourceController = AppDelegate.shared.sourceController

        title = "StatusPanel"
        navigationItem.leftBarButtonItem = settingsButtonItem
        navigationItem.rightBarButtonItems = [addButtonItem, refreshButtonItem]

        view.addSubview(imageView)
        imageView.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: view.layoutMarginsGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: view.layoutMarginsGuide.bottomAnchor),
            activityIndicator.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: imageView.centerYAnchor),
        ])

        imageView.addGestureRecognizer(longPressGestureRecognizer)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        fetch()
    }

    @objc func settingsTapped(sender: Any) {
        let settingsViewController = SettingsViewController()
        let viewController = UINavigationController(rootViewController: settingsViewController)
        settingsViewController.delegate = self
        present(viewController, animated: true, completion: nil)
    }

    @objc func refreshTapped(sender: Any) {
        Config().clearUploadHashes()  // Wipe all stored hashes to force re-upload on completion.
        fetch()
    }

    @objc func addTapped(sender: Any) {
        let viewController = AddViewController()
        viewController.addDelegate = self
        present(viewController, animated: true)
    }

    @objc func addLongPress(sender: UILongPressGestureRecognizer) {
        guard sender.state == .began else {
            return
        }
        guard let clipboard = UIPasteboard.general.string,
           let url = URL(string: clipboard) else {
            return
        }
        _ = AppDelegate.shared.application(UIApplication.shared, open: url, options: [:])
    }

    @objc func imageTapped(recognizer: UIGestureRecognizer) {
        switch recognizer.state {
        case .began:
            imageView.image = redactedImage
        case .ended, .cancelled, .failed:
            imageView.image = image
        case .possible, .changed:
            break
        @unknown default:
            break
        }
    }

    func didDismiss(settingsViewController: SettingsViewController) {
        fetch()
    }

    func fetch() {
        dispatchPrecondition(condition: .onQueue(.main))
        let blankImage = Panel.blankImage()
        self.image = blankImage
        self.redactedImage = blankImage
        UIView.transition(with: self.imageView,
                          duration: 0.3,
                          options: .transitionCrossDissolve) {
            self.imageView.image = blankImage
        }
        self.refreshButtonItem.isEnabled = false
        activityIndicator.startAnimating()

        sourceController.fetch { items, error in
            dispatchPrecondition(condition: .onQueue(.main))

            guard let items = items else {
                if let error {
                    self.present(error: error)
                }
                self.fetchDidComplete()
                return
            }

            let config = Config()
            let images = Renderer.render(data: items, config: config, device: Device())
            self.fetchDidUpdate(image: images[0], privacyImage: images[1])

            let devices = config.devices
            var pendingDevices = Set(devices)
            var anyChanges = false
            for device in devices {
                let images = Renderer.render(data: items, config: config, device: device)

                let client = AppDelegate.shared.client
                let payloads = Panel.rlePayloads(for: images)

                let completion = { (didUpload: Bool) in
                    DispatchQueue.main.async {
                        pendingDevices.remove(device)
                        if didUpload {
                            anyChanges = true
                        }
                        if pendingDevices.isEmpty {
                            DispatchQueue.main.async {
                                AppDelegate.shared.fetchCompleted(hasChanged: anyChanges)
                                self.fetchDidComplete()
                            }
                        }
                    }
                }
                let clientPayloads = device.kind == .einkV1 ? payloads.map { $0.0 } : payloads.map { $0.1.pngData()! }
                client.upload(clientPayloads, device: device, completion: completion)
            }
        }
    }

    func fetchDidUpdate(image: UIImage, privacyImage: UIImage) {
        self.image = image
        self.redactedImage = privacyImage
        activityIndicator.stopAnimating()
        UIView.transition(with: self.imageView,
                          duration: 0.3,
                          options: .transitionCrossDissolve) {
            self.imageView.image = image
        }
    }

    func fetchDidComplete() {
        dispatchPrecondition(condition: .onQueue(.main))
        self.refreshButtonItem.isEnabled = true
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        BitmapFontCache.shared.emptyCache()
    }

}

extension ViewController: AddViewControllerDelegate {
    
    func addViewControllerDidCancel(_ addViewController: AddViewController) {
        addViewController.dismiss(animated: true)
    }

    func addViewController(_ addViewController: AddViewController, didConfigureDevice device: Device) {
        addViewController.dismiss(animated: true) {
            AppDelegate.shared.addDevice(device)
        }
    }

}
