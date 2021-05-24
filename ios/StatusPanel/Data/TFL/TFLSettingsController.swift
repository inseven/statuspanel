//
//  TFLSettingsController.swift
//  StatusPanel
//
//  Created by Tom Sutcliffe on 16/03/2019.
//  Copyright © 2019 Tom Sutcliffe. All rights reserved.
//

import UIKit

class TFLSettingsController: UITableViewController {

    var sortedLines: [String]!
    var activeLines = Set<String>()

    override func viewDidLoad() {
        super.viewDidLoad()
        sortedLines = TFLDataSource.lines.keys.sorted()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        activeLines = Set(Config().activeTFLLines)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sortedLines.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let line = sortedLines[indexPath.row]
        cell.textLabel?.text = TFLDataSource.lines[line]
        cell.accessoryType = activeLines.contains(line) ? .checkmark : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let line = sortedLines[indexPath.row]
        if activeLines.contains(line) {
            activeLines.remove(line)
        } else {
            activeLines.insert(line)
        }
        tableView.deselectRow(at: indexPath, animated: true)
        tableView.reloadRows(at: [indexPath], with: .fade)
        Config().activeTFLLines = activeLines.sorted()
    }
}
