//
//  MaxLinesController.swift
//  StatusPanel
//
//  Created by Tom Sutcliffe on 22/03/2020.
//  Copyright © 2020 Tom Sutcliffe. All rights reserved.
//

import UIKit

class MaxLinesController : UITableViewController {

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let val = Config().maxLines
        updateTickMark(val)
    }

    func numItems() -> Int {
        return self.tableView.numberOfRows(inSection: 0)
    }

    func updateTickMark(_ tag: Int) {
        for i in 0 ..< numItems() {
            let cell = self.tableView.cellForRow(at: IndexPath(row: i, section: 0))
            cell?.accessoryType = (cell?.tag == tag) ? .checkmark : .none
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let tag = tableView.cellForRow(at: indexPath)!.tag
        Config().maxLines = tag
        tableView.performBatchUpdates({
            tableView.deselectRow(at: indexPath, animated: true)
            updateTickMark(tag)
        })
    }
}
