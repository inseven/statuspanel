//
//  UpdateTimeController.swift
//  StatusPanel
//
//  Created by Tom Sutcliffe on 16/03/2019.
//  Copyright © 2019 Tom Sutcliffe. All rights reserved.
//

import UIKit

class UpdateTimeController: UIViewController {

    @IBOutlet weak var datePicker: UIDatePicker!

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        datePicker.timeZone = TimeZone(secondsFromGMT: 0)
        datePicker.date = Date.init(timeIntervalSinceReferenceDate: Config().updateTime)
    }

    @IBAction func timeChanged(sender: UIDatePicker, forEvent event: UIEvent) {
        let newTime = sender.date.timeIntervalSinceReferenceDate
        Config().updateTime = newTime
    }

}
