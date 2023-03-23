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
        return UIBarButtonItem(barButtonSystemItem: .add,
                               target: self,
                               action: #selector(addTapped(sender:)))
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
        sourceController.delegate = self

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
        sourceController.fetch()
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

    func renderAndUpload(data: [DataItemBase], completion: @escaping (Bool) -> Void) {
        dispatchPrecondition(condition: .onQueue(.main))
        let config = Config()
        let images = Renderer.render(data: data, config: config)

        let client = AppDelegate.shared.client
        DispatchQueue.global().async {
            let payloads = Panel.rlePayloads(for: images)
            DispatchQueue.main.sync {
                self.fetchDidUpdate(image: payloads[0].1, privacyImage: payloads[1].1)
            }
            client.upload(image: payloads[0].0, privacyImage: payloads[1].0) { anythingChanged in
                print("Changes: \(anythingChanged)")
                completion(anythingChanged)
            }
        }

    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        BitmapFontCache.shared.emptyCache()
    }

}

extension ViewController: DataSourceControllerDelegate {

    func dataSourceController(_ dataSourceController: DataSourceController, didUpdateData data: [DataItemBase]) {
        self.renderAndUpload(data: data, completion: { (changes: Bool) -> Void in
            DispatchQueue.main.async {
                AppDelegate.shared.fetchCompleted(hasChanged: changes)
                self.fetchDidComplete()
            }
        })
    }

    func dataSourceController(_ dataSourceController: DataSourceController, didFailWithError error: Error) {
        present(error: error)
        fetchDidComplete()
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
