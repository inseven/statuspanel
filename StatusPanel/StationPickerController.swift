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
    var filteredStations: [Station]!
    var selectedStation: Station?

    override func viewDidLoad() {
        stations = StationsList.get()
        filteredStations = stations
        searchController = UISearchController(searchResultsController: nil)
        searchController.searchResultsUpdater = self
        searchController.searchBar.autocapitalizationType = .none
        searchController.searchBar.placeholder = "Select a station"
        searchController.dimsBackgroundDuringPresentation = false // The default is true.

        if #available(iOS 11.0, *) {
            // For iOS 11 and later, place the search bar in the navigation bar.
            navigationItem.searchController = searchController

            // Make the search bar always visible.
            navigationItem.hidesSearchBarWhenScrolling = false
        } else {
            // For iOS 10 and earlier, place the search controller's search bar in the table view's header.
            tableView.tableHeaderView = searchController.searchBar
        }

        searchController.dimsBackgroundDuringPresentation = false // The default is true.
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
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredStations.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
        cell.textLabel?.text = filteredStations[indexPath.row].nameAndCode
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedStation = filteredStations[indexPath.row]
        navigationController?.popViewController(animated: true)
    }
    func updateSearchResults(for searchController: UISearchController) {
        let searchString = searchController.searchBar.text!.trimmingCharacters(in: CharacterSet.whitespaces)
        if searchString == "" {
            filteredStations = stations
            self.tableView.reloadData()
            return
        }

        let codePred = NSComparisonPredicate(
            leftExpression: NSExpression(forKeyPath: "code"),
            rightExpression: NSExpression(forConstantValue: searchString),
            modifier: .direct,
            type: .equalTo,
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
        filteredStations.append(contentsOf: codeMatches)
        for m in nameMatches {
            if !codeMatches.contains(m) {
                filteredStations.append(m)
            }
        }

        self.tableView.reloadData()
    }
}
