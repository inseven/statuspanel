//
//  NationalRailSettingsController.swift
//  StatusPanel
//
//  Created by Tom Sutcliffe on 30/03/2019.
//  Copyright © 2019 Tom Sutcliffe. All rights reserved.
//

import UIKit

class NationalRailSettingsController : UITableViewController {

    @IBOutlet weak var fromStationCell: UITableViewCell!
    @IBOutlet weak var toStationCell: UITableViewCell!
    @IBOutlet weak var enabledCell: UITableViewCell!
    var stationPickerShowing: StationPickerController?
    var pickingDest = false

    func update() {
        let route = Config().trainRoute
        var from = "Select a starting station"
        var to = "Select a destination"
        if let fromStation = StationsList.lookup(code: route.from) {
            from = fromStation.nameAndCode
        }
        if let toStation = StationsList.lookup(code: route.to) {
            to = toStation.nameAndCode
        }
        fromStationCell.textLabel?.text = from
        toStationCell.textLabel?.text = to
        let enabled = route.from != nil && route.to != nil
        if let enabledSwitch = enabledCell.accessoryView as? UISwitch {
            enabledSwitch.setOn(enabled, animated: false)
        }
    }

    override func viewDidLoad() {
        let enabledSwitch = UISwitch()
        enabledSwitch.addTarget(self, action: #selector(enabledSwitchDidChange), for: UIControl.Event.valueChanged)
        enabledCell.accessoryView = enabledSwitch
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let stationPicker = stationPickerShowing {
            stationPickerShowing = nil
            let config = Config()
            guard let station = stationPicker.selectedStation else {
                // User might not have made a selection
                return
            }
            var route = config.trainRoute
            if pickingDest {
                route.to = station.code
            } else {
                route.from = station.code
            }
            config.trainRoute = route
        }
        update()
    }

    @objc func enabledSwitchDidChange(sender: Any) {
        guard let enabledSwitch = sender as? UISwitch else {
            return
        }
        if !enabledSwitch.isOn {
            Config().trainRoute = Config.TrainRoute(from: nil, to: nil)
            update()
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // If we're about to show the station picker, track it and which field
        // it was triggered for
        stationPickerShowing = segue.destination as? StationPickerController
        pickingDest = (sender as? UITableViewCell) == toStationCell
    }

}
