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

class StationPickerController: UITableViewController, UISearchResultsUpdating {

    static let valueCellReuseIdentifier = "ValueCell"

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
        searchController.obscuresBackgroundDuringPresentation = false
        navigationItem.hidesSearchBarWhenScrolling = false

        navigationItem.searchController = searchController

        definesPresentationContext = true
        searchController.isActive = true

        tableView.register(ValueCell.self, forCellReuseIdentifier: Self.valueCellReuseIdentifier)

        super.viewDidLoad()
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

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if filteredStations == nil {
            let name = String(UnicodeScalar(Int(Character("A").asciiValue!) + section)!)
            return name
        } else {
            // No section headers in filtered list
            return nil
        }

    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.valueCellReuseIdentifier, for: indexPath)
        let station = stationForIndexPath(indexPath)
        cell.textLabel?.text = station.name
        cell.detailTextLabel?.text = station.code
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
