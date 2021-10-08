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

class NationalRailSettingsController : UITableViewController {

    var store: DataSourceSettingsStore<NationalRailDataSource.Settings>!
    var settings: NationalRailDataSource.Settings!

    @IBOutlet weak var fromStationCell: UITableViewCell!
    @IBOutlet weak var toStationCell: UITableViewCell!
    var stationPickerShowing: StationPickerController?
    var pickingDest = false

    func update() {
        var from = "Select a starting station"
        var to = "Select a destination"
        if let fromStation = StationsList.lookup(code: settings.from) {
            from = fromStation.nameAndCode
        }
        if let toStation = StationsList.lookup(code: settings.to) {
            to = toStation.nameAndCode
        }
        fromStationCell.textLabel?.text = from
        toStationCell.textLabel?.text = to
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let stationPicker = stationPickerShowing {
            stationPickerShowing = nil
            guard let station = stationPicker.selectedStation else {
                // User might not have made a selection
                return
            }
            if pickingDest {
                settings.to = station.code
            } else {
                settings.from = station.code
            }
            do {
                try store.save(settings: settings)
            } catch {
                self.present(error: error, completion: nil)
            }
        }
        update()
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // If we're about to show the station picker, track it and which field
        // it was triggered for
        stationPickerShowing = segue.destination as? StationPickerController
        pickingDest = (sender as? UITableViewCell) == toStationCell
    }

}
