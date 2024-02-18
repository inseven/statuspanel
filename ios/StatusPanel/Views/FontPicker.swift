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

struct FontPicker: View {

    struct FontList: View {

        @Environment(\.dismiss) var dismiss

        let title: String
        @Binding var selection: String

        var body: some View {
            List {
                ForEach(Fonts.availableFonts) { font in
                    Button {
                        selection = font.configName
                        dismiss()
                    } label: {
                        HStack {
                            FontView(font.humanReadableName, font: font.configName)
                                .tag(font.configName)
                            Spacer()
                            if font.configName == selection {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
        }

    }

    let title: String

    @Binding var selection: String

    init(_ title: String, selection: Binding<String>) {
        self.title = title
        _selection = selection
    }

    var body: some View {
        NavigationLink {
            FontList(title: title, selection: $selection)
        } label: {
            LabeledContent(title) {
                FontView(Fonts.font(named: selection).humanReadableName, font: selection, color: .secondary)
                    .id(selection)
            }
        }
    }

}
