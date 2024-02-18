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

import SwiftUI

import Diligence

struct AboutView: View {

    var body: some View {
        Diligence.AboutView(repository: "inseven/statuspanel",
                            copyright: "Copyright © 2018-2024\nJason Morley, Tom Sutcliffe") {
            Action("Website", url: URL(string: "https://statuspanel.io")!)
            Action("Privacy Policy", url: URL(string: "https://statuspanel.io/privacy-policy")!)
            Action("GitHub", url: URL(string: "https://github.com/inseven/statuspanel")!)
        } acknowledgements: {
            Acknowledgements("Developers") {
                Credit("Jason Morley", url: URL(string: "https://jbmorley.co.uk"))
                Credit("Tom Sutcliffe", url: URL(string: "https://github.com/tomsci"))
            }
            Acknowledgements("Thanks") {
                Credit("Lukas Fittl")
                Credit("Pavlos Vinieratos", url: URL(string: "https://github.com/pvinis"))
                Credit("Sarah Barbour")
            }
        } licenses: {
            LicenseGroup("Fonts") {
                for license in Fonts.licenses {
                    license
                }
            }
            LicenseGroup("Licenses", includeDiligenceLicense: true) {
                License(name: "Binding+mappedToBool", author: "Joseph Duffy", filename: "Binding+mappedToBool.txt")
                License(name: "Material Icons", author: "Google", filename: "Material-Icons.txt")
                License(name: "StatusPanel", author: "Jason Morley, Tom Sutcliffe", filename: "StatusPanel.txt")
                License(name: "Swift-Sodium", author: "Frank Denis", filename: "Swift-Sodium.txt")
            }
        }
    }

}
