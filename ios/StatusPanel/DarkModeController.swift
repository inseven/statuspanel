//
//  DarkModeController.swift
//  StatusPanel
//
//  Created by Tom Sutcliffe on 09/03/2020.
//  Copyright © 2020 Tom Sutcliffe. All rights reserved.
//

import UIKit

class DarkModeController : UITableViewController {

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateTickMark(Config().darkMode.rawValue)
    }

    func updateTickMark(_ selected: Int) {
        for mode in Config.DarkModeConfig.allCases {
            let i = mode.rawValue
            let cell = self.tableView.cellForRow(at: IndexPath(row: i, section: 0))
            cell?.accessoryType = (i == selected) ? .checkmark : .none
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        Config().darkMode = Config.DarkModeConfig(rawValue: indexPath.row)!
        tableView.performBatchUpdates({
            tableView.deselectRow(at: indexPath, animated: true)
            updateTickMark(indexPath.row)
        })
    }
}
