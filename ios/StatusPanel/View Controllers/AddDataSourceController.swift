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
import SwiftUI

protocol AddDataSourceControllerDelegate: AnyObject {

    func addDataSourceController(_ addDataSourceController: AddDataSourceController,
                                 didCompleteWithDetails details: DataSourceInstance.Details)
    func addDataSourceControllerDidCancel(_ addDataSourceController: AddDataSourceController)

}

class AddDataSourceController: UINavigationController {

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
        super.init(rootViewController: UITableViewController())

        let view = AddDataSourceView(sourceController: dataSourceController) { dataSource in
            dispatchPrecondition(condition: .onQueue(.main))
            guard let dataSource = dataSource else {
                self.navigationController?.dismiss(animated: true, completion: nil)
                self.addSourceDelegate?.addDataSourceControllerDidCancel(self)
                return
            }
            self.didSelectDataSource(dataSource)
        }

        self.viewControllers = [UIHostingController(rootView: view)]
    }

    @objc func cancelTapped(sender: Any) {
        addSourceDelegate?.addDataSourceControllerDidCancel(self)
    }

    @objc func doneTapped(sender: Any) {
        guard let details = details else {
            present(error: StatusPanelError.internalInconsistency)
            return
        }
        addSourceDelegate?.addDataSourceController(self, didCompleteWithDetails: details)
    }

    func didSelectDataSource(_ dataSource: AnyDataSource) {
        do {
            let details = DataSourceInstance.Details(id: UUID(), type: dataSource.id)
            guard dataSource.configurable else {
                self.addSourceDelegate?.addDataSourceController(self, didCompleteWithDetails: details)
                return
            }
            guard let settingsViewController = try dataSource.settingsViewController(for: details.id) else {
                throw StatusPanelError.internalInconsistency
            }
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
