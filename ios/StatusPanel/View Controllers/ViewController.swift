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
import EventKit

import Sodium

extension DataItemFlags {

    var labelStyle: ViewController.LabelStyle {
        if contains(.header) {
            return .header
        }
        return .text
    }

}

class ViewController: UIViewController, SettingsViewControllerDelegate {

    enum DividerStyle {
        case vertical(originY: CGFloat)
        case horizontal(originY: CGFloat)
    }

    enum LabelStyle {
        case text
        case header
        case subText
    }

    private var image: UIImage?
    private var redactedImage: UIImage?

    let SettingsButtonTag = 1

    var sourceController: DataSourceController!

    var client: Client {
        return AppDelegate.shared.client
    }

    private lazy var settingsButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(title: "Settings",
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

    private var showRedacted: Bool = false {
        didSet {
            switch showRedacted {
            case true:
                imageView.image = redactedImage
            case false:
                imageView.image = image
            }
        }
    }

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

    static func getLabel(frame: CGRect, font fontName: String, style: LabelStyle, redactMode: RedactMode = .none) -> UILabel {
        let font = Config().getFont(named: fontName)
        let size = (style == .header) ? font.headerSize : (style == .subText) ? font.subTextSize : font.textSize
        if let bitmapInfo = font.bitmapInfo {
            return BitmapFontLabel(frame: frame, bitmapFont: bitmapInfo, scale: size, redactMode: redactMode)
        } else if let uifont = UIFont(name: font.uifontName!, size: CGFloat(size)) {
            return BitmapFontLabel(frame: frame, uiFont: uifont, redactMode: redactMode)
        }

        // Otherwise, a plain old label (this code path now only used if we fail to find a font)
        let label = UILabel(frame: frame)
        label.lineBreakMode = .byWordWrapping
        print("No UIFont found for \(font.uifontName!)!")
        for family in UIFont.familyNames {
            for fontName in UIFont.fontNames(forFamilyName: family) {
                print("Candidate: \(fontName)")
            }
        }
        return label
    }

    func renderAndUpload(data: [DataItemBase], completion: @escaping (Bool) -> Void) {
        let darkMode = shouldBeDark()
        let image = Self.renderToImage(data: data, shouldRedact: false, darkMode: darkMode)

        let privacyImage = ((Config().privacyMode == .customImage)
                            ? ViewController.loadPrivacyImage()
                            : Self.renderToImage(data: data, shouldRedact: true, darkMode: darkMode))

        let client = self.client
        DispatchQueue.global().async {
            let payloads = Panel.rlePayloads(for: [image, privacyImage])
            DispatchQueue.main.sync {
                self.fetchDidUpdate(image: payloads[0].1, privacyImage: payloads[1].1)
            }
            client.upload(image: payloads[0].0, privacyImage: payloads[1].0) { anythingChanged in
                print("Changes: \(anythingChanged)")
                completion(anythingChanged)
            }
        }

    }

    static func loadPrivacyImage() -> UIImage {
        return (try? Config().privacyImage()) ?? Panel.blankImage()
    }

    static func renderToImage(data: [DataItemBase], shouldRedact: Bool, darkMode: Bool) -> UIImage {
        let contentView = UIView(frame: CGRect(origin: .zero, size: Panel.size))
        contentView.contentScaleFactor = 1.0

        // Construct the contentView's contents. For now just make labels and flow them into 2 columns
        contentView.backgroundColor = darkMode ? UIColor.black : UIColor.white
        let foregroundColor = darkMode ? UIColor.white : UIColor.black
        let config = Config()
        let twoCols = config.displayTwoColumns
        let showIcons = config.showIcons
        let rect = contentView.frame
        let maxy = rect.height - 10 // Leave space for status line
        let midx = rect.width / 2
        var x : CGFloat = 5
        var y : CGFloat = 0
        let colWidth = twoCols ? (rect.width / 2 - x * 2) : rect.width - x
        let bodyFont = config.getFont(named: config.bodyFont)
        let itemGap = CGFloat(min(10, bodyFont.textHeight / 2)) // ie 50% of the body text line height up to a max of 10px
        var colStart = y
        var col = 0
        var columnItemCount = 0 // Number of items assigned to the current column
        var divider: DividerStyle? = twoCols ? .vertical(originY: 0) : nil
        let redactMode: RedactMode = (shouldRedact ? (config.privacyMode == .redactWords ? .redactWords : .redactLines) : .none)

        for item in data {
            
            let flags = item.flags
            let font = flags.contains(.header) ? config.titleFont : config.bodyFont
            let fontDetails = Config().getFont(named: font)
            let w = flags.contains(.spansColumns) ? rect.width : colWidth
            let frame = CGRect(x: x, y: y, width: w, height: 0)
            let view = UIView(frame: frame)
            var prefix = fontDetails.supportsEmoji && showIcons ? item.iconAndPrefix : item.prefix
            let numPrefixLines = prefix.split(separator: "\n").count
            var textFrame = CGRect(origin: CGPoint.zero, size: frame.size)
            var itemHeight: CGFloat = 0

            if !prefix.isEmpty {
                let prefixLabel = ViewController.getLabel(frame: textFrame,
                                                          font: font,
                                                          style: flags.labelStyle,
                                                          redactMode: redactMode)
                prefixLabel.textColor = foregroundColor
                prefixLabel.numberOfLines = numPrefixLines
                prefixLabel.text = prefix + " "
                prefixLabel.sizeToFit()
                let prefixWidth = prefixLabel.frame.width
                if prefixWidth < frame.width / 2 {
                    prefix = ""
                    view.addSubview(prefixLabel)
                    textFrame = textFrame.divided(atDistance: prefixWidth, from: .minXEdge).remainder
                    itemHeight = prefixLabel.frame.height
                } else {
                    // Label too long, treat as single text entity (leave 'prefix' set)
                    prefix = prefix + " "
                }
            }
            let label = ViewController.getLabel(frame: textFrame,
                                                font: font,
                                                style: flags.labelStyle,
                                                redactMode: redactMode)
            label.numberOfLines = 1 // Temporarily while we're using it in checkFit

            let text = prefix + item.getText(checkFit: { (string: String) -> Bool in
                label.text = prefix + string
                let size = label.sizeThatFits(textFrame.size)
                return size.width <= textFrame.width
            })
            label.textColor = foregroundColor
            if flags.contains(.warning) {
                // Icons don't render well on the panel, use a coloured background instead
                label.backgroundColor = UIColor.yellow
                label.textColor = UIColor.black
            }
            label.numberOfLines = config.maxLines
            label.lineBreakMode = .byTruncatingTail
            label.text = text
            label.sizeToFit()
            itemHeight = max(itemHeight, label.bounds.height)
            label.frame = CGRect(x: label.frame.minX, y: label.frame.minY, width: textFrame.width, height: label.frame.height)
            view.frame = CGRect(origin: view.frame.origin, size: CGSize(width: view.frame.width, height: itemHeight))
            view.addSubview(label)
            if let subText = item.subText {
                let subLabel = ViewController.getLabel(frame: textFrame,
                                                       font: font,
                                                       style: .subText,
                                                       redactMode: redactMode)
                subLabel.textColor = foregroundColor
                subLabel.numberOfLines = config.maxLines
                subLabel.text = subText
                subLabel.sizeToFit()
                subLabel.frame = CGRect(x: textFrame.minX, y: view.bounds.maxY + 1, width: textFrame.width, height: subLabel.frame.height)
                view.frame = CGRect(origin: view.frame.origin, size: CGSize(width: view.frame.width, height: subLabel.frame.maxY))
                view.addSubview(subLabel)
            }
            let sz = view.frame
            // Enough space for this item?
            let itemIsColBreak = (columnItemCount > 0 && flags.contains(.prefersEmptyColumn))
            if (col == 0 && twoCols && (sz.height > maxy - y || itemIsColBreak)) {
                // overflow to 2nd column
                col += 1
                columnItemCount = 0
                x += midx + 5
                y = colStart
                view.frame = CGRect(x: x, y: y, width: sz.width, height: sz.height)
            } else if (!twoCols && itemIsColBreak) {
                // Leave some extra space and mark where to draw a line
                divider = .horizontal(originY: y)
                let c = view.center
                view.center = CGPoint(x: c.x, y: c.y + itemGap)
                y += itemGap
            }
            contentView.addSubview(view)

            y = y + sz.height + itemGap

            if flags.contains(.spansColumns) {
                // Update the verticial origin of the divider and columns, and start at column 0 again.
                divider = .vertical(originY: y)
                colStart = y
                columnItemCount = 0
                col = 0
            } else {
                // Track the number of items in the current column.
                columnItemCount += 1
            }

        }

        // And render it into an image
        let result = UIImage.New(rect.size, flipped: false) { context in
            // layer.render() works when the device is locked, whereas drawHierarchy() doesn't
            contentView.layer.render(in: context)

            // Draw the dividing line.
            if let divider = divider {

                context.setStrokeColor(foregroundColor.cgColor)
                context.beginPath()

                switch divider {
                case .vertical(let originY):
                    context.move(to: CGPoint(x: midx, y: originY))
                    context.addLine(to: CGPoint(x: midx, y: rect.height - Panel.statusBarHeight))
                case .horizontal(let originY):
                    context.move(to: CGPoint(x: x, y: originY))
                    context.addLine(to: CGPoint(x: rect.width - x, y: originY))
                }

                context.drawPath(using: .stroke)
            }
        }
        return result
    }

    private func shouldBeDark() -> Bool {
        switch Config().darkMode {
        case .off:
            return false
        case .on:
            return true
        case .system:
            return traitCollection.userInterfaceStyle == UIUserInterfaceStyle.dark
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
