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

import UIKit
import SwiftUI

class NationalRailSettingsController : UITableViewController {

    static let valueCellReuseIdentifier = "ValueCell"

    var model: NationalRailDataSource.Model
    var stationPickerShowing: StationPickerController?
    var pickingDest = false

    init(model: NationalRailDataSource.Model) {
        self.model = model
        super.init(style: .insetGrouped)
        tableView.register(Value1TableViewCell.self, forCellReuseIdentifier: Self.valueCellReuseIdentifier)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let stationPicker = stationPickerShowing {
            stationPickerShowing = nil
            guard let station = stationPicker.selectedStation else {
                // User might not have made a selection
                return
            }
            var indexPath: IndexPath? = nil
            if pickingDest {
                model.settings.to = station.code
                indexPath = IndexPath(row: 1, section: 0)
            } else {
                model.settings.from = station.code
                indexPath = IndexPath(row: 0, section: 0)
            }
            if let indexPath = indexPath {
                tableView.reloadRows(at: [indexPath], with: .fade)
            }
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.valueCellReuseIdentifier, for: indexPath)
        switch indexPath.row {
        case 0:
            cell.textLabel?.text = "From"
            cell.detailTextLabel?.text = StationsList.lookup(code: model.settings.from)?.nameAndCode
        case 1:
            cell.textLabel?.text = "To"
            cell.detailTextLabel?.text = StationsList.lookup(code: model.settings.to)?.nameAndCode
        default:
            break
        }
        cell.accessoryType = .disclosureIndicator
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let viewController = StationPickerController()
        stationPickerShowing = viewController
        switch indexPath.row {
        case 0:
            pickingDest = false
        case 1:
            pickingDest = true
        default:
            break
        }
        navigationController?.pushViewController(viewController, animated: true)
    }

}
