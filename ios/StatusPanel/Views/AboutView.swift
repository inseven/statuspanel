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

extension String: Identifiable {
    public var id: String { self }
}

struct AboutView: View {

    @Environment(\.presentationMode) var presentationMode

    private static let dateFormatter: DateFormatter = {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        return dateFormatter
    }()

    private var date: String? {
        guard let date = UIApplication.shared.utcBuildDate else {
            return nil
        }
        return Self.dateFormatter.string(from: date)
    }

    private var contributors = [
        "Jason Morley",
        "Tom Sutcliffe",
    ]

    private var people = [
        "Lukas Fittl",
        "Pavlos Vinieratos",
    ]

    private var fonts: [Fonts.Font] {
        Config().availableFonts.sorted { $0.humanReadableName < $1.humanReadableName }
    }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    ValueRow(text: "Version", detailText: UIApplication.shared.version ?? "")
                    ValueRow(text: "Build", detailText: UIApplication.shared.build ?? "")
                    ValueRow(text: "Date", detailText: date ?? "")
                    Button {
                        guard let url = UIApplication.shared.commitUrl else {
                            return
                        }
                        UIApplication.shared.open(url, options: [:])
                    } label: {
                        ValueRow(text: "Commit", detailText: UIApplication.shared.commit ?? "")
                    }
                }
                Section(header: Text("Contributors")) {
                    ForEach(contributors) { person in
                        Text(person)
                    }
                }
                Section(header: Text("Thanks")) {
                    ForEach(people) { person in
                        Text(person)
                    }
                }
                Section(header: Text("Fonts")) {
                    ForEach(fonts) { font in
                        LicenseRow(name: font.humanReadableName, author: font.author, license: font.attribution)
                    }
                }
                Section(header: Text("Licenses")) {
                    LicenseRow(name: "Binding+mappedToBool",
                               author: "Joseph Duffy",
                               license: String(contentsOfBundleFile: "Binding+mappedToBool") ?? "missing file")
                    LicenseRow(name: "Swift-Sodium",
                               author: "Frank Denis",
                               license: String(contentsOfBundleFile: "Swift-Sodium") ?? "missing file")
                }
            }
            .navigationBarTitle("About", displayMode: .inline)
            .navigationBarItems(leading: Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("Done")
                    .fontWeight(.regular)
            })
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

}
