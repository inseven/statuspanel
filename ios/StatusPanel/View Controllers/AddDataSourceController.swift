// Copyright (c) 2018-2023 Jason Morley, Tom Sutcliffe
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
import SwiftUI

protocol AddDataSourceControllerDelegate: AnyObject {

    func addDataSourceControllerDidComplete(_ addDataSourceController: AddDataSourceController)

}

class AddDataSourceController: UINavigationController {

    private let dataSourceController: DataSourceController

    weak var addSourceDelegate: AddDataSourceControllerDelegate?

    private var details: DataSourceInstance.Details? = nil

    private lazy var cancelButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .cancel,
                               target: self,
                               action: #selector(cancelTapped(sender:)))
    }()

    private lazy var doneButtonItem: UIBarButtonItem = {
        return UIBarButtonItem(title: "Add",
                               style: .done,
                               target: self,
                               action: #selector(doneTapped(sender:)))
    }()

    init(dataSourceController: DataSourceController) {
        self.dataSourceController = dataSourceController
        super.init(rootViewController: UITableViewController())

        let view = AddDataSourceView(sourceController: dataSourceController) { dataSource in
            dispatchPrecondition(condition: .onQueue(.main))
            guard let dataSource = dataSource else {
                self.dismiss(animated: true, completion: nil)
                return
            }
            self.didSelectDataSource(dataSource)
        }

        self.viewControllers = [UIHostingController(rootView: view)]
    }

    @objc func cancelTapped(sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }

    @objc func doneTapped(sender: Any) {
        guard let details = details else {
            present(error: StatusPanelError.internalInconsistency)
            return
        }
        if addDataSource(details: details) {
            addSourceDelegate?.addDataSourceControllerDidComplete(self)
            self.dismiss(animated: true, completion: nil)
        }
    }

    func addDataSource(details: DataSourceInstance.Details) -> Bool {
        do {
            try dataSourceController.add(details)
            try dataSourceController.save()
            return true
        } catch {
            present(error: error)
            return false
        }
    }

    func didSelectDataSource(_ dataSource: AnyDataSource) {
        do {
            let details = DataSourceInstance.Details(id: UUID(), type: dataSource.id)
            guard dataSource.configurable else {
                if addDataSource(details: details) {
                    addSourceDelegate?.addDataSourceControllerDidComplete(self)
                    self.dismiss(animated: true, completion: nil)
                }
                return
            }
            let settingsView = try dataSource.settingsView(for: details.id)
            let settingsViewController = UIHostingController(rootView: settingsView)
            settingsViewController.navigationItem.rightBarButtonItem = self.doneButtonItem
            self.pushViewController(settingsViewController, animated: true)
            self.details = details
        } catch {
            self.present(error: error)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
