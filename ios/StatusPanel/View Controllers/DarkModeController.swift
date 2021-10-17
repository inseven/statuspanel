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

class DarkModeController : UITableViewController {

    private static let cellReuseIdentifier = "Cell"

    private var config: Config

    init(config: Config) {
        self.config = config
        super.init(style: .grouped)
        tableView.allowsSelection = true
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: Self.cellReuseIdentifier)
        title = LocalizedString("dark_mode_title")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 3
    }

    func configValue(forRowAt indexPath: IndexPath) -> Config.DarkModeConfig {
        switch indexPath.row {
        case 0:
            return Config.DarkModeConfig.off
        case 1:
            return Config.DarkModeConfig.on
        case 2:
            return Config.DarkModeConfig.system
        default:
            break
        }
        assert(false)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: Self.cellReuseIdentifier, for: indexPath)
        let configValue = configValue(forRowAt: indexPath)
        cell.textLabel?.text = Localize(configValue)
        cell.accessoryType = config.darkMode == configValue ? .checkmark : .none
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        Config().darkMode = Config.DarkModeConfig(rawValue: indexPath.row)!
        tableView.performBatchUpdates({
            tableView.deselectRow(at: indexPath, animated: true)
            tableView.reloadData()
        }) { finished in
            self.navigationController?.popViewController(animated: true)
        }
    }
}
