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

import SwiftUI

struct AddDataSourceView: View {

    @Environment(\.dismiss) var dismiss

    let config: Config
    let dataSourceController: DataSourceController
    
    @Binding var dataSources: [DataSourceInstance.Details]

    @State var error: Error?

    var body: some View {
        NavigationView {
            Form {
                ForEach(DataSourceController.sources) { dataSource in
                    let uuid = UUID()
                    NavigationLink {
                        try! dataSource.views(config: config, instanceId: uuid).settingsView
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("Add") {
                                        do {
                                            let details = DataSourceInstance.Details(id: uuid, type: dataSource.id)
                                            let dataSource = try dataSourceController.dataSourceInstance(for: details)
                                            dataSources.append(dataSource.details)
                                            dismiss()
                                        } catch {
                                            self.error = error
                                        }
                                    }
                                }
                            }
                    } label: {
                        HStack(spacing: 0) {
                            dataSource.image
                                .renderingMode(.template)
                                .foregroundColor(.primary)
                                .padding(.trailing)
                            Text(dataSource.name)
                                .foregroundColor(.primary)
                        }
                    }
                }
            }
            .navigationBarTitle("Add Data Source", displayMode: .inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .presents($error)
        }
    }

}
