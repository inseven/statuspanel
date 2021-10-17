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

class TFLSettingsController: UITableViewController {

    private static var cellReuseIdentifier = "Cell"

    private var store: DataSourceSettingsStore<TFLDataSource.Settings>!
    private var settings: TFLDataSource.Settings!

    private var sortedLines: [String]!
    private var activeLines = Set<String>()

    init(store: DataSourceSettingsStore<TFLDataSource.Settings>, settings: TFLDataSource.Settings) {
        self.store = store
        self.settings = settings
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.cellReuseIdentifier)
        sortedLines = TFLDataSource.lines.keys.sorted()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        activeLines = Set(settings.lines)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sortedLines.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellReuseIdentifier, for: indexPath)
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
        settings.lines = activeLines.sorted()
        do {
            try store.save(settings: settings)
        } catch {
            self.present(error: error)
        }
    }
}
