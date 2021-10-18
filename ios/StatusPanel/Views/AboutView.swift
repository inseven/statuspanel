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
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    var build: String? {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String
    }

    var date: String? {
        guard let build = self.build,
              build.count == 18
        else {
            return nil
        }
        let dateString = String(build.prefix(10))
        let inputDateFormatter = DateFormatter()
        inputDateFormatter.dateFormat = "yyMMddHHmm"
        guard let date = inputDateFormatter.date(from: dateString) else {
            return nil
        }
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .short
        return dateFormatter.string(from: date)
    }

    var sha: String? {
        guard let build = self.build,
              build.count == 18
        else {
            return nil
        }
        guard let shaValue = Int(String(build.suffix(8))) else {
            return nil
        }
        return String(format: "%02x", shaValue)
    }

    var commitUrl: URL? {
        guard let sha = self.sha else {
            return nil
        }
        return URL(string: "https://github.com/inseven/statuspanel/commit")?.appendingPathComponent(sha)
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
                Section {
                    ValueRow(text: "Version", detailText: version ?? "")
                    ValueRow(text: "Build", detailText: build ?? "")
                    ValueRow(text: "Date", detailText: date ?? "")
                    Button {
                        guard let url = commitUrl else {
                            return
                        }
                        UIApplication.shared.open(url, options: [:])
                    } label: {
                        ValueRow(text: "Commit", detailText: sha ?? "")
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
