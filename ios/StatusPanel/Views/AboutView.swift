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

import Diligence

extension Fonts.Font {

    var license: License {
        return License(name: humanReadableName, author: author, text: attribution)
    }

}

struct AboutView: View {

    @Environment(\.presentationMode) var presentationMode

    private var fonts: [License] {
        return Config()
            .availableFonts
            .sorted { $0.humanReadableName < $1.humanReadableName }
            .map { $0.license }
    }

    var body: some View {
        NavigationView {
            Form {
                HeaderSection {
                    IconView(uiImage: UIImage(named: "Icon")!)
                }
                BuildSection("inseven/statuspanel")
                Section {
                    Link("InSeven Limited", url: URL(string: "https://inseven.co.uk")!)
                    Link("GitHub", url: URL(string: "https://github.com/inseven/statuspanel")!)
                }
                CreditSection("Contributors", [
                    Credit("Jason Morley", url: URL(string: "https://jbmorley.co.uk")),
                    Credit("Tom Sutcliffe", url: URL(string: "https://github.com/tomsci")),
                ])
                CreditSection("Thanks", [
                    "Lukas Fittl",
                    "Pavlos Vinieratos",
                ])
                LicenseSection("Fonts", fonts)
                LicenseSection("Licenses", [
                    License(name: "Binding+mappedToBool", author: "Joseph Duffy", filename: "Binding+mappedToBool"),
                    License(name: "Diligence", author: "InSeven Limited", filename: "Diligence"),
                    License(name: "Swift-Sodium", author: "Frank Denis", filename: "Swift-Sodium"),
                ])
            }
            .navigationBarTitle("", displayMode: .inline)
            .navigationBarItems(trailing: Button {
                presentationMode.wrappedValue.dismiss()
            } label: {
                Text("Done")
                    .bold()
            })
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }

}
