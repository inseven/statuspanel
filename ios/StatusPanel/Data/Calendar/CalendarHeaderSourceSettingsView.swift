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

import SwiftUI

class ErrorHandler {

    var viewController: UIViewController?

    init(viewController: UIViewController? = nil) {
        self.viewController = viewController
    }

    func present(error: Error) {
        viewController?.present(error: error, completion: nil)
    }

}

struct ErrorHandlerEnvironmentKey: EnvironmentKey {
    static var defaultValue = ErrorHandler()
}

extension EnvironmentValues {
    var errorHandler: ErrorHandler {
        get { self[ErrorHandlerEnvironmentKey.self] }
        set { self[ErrorHandlerEnvironmentKey.self] = newValue }
    }
}

struct CalendarHeaderSourceSettingsView: View {

    @Environment(\.errorHandler) var errorHandler

    var store: DataSourceSettingsStore<CalendarHeaderSource.Settings>
    @State var settings: CalendarHeaderSource.Settings

    init(store: DataSourceSettingsStore<CalendarHeaderSource.Settings>, settings: CalendarHeaderSource.Settings) {
        self.store = store
        _settings = State(initialValue: settings)
    }

    var body: some View {
        Form {
            Section {
                Picker("Date", selection: $settings.offset) {
                    Text("Today").tag(0)
                    Text("Tomorrow").tag(1)
                }
                NavigationLink(destination: FormatEditor(settings: $settings)) {
                    HStack {
                        Text("Format")
                        Spacer()
                        Text(settings.longFormat)
                            .foregroundColor(.secondary)
                    }
                }
            }
            FlagsSection(flags: $settings.flags)
        }
        .onChange(of: settings) { newSettings in
            do {
                try store.save(settings: newSettings)
            } catch {
                errorHandler.present(error: error)
            }
        }
    }

}
