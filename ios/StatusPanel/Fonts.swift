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
    struct Font {
        let configName: String
        let humanReadableName: String
        let uifontName: String? // nil if a bitmap font
        let bitmapName: String? // nil if a UIFont
        // These three are scale factors for bitmap fonts, point sizes for UIFonts
        let subTextSize: Int
        let textSize: Int
        let headerSize: Int
        let attribution: String

        init(configName: String, humanName: String, uifont: String, subTextSize: Int, textSize: Int, headerSize: Int, attribution: String) {
            self.configName = configName
            self.humanReadableName = humanName
            self.uifontName = uifont
            self.bitmapName = nil
            self.subTextSize = subTextSize
            self.textSize = textSize
            self.headerSize = headerSize
            self.attribution = attribution
        }

        init(configName: String, humanName: String, bitmap: String, subTextScale: Int, textScale: Int, headerScale: Int, attribution: String) {
            self.configName = configName
            self.humanReadableName = humanName
            self.uifontName = nil
            self.bitmapName = bitmap
            self.subTextSize = subTextScale
            self.textSize = textScale
            self.headerSize = headerScale
            self.attribution = attribution
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

    static let availableFonts = [
        Font(configName: "font6x10_2", humanName: "Guicons Font", bitmap: "font6x10", subTextScale: 1, textScale: 2, headerScale: 2,
             attribution: "Guicons font taken from https://sourceforge.net/p/fshell/code/ci/default/tree/plugins/consoles/guicons/data/font_6x10.PNG licensed under the EPL. Original author uncertain."),
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
        // Font(configName: "advocut", humanName: "AdvoCut", uifont: "AdvoCut", subTextSize: 13, textSize: 27, headerSize: 37),
        // Font(configName: "silkscreen", humanName: "Silkscreen", uifont: "Silkscreen", subTextSize: 11, textSize: 17, headerSize: 32),
    ]
}
