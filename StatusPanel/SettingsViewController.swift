//
//  SettingsViewController.swift
//  StatusPanel
//
//  Created by Jason Barrie Morley on 13/01/2019.
//  Copyright © 2019 Tom Sutcliffe. All rights reserved.
//

import EventKit
import UIKit

class SettingsViewController: UITableViewController {

    @IBOutlet weak var calendarsCell: UITableViewCell!
    @IBOutlet weak var deviceIdCell: UITableViewCell!
    @IBOutlet weak var tflCell: UITableViewCell!
    @IBOutlet weak var nationalRailCell: UITableViewCell!
    @IBOutlet weak var updateTimeCell: UITableViewCell!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func cancelTapped(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        update()
    }

    func update() {
        let config = Config()

        // Calendars
        let calendarIds = config.activeCalendars
        let eventStore = EKEventStore()
        var calendarNames: [String] = []
        for calendarId in calendarIds {
            guard let cal = eventStore.calendar(withIdentifier: calendarId) else {
                // Calendar has been deleted?
                continue
            }
            calendarNames.append(cal.title)
        }
        if calendarNames.count > 0 {
            calendarsCell.detailTextLabel?.text = calendarNames.joined(separator: ", ")
        } else {
            calendarsCell.detailTextLabel?.text = "None"
        }

        // TFL
        let lines = config.activeTFLLines
        var lineNames: [String] = []
        for lineId in lines {
            lineNames.append(TFLDataSource.lines[lineId]!)
        }
        if lineNames.count > 0 {
            tflCell.detailTextLabel?.text = lineNames.joined(separator: ", ")
        } else {
            tflCell.detailTextLabel?.text = "None"
        }

        // National rail
        let route = config.trainRoute
        if let from = route.from, let to = route.to {
            nationalRailCell.detailTextLabel?.text = "\(from) to \(to)"
        } else {
            nationalRailCell.detailTextLabel?.text = "Not configured"
        }

        // Update time
        let updateTime = Date(timeIntervalSinceReferenceDate: config.updateTime)
        let df = DateFormatter()
        df.timeStyle = .short
        let timeStr = df.string(from: updateTime)
        self.updateTimeCell.textLabel?.text = timeStr

        // Device ID
        if let (deviceId, _) = Config.getDeviceAndKey() {
            self.deviceIdCell.detailTextLabel?.text = deviceId
        } else {
            self.deviceIdCell.detailTextLabel?.text = "Not configured"
        }
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
