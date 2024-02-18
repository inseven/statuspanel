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

import UIKit

extension UILabel {

    enum ColorHint {
        case monochrome
        case inkyPalette
    }

    static func getLabel(frame: CGRect,
                         font fontName: String,
                         style: LabelStyle,
                         colorHint: ColorHint,
                         redactMode: RedactMode = .none) -> UILabel {
        dispatchPrecondition(condition: .onQueue(.main))
        let font = Fonts.font(named: fontName)
        let size = (style == .header) ? font.headerSize : (style == .subText) ? font.subTextSize : font.textSize
        if let bitmapInfo = font.bitmapInfo {
            let label = BitmapFontLabel(frame: frame, bitmapFont: bitmapInfo, scale: size, redactMode: redactMode)
            label.colorHint = colorHint
            return label
        } else if let uifont = UIFont(name: font.uifontName!, size: CGFloat(size)) {
            let label = BitmapFontLabel(frame: frame, uiFont: uifont, redactMode: redactMode)
            label.colorHint = colorHint
            return label
        }

        // Otherwise, a plain old label (this code path now only used if we fail to find a font)
        let label = UILabel(frame: frame)
        label.lineBreakMode = .byWordWrapping
        print("No UIFont found for \(font.uifontName!)!")
        for family in UIFont.familyNames {
            for fontName in UIFont.fontNames(forFamilyName: family) {
                print("Candidate: \(fontName)")
            }
        }
        return label
    }

}
