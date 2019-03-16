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
        // Calendars
        let calendarIds = Config().activeCalendars
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
            self.calendarsCell.detailTextLabel?.text = calendarNames.joined(separator: ", ")
        } else {
            self.calendarsCell.detailTextLabel?.text = "None"
        }

        // TFL
        let lines = Config().activeTFLLines
        var lineNames: [String] = []
        for lineId in lines {
            lineNames.append(TFLDataSource.lines[lineId]!)
        }
        if lineNames.count > 0 {
            self.tflCell.detailTextLabel?.text = lineNames.joined(separator: ", ")
        } else {
            self.tflCell.detailTextLabel?.text = "None"
        }

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
