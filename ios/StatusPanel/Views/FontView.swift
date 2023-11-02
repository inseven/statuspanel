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

struct FontView: UIViewRepresentable {

    let text: String
    let font: String

    // N.B. Unfortunately SwiftUI doesn't seem to expose the foreground color (as set by the `.foregroundColor` view
    // modifier, so it's necessary to make it explicit. Hopefully this can be replaced with an officail API in the
    // future.
    let color: Color

    let redactMode: RedactMode

    init(_ text: String, font: String, color: Color = .primary, redactMode: RedactMode = .none) {
        self.text = text
        self.font = font
        self.color = color
        self.redactMode = redactMode
    }

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel.getLabel(frame: .zero, font: font, style: .text, colorHint: .monochrome, redactMode: redactMode)
        label.text = text
        label.textColor = UIColor(color)
        return label
    }

    func updateUIView(_ uiView: UILabel, context: Context) {
        uiView.text = text
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        uiView.sizeThatFits(.zero)
    }

}
