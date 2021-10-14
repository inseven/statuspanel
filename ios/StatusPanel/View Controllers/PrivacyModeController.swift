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

class PrivacyModeController : UITableViewController, UINavigationControllerDelegate, UIImagePickerControllerDelegate {

    private let config = Config()

    override func tableView(_ tableView: UITableView, shouldHighlightRowAt indexPath: IndexPath) -> Bool {
        return true
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
            tableView.performBatchUpdates({
                tableView.deselectRow(at: indexPath, animated: true)
                let imgCellIndexPath = IndexPath(row: 3, section: 0)
                tableView.reloadRows(at: [indexPath, prevIndexPath], with: .fade)
                if prevMode != .customImage && newMode == .customImage {
                    tableView.insertRows(at: [imgCellIndexPath], with: .automatic)
                } else if prevMode == .customImage && newMode != .customImage{
                    tableView.deleteRows(at: [imgCellIndexPath], with: .automatic)
                }
            })
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return config.privacyMode == .customImage ? 4 : 3
    }

    private let kImageRowHeight: CGFloat = 200

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.row == 3 {
            return kImageRowHeight
        } else {
            return tableView.rowHeight
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)

        if indexPath.row < 2 {
            let frame = cell.contentView.bounds.insetBy(dx: cell.separatorInset.left, dy: 0)
            let redactMode: RedactMode = (indexPath.row == 0) ? .redactLines : .redactWords
            let label = ViewController.getLabel(frame: frame, font: Config().bodyFont, style: .text, redactMode: redactMode)
            label.text = "Redact text good"
            label.sizeToFit()
            label.frame = label.frame.offsetBy(dx: 0, dy: (frame.height - label.bounds.height) / 2)
            cell.contentView.addSubview(label)
        } else if (indexPath.row == 2) {
            cell.textLabel?.text = "Custom Image"
        } else if (indexPath.row == 3) {
            cell.contentView.bounds = cell.contentView.bounds.rectWithDifferentHeight(kImageRowHeight)
            cell.accessoryType = .disclosureIndicator
            let frame = cell.contentView.bounds.insetBy(left: cell.separatorInset.left, right: 35, top: 10, bottom: 10)
            let img = ViewController.cropCustomRedactImageToPanelSize()
            let imgView = UIImageView(image: img)
            imgView.contentMode = .scaleAspectFit
            imgView.frame = frame
            cell.contentView.addSubview(imgView)
        }

        if indexPath.row == Config().privacyMode.rawValue {
            cell.accessoryType = .checkmark
        }
        return cell
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        var image = info[.editedImage] as? UIImage
        if image == nil {
            image = info[.originalImage] as? UIImage
        }
        if let image = image {
            savePrivacyImage(image)
            tableView.reloadRows(at: [IndexPath(row: 3, section: 0)], with: .none)
        }
        dismiss(animated: true)
    }

    func savePrivacyImage(_ image: UIImage) {
         do {
             let dir = try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
             let imgdata = image.pngData()
             try imgdata?.write(to: dir.appendingPathComponent("customPrivacyImage.png"))
         } catch {
             print("meh")
         }
    }
}
