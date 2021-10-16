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

    var version: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    var build: String? {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    }

    var contributors = [
        "Jason Morley",
        "Tom Sutcliffe",
    ]

    var people = [
        "Lukas Fittl",
        "Pavlos Vinieratos",
    ]

    var fonts: [Fonts.Font] {
        Config().availableFonts.sorted { $0.humanReadableName < $1.humanReadableName }
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("App")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(version ?? "")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Build")
                        Spacer()
                        Text(build ?? "")
                            .foregroundColor(.secondary)
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
                Section(header: Text("Font Licenses")) {
                    ForEach(fonts) { font in
                        LicenseRow(name: font.humanReadableName, author: font.author, license: font.attribution)
                    }
                }
                Section(header: Text("Code Licenses")) {
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
