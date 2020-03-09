//
//  StationPickerController.swift
//  StatusPanel
//
//  Created by Tom Sutcliffe on 30/03/2019.
//  Copyright © 2019 Tom Sutcliffe. All rights reserved.
//

import UIKit

class StationPickerController: UITableViewController, UISearchResultsUpdating {

    var searchController: UISearchController!

    var stations: [Station]!
    var stationsByLetter: [[Station]] = []
    var filteredStations: [Station]?
    var selectedStation: Station?

    override func viewDidLoad() {
        stations = StationsList.get()
        for _ in 0...25 {
            stationsByLetter.append([])
        }
        for station in stations {
            let firstChar:Character = station.name[station.name.startIndex]
            let index = Int(firstChar.asciiValue! - Character("A").asciiValue!)
            stationsByLetter[index].append(station)
        }

        searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.searchBar.autocapitalizationType = .none
        searchController.searchBar.placeholder = "Select a station"
        searchController.obscuresBackgroundDuringPresentation = false // The default is true.

        if #available(iOS 11.0, *) {
            // For iOS 11 and later, place the search bar in the navigation bar.
            navigationItem.searchController = searchController

            // Make the search bar always visible.
            navigationItem.hidesSearchBarWhenScrolling = false
        } else {
            // For iOS 10 and earlier, place the search controller's search bar in the table view's header.
            tableView.tableHeaderView = searchController.searchBar
        }

        searchController.obscuresBackgroundDuringPresentation = false // The default is true.
        definesPresentationContext = true
        searchController.isActive = true

        super.viewDidLoad()
    }

    override func viewDidAppear(_ animated: Bool) {
        // Make sure the seach box always starts out with the keyboard up
        // TODO: Why doesn't this work?
        // searchController.searchBar.becomeFirstResponder()

        super.viewDidAppear(animated)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        if filteredStations != nil {
            return 1
        } else {
            return stationsByLetter.count
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let stats = filteredStations {
            return stats.count
        } else {
            return stationsByLetter[section].count
        }
    }

    func stationForIndexPath(_ indexPath: IndexPath) -> Station {
        if let filtered = filteredStations {
            return filtered[indexPath.row]
        } else {
            let section = stationsByLetter[indexPath.section]
            return section[indexPath.row]
        }
    }

    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        if filteredStations == nil {
            var result:[String] = []
            for i in Character("A").asciiValue! ... Character("Z").asciiValue! {
                result.append(String(UnicodeScalar(i)))
            }
            return result
        } else {
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        if filteredStations == nil {
            return 24 // Looks about right (!)
        } else {
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        if filteredStations == nil {
            let name = String(UnicodeScalar(Int(Character("A").asciiValue!) + section)!)
            let label = UILabel()
            label.text = name
            label.font = UIFont.boldSystemFont(ofSize: UIFont.labelFontSize)
            label.backgroundColor = UIColor.systemGroupedBackground
            return label
        } else {
            // No section headers in filtered list
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        let station = stationForIndexPath(indexPath)
        cell.textLabel?.text = station.nameAndCode
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedStation = stationForIndexPath(indexPath)
        navigationController?.popViewController(animated: true)
    }
    func updateSearchResults(for searchController: UISearchController) {
        let searchString = searchController.searchBar.text!.trimmingCharacters(in: CharacterSet.whitespaces)
        if searchString == "" {
            filteredStations = nil
            self.tableView.reloadData()
            return
        }

        let codePred = NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: "code"),
            rightExpression: NSExpression(forConstantValue: searchString),
            modifier: .direct,
            type: .contains,
            options: [.caseInsensitive]
        )
        let codeMatches = stations.filter({codePred.evaluate(with: $0)})

        let namePred = NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: "name"),
            rightExpression: NSExpression(forConstantValue: searchString),
            modifier: .direct,
            type: .contains,
            options: [.caseInsensitive]
        )
        let nameMatches = stations.filter({namePred.evaluate(with: $0)})

        // A matching code is given priority
        filteredStations = []
        filteredStations?.append(contentsOf: codeMatches)
        for m in nameMatches {
            if !codeMatches.contains(m) {
                filteredStations?.append(m)
            }
        }

        self.tableView.reloadData()
    }
}
