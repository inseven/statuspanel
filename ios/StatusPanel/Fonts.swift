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

import Foundation

class Fonts {
    struct BitmapInfo {
        let bitmapName: String
        let startIndex: Unicode.Scalar
        let charw: Int
        let charh: Int // aka ascent + descent, same as the "point size" of a TTF font
        let descent: Int
        let capHeight: Int
        let minWidth: Int? // If set, empty space on the right hand side of the image will be shrunk down to, at a minimum, this size

        init(bitmap: String, charWidth: Int, charHeight: Int, capHeight: Int, descent: Int, startIndex: Unicode.Scalar, minWidth: Int? = nil) {
            self.bitmapName = bitmap
            self.charw = charWidth
            self.charh = charHeight
            self.capHeight = capHeight
            self.descent = descent
            self.startIndex = startIndex
            self.minWidth = minWidth
        }

        var ascent: Int {
            return charh - descent
        }
    }

    struct Font: Identifiable {

        var id: String { configName }

        let configName: String
        let humanReadableName: String
        let uifontName: String? // nil if a bitmap font
        let bitmapInfo: BitmapInfo? // nil if a UIFont
        // These three are scale factors for bitmap fonts, point sizes for UIFonts
        let subTextSize: Int
        let textSize: Int
        let headerSize: Int
        // Copyright etc
        let attribution: String
        let supportsEmoji: Bool

        // UIFont constructor
        init(configName: String,
             humanName: String,
             uifont: String,
             subTextSize: Int,
             textSize: Int,
             headerSize: Int,
             attribution: String) {

            self.configName = configName
            self.humanReadableName = humanName
            self.uifontName = uifont
            self.bitmapInfo = nil
            self.subTextSize = subTextSize
            self.textSize = textSize
            self.headerSize = headerSize
            self.attribution = attribution
            self.supportsEmoji = false
        }

        // Bitmap constructor
        init(configName: String,
             humanName: String,
             bitmapInfo: BitmapInfo,
             subTextScale: Int,
             textScale: Int,
             headerScale: Int,
             attribution: String) {
            
            self.configName = configName
            self.humanReadableName = humanName
            self.uifontName = nil
            self.bitmapInfo = bitmapInfo
            self.subTextSize = subTextScale
            self.textSize = textScale
            self.headerSize = headerScale
            self.attribution = attribution
            self.supportsEmoji = true
        }
    }

    private static let castpixelAttribution = """
        Font by castpixel <https://www.patreon.com/castpixel>
        https://www.patreon.com/posts/16897144
        License: Free for any use
        """
    private static let castpixelAttributionHeroineSword = """
        Font by castpixel <https://www.patreon.com/castpixel>
        https://www.patreon.com/posts/39070970
        License: Free for any use
        """

    private static let unifontAttribution = """
        GNU Unifont 13.0.06.
        http://unifoundry.com/unifont/index.html
        License: SIL Open Font License version 1.1
        """

    static let guiConsFont = BitmapInfo(bitmap: "font6x10", charWidth: 6, charHeight: 10, capHeight: 7, descent: 2, startIndex: " ")
    static let unifont = BitmapInfo(bitmap: "unifont-13.0.06", charWidth: 16, charHeight: 16, capHeight: 10, descent: 2, startIndex: "\0", minWidth: 7)

    static let availableFonts = [
        Font(configName: "font6x10_2", humanName: "Guicons Font", bitmapInfo: guiConsFont, subTextScale: 1, textScale: 2, headerScale: 2,
             attribution: "Guicons font taken from https://sourceforge.net/p/fshell/code/ci/default/tree/plugins/consoles/guicons/data/font_6x10.PNG licensed under the EPL. Original author uncertain."),
        Font(configName: "unifont", humanName: "Unifont 16pt", bitmapInfo: unifont, subTextScale: 1, textScale: 1, headerScale: 1, attribution: unifontAttribution),
        Font(configName: "unifont_2", humanName: "Unifont 32pt", bitmapInfo: unifont, subTextScale: 1, textScale: 2, headerScale: 2, attribution: unifontAttribution),
        Font(configName: "amiga4ever", humanName: "Amiga Forever", uifont: "Amiga Forever", subTextSize: 8, textSize: 16, headerSize: 24, attribution: """
            "Amiga 4ever" Truetype Font
            Copyright (c) 2001 by ck! [Freaky Fonts]. All rights reserved.

            The personal, non-commercial use of my font is free.
            But Donations are accepted and highly appreciated!
            The use of my fonts for commercial and profit purposes is prohibited,
            unless a small donation is send to me.
            Contact: ck@freakyfonts.de
            These font files may not be modified or renamed.
            This readme file must be included with each font, unchanged.
            Redistribute? Sure, but contact me first.

            If you like the font, please mail: ck@freakyfonts.de

            Visit .:Freaky Fonts:. for updates and new fonts (PC & MAC) :
            www.freakyfonts.de

            Thanks again to {ths} for the Mac conversion.
            1@ths.nu or visit: www.ths.nu

            Note:
            Photoshop use: Size 8 (& multiplier) - antialising turned off
            Paintshop use: Size 6 (& multiplier) - antialising turned off
            Amiga 4ever = like the original, 8x8 - sideborder vary
            Amiga 4ever pro = modified, mainly 2 pixel sideborder
            Amiga 4ever pro2 = ... mainly 1 pixel sideborder
            This font includes some dingbats, cut & paste: ƒ„…†‡ˆ
            All trademarks are property of their respective owners.
            """),
        Font(configName: "heroinesword", humanName: "Heroine Sword", uifont: "8x8BoldWideMono", subTextSize: 16, textSize: 32, headerSize: 48, attribution: castpixelAttributionHeroineSword),
        Font(configName: "jinxedwizards", humanName: "Jinxed Wizards", uifont: "JinxedWizards", subTextSize: 16, textSize: 16, headerSize: 16, attribution: castpixelAttribution),
        Font(configName: "roboty", humanName: "RobotY", uifont: "RobotY", subTextSize: 16, textSize: 32, headerSize: 32, attribution: castpixelAttribution),
        Font(configName: "pixelbyzantine", humanName: "PixelByzantine", uifont: "PixelByzantine", subTextSize: 16, textSize: 32, headerSize: 32, attribution: castpixelAttribution),
        Font(configName: "chikarego", humanName: "ChiKareGo", uifont: "ChiKareGo", subTextSize: 16, textSize: 32, headerSize: 48, attribution: """
            ChiKareGo by Giles Booth
            http://www.pentacom.jp/pentacom/bitfontmaker2/gallery/?id=3778
            License: Creative Commons Attribution
            """),
        Font(configName: "chikarego2", humanName: "ChiKareGo 2", uifont: "ChiKareGo2", subTextSize: 16, textSize: 32, headerSize: 48, attribution: """
            ChiKareGo2 by Giles Booth
            http://www.pentacom.jp/pentacom/bitfontmaker2/gallery/?id=3780
            License: Creative Commons Attribution
            """),
    ]
}
