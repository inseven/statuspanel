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
import EventKit
import SwiftUI
import UIKit

import Sodium

class ViewController: UIViewController {

    private var image: UIImage?
    private var redactedImage: UIImage?

    let config: Config
    var cancellables: Set<AnyCancellable> = []

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

    init(config: Config) {
        self.config = config
        super.init(nibName: nil, bundle: nil)
        view.backgroundColor = .systemGroupedBackground
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        sourceController = AppDelegate.shared.dataSourceController

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

        // Watch config for changes.
        config.objectWillChange.debounce(for: 0.1, scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.fetch()
            }
            .store(in: &cancellables)
    }

    @objc func settingsTapped(sender: Any) {
        let dataSourceController = AppDelegate.shared.dataSourceController
        let viewController = UIHostingController(rootView: SettingsView(config: config,
                                                                        dataSourceController: dataSourceController))
        present(viewController, animated: true, completion: nil)
    }

    @objc func refreshTapped(sender: Any) {
        config.clearUploadHashes()  // Wipe all stored hashes to force re-upload on completion.
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

    func fetch() {
        dispatchPrecondition(condition: .onQueue(.main))

        // Use the first device for the previews.
        guard let device = config.devices.first else {
            imageView.isHidden = true
            return
        }

        imageView.isHidden = false

        let settings = (try? config.settings(forDevice: device.id)) ?? DeviceSettings(deviceId: UUID().uuidString)
        let blankImage = device.blankImage()
        self.image = blankImage
        self.redactedImage = blankImage
        UIView.transition(with: self.imageView,
                          duration: 0.3,
                          options: .transitionCrossDissolve) {
            self.imageView.image = blankImage
        }
        self.refreshButtonItem.isEnabled = false
        activityIndicator.startAnimating()

        // Generate a preview update.
        sourceController.fetch(details: settings.dataSources) { items, error in
            dispatchPrecondition(condition: .onQueue(.main))

            self.refreshButtonItem.isEnabled = true

            guard let items = items else {
                if let error {
                    self.present(error: error)
                }
                return
            }
            let images = device.renderer.render(data: items, config: AppDelegate.shared.config,
                                                device: device,
                                                settings: settings)
            self.image = images[0]
            self.redactedImage = images[1]
            self.activityIndicator.stopAnimating()
            UIView.transition(with: self.imageView,
                              duration: 0.3,
                              options: .transitionCrossDissolve) {
                self.imageView.image = images[0]
            }
        }

        // Trigger an update; long-term this should be automatic when the configuration changes.
        AppDelegate.shared.updateDevices()
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
