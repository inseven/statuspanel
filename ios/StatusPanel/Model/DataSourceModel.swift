// Copyright (c) 2018-2024 Jason Morley, Tom Sutcliffe
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

import Combine
import Foundation
import UIKit
import SwiftUI

class DataSourceModel<T: DataSourceSettings>: ObservableObject {

    let store: DataSourceSettingsStore<T>

    @Published var settings: T
    @Published var error: Error? = nil

    var cancellables: Set<AnyCancellable> = []

    init(store: DataSourceSettingsStore<T>, settings: T) {
        self.store = store
        self.settings = settings
    }

    func start() {
        $settings
            .receive(on: DispatchQueue.main)
            .sink { [weak self] dataSourceSettings in
                guard let self else { return }
                do {
                    try self.store.save(settings: self.settings)
                } catch {
                    print("Failed to save data source settings with error \(error).")
                    self.error = error
                }
            }
            .store(in: &cancellables)
    }

}
