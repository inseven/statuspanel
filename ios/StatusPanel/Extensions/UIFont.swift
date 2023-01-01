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

import UIKit

extension UIFont {

    // Returns nil if the character does not appear in the font (ie does NOT do automatic fallback to any other font)
    func renderCharacter(_ character: Character) -> CGImage? {
        let font = self as CTFont
        let ns = String(character) as NSString
        let nchars = ns.length
        var chars = Array<unichar>(repeating: 0, count: nchars)
        ns.getCharacters(&chars, range: NSMakeRange(0, nchars))
        var glyphs = Array<CGGlyph>(repeating: 0, count: nchars)
        let ok = CTFontGetGlyphsForCharacters(self, chars, &glyphs, nchars)
        if ok {
            let descent = CTFontGetDescent(font)
            // Drop any 0 glyphs, this can happen even if ok==true with non-BMP
            // chars, because there's 2 UTF-16 unichars (ie a surrogate pair)
            // that may map to only a single CGGlyph. Equally a single Character
            // can map to multiple glyphs (eg a letter plus a combining accent)
            glyphs = glyphs.compactMap { return $0 == 0 ? nil : $0 }
            var glyphBounds = Array<CGRect>(repeating: .zero, count: glyphs.count)
            let rect = CTFontGetOpticalBoundsForGlyphs(self, &glyphs, &glyphBounds, glyphs.count, .zero)
            let img = CGImage.New(rect.size, flipped: true) { ctx in
                ctx.setFillColor(UIColor.black.cgColor)
                for i in 0 ..< glyphs.count {
                    var transform = CGAffineTransform.init(translationX: glyphBounds[i].origin.x, y: descent)
                    if let path = CTFontCreatePathForGlyph(font, glyphs[i], &transform) {
                        ctx.addPath(path)
                    }
                }
                ctx.drawPath(using: .fill)
            }
            return img
        } else {
            return nil
        }
    }
}
