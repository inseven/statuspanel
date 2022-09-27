// Copyright (c) 2018-2022 Jason Morley, Tom Sutcliffe
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

class PrivacyModeController : UITableViewController, UINavigationControllerDelegate {

    private static var imageCellReuseIdentifier = "ImageCell"
    private let kImageRowHeight: CGFloat = 200

    private let config: Config

    private var firstRun = true

    private var privacyImage: UIImage? = nil {
        didSet {
            dispatchPrecondition(condition: .onQueue(.main))
            guard self.config.privacyMode == .customImage else {
                return
            }
            self.tableView.reloadRows(at: [IndexPath(row: 3, section: 0)], with: .fade)
        }
    }

    init(config: Config) {
        self.config = config
        super.init(style: .grouped)
        title = LocalizedString("privacy_mode_title")
        tableView.register(ImageViewTableViewCell.self, forCellReuseIdentifier: Self.imageCellReuseIdentifier)
        tableView.allowsSelection = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        loadPrivacyImage()
    }

    func loadPrivacyImage() {
        if !firstRun {
            return
        }
        firstRun = false
        DispatchQueue.global(qos: .userInteractive).async {
            let image = try? self.config.privacyImage() ?? Panel.blankImage()
            DispatchQueue.main.async {
                self.privacyImage = image
            }
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        if indexPath.row == 3 {
            tableView.deselectRow(at: indexPath, animated: true)
            let picker = UIImagePickerController()
            picker.delegate = self
            picker.sourceType = .photoLibrary
            picker.modalPresentationStyle = .popover
            present(picker, animated: true)
        } else {
            let prevMode = config.privacyMode
            let prevIndexPath = IndexPath(row: prevMode.rawValue, section: 0)
            let newMode = Config.PrivacyMode(rawValue: indexPath.row)!
            if newMode == prevMode {
                tableView.deselectRow(at: indexPath, animated: true)
                return
            }
            config.privacyMode = Config.PrivacyMode(rawValue: indexPath.row)!
            tableView.performBatchUpdates {
                tableView.deselectRow(at: indexPath, animated: true)
                let imgCellIndexPath = IndexPath(row: 3, section: 0)
                tableView.reloadRows(at: [indexPath, prevIndexPath], with: .fade)
                if prevMode != .customImage && newMode == .customImage {
                    tableView.insertRows(at: [imgCellIndexPath], with: .automatic)
                } else if prevMode == .customImage && newMode != .customImage{
                    tableView.deleteRows(at: [imgCellIndexPath], with: .automatic)
                }
            }
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return config.privacyMode == .customImage ? 4 : 3
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.row == 3 {
            return kImageRowHeight
        } else {
            return tableView.rowHeight
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.row < 2 {
            let redactMode: RedactMode = (indexPath.row == 0) ? .redactLines : .redactWords
            let cell = FontLabelTableViewCell(font: config.getFont(named: config.bodyFont), redactMode: redactMode)
            cell.label.text = "Redact text good"
            cell.accessoryType = indexPath.row == config.privacyMode.rawValue ? .checkmark : .none
            return cell
        } else if (indexPath.row == 2) {
            let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
            cell.textLabel?.text = "Custom Image"
            cell.accessoryType = indexPath.row == config.privacyMode.rawValue ? .checkmark : .none
            return cell
        } else if (indexPath.row == 3) {
            let cell = tableView.dequeueReusableCell(withIdentifier: Self.imageCellReuseIdentifier,
                                                     for: indexPath) as! ImageViewTableViewCell
            cell.accessoryType = .disclosureIndicator
            cell.contentImageView.contentMode = .scaleAspectFit
            cell.contentImageView.image = privacyImage ?? Panel.blankImage()
            cell.activityIndicatorView.setAnimating(privacyImage == nil)
            return cell
        }
        fatalError("Unknown index path")
    }

}

extension PrivacyModeController: UIImagePickerControllerDelegate {

    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        dismiss(animated: true)
        guard let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage) else {
            print("Failed to get an updated image.")
            return
        }
        self.privacyImage = nil
        Panel.privacyImage(from: image) { result in
            switch result {
            case .success(let image):
                do {
                    try self.config.setPrivacyImage(image)
                    DispatchQueue.main.async {
                        self.privacyImage = image
                    }
                } catch {
                    DispatchQueue.main.async {
                        self.present(error: error)
                    }
                    return
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.present(error: error)
                }
            }
        }
    }

}
