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

import Foundation

import Diligence

class Fonts {

    struct BitmapInfo {
        let bitmapName: String
        let startIndex: Unicode.Scalar
        let charw: Int
        let charh: Int // aka ascent + descent, same as the "point size" of a TTF font
        let descent: Int
        let capHeight: Int
        let minWidth: Int? // If set, empty space on the right hand side of the image will be shrunk down to, at a minimum, this size

        init(bitmap: String,
             charWidth: Int,
             charHeight: Int,
             capHeight: Int,
             descent: Int,
             startIndex: Unicode.Scalar,
             minWidth: Int? = nil) {
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
        let license: License
        let supportsEmoji: Bool

        // UIFont constructor
        init(configName: String,
             humanName: String,
             uifont: String,
             subTextSize: Int,
             textSize: Int,
             headerSize: Int,
             author: String,
             attributes: [NamedURL] = [],
             license: String) {

            self.configName = configName
            self.humanReadableName = humanName
            self.uifontName = uifont
            self.bitmapInfo = nil
            self.subTextSize = subTextSize
            self.textSize = textSize
            self.headerSize = headerSize
            self.license = License(humanName, author: author, attributes: attributes, text: license)
            self.supportsEmoji = false
        }

        // Bitmap constructor
        init(configName: String,
             humanName: String,
             bitmapInfo: BitmapInfo,
             subTextScale: Int,
             textScale: Int,
             headerScale: Int,
             author: String,
             attributes: [NamedURL] = [],
             license: String) {
            
            self.configName = configName
            self.humanReadableName = humanName
            self.uifontName = nil
            self.bitmapInfo = bitmapInfo
            self.subTextSize = subTextScale
            self.textSize = textScale
            self.headerSize = headerScale
            self.license = License(humanName, author: author, attributes: attributes, text: license)
            self.supportsEmoji = true
        }

        var textHeight: Int {
            if let bitmapInfo = self.bitmapInfo {
                // Bitmap font, textSize is scale factor
                return bitmapInfo.charh * textSize
            } else {
                // UIFont, textSize is the font size
                return textSize
            }
        }
    }

    static let guiConsFont = BitmapInfo(bitmap: "font6x10", charWidth: 6, charHeight: 10, capHeight: 7, descent: 2, startIndex: " ")
    static let unifont = BitmapInfo(bitmap: "unifont-15.0.01", charWidth: 16, charHeight: 16, capHeight: 10, descent: 2, startIndex: "\0", minWidth: 7)

    class FontName {
        static let guicons = "font6x10_2"
        static let unifont16 = "unifont"
        static let unifont32 = "unifont_2"
        static let amiga4Ever = "amiga4ever"
        static let heroineSword = "heroinesword"
        static let jinxedWizards = "jinxedwizards"
        static let robotY = "roboty"
        static let pixelByzantine = "pixelbyzantine"
        static let chiKareGo = "chikarego"
        static let chiKareGo2 = "chikarego2"
    }

    static let availableFonts = [

        Font(configName: FontName.guicons,
             humanName: "Guicons Font",
             bitmapInfo: guiConsFont,
             subTextScale: 1,
             textScale: 2,
             headerScale: 2,
             author: "Unknown",
             attributes: [
                NamedURL("Website", url: URL(string: "https://sourceforge.net/p/fshell/code/ci/default/tree/plugins/consoles/guicons")!)
             ],
             license: """
                Eclipse Public License - v 1.0

                THE ACCOMPANYING PROGRAM IS PROVIDED UNDER THE TERMS OF THIS ECLIPSE PUBLIC LICENSE ("AGREEMENT"). ANY USE, REPRODUCTION OR DISTRIBUTION OF THE PROGRAM CONSTITUTES RECIPIENT'S ACCEPTANCE OF THIS AGREEMENT.

                1. DEFINITIONS

                "Contribution" means:

                a) in the case of the initial Contributor, the initial code and documentation distributed under this Agreement, and
                b) in the case of each subsequent Contributor:
                i) changes to the Program, and
                ii) additions to the Program;
                where such changes and/or additions to the Program originate from and are distributed by that particular Contributor. A Contribution 'originates' from a Contributor if it was added to the Program by such Contributor itself or anyone acting on such Contributor's behalf. Contributions do not include additions to the Program which: (i) are separate modules of software distributed in conjunction with the Program under their own license agreement, and (ii) are not derivative works of the Program.
                "Contributor" means any person or entity that distributes the Program.

                "Licensed Patents" mean patent claims licensable by a Contributor which are necessarily infringed by the use or sale of its Contribution alone or when combined with the Program.

                "Program" means the Contributions distributed in accordance with this Agreement.

                "Recipient" means anyone who receives the Program under this Agreement, including all Contributors.

                2. GRANT OF RIGHTS

                a) Subject to the terms of this Agreement, each Contributor hereby grants Recipient a non-exclusive, worldwide, royalty-free copyright license to reproduce, prepare derivative works of, publicly display, publicly perform, distribute and sublicense the Contribution of such Contributor, if any, and such derivative works, in source code and object code form.
                b) Subject to the terms of this Agreement, each Contributor hereby grants Recipient a non-exclusive, worldwide, royalty-free patent license under Licensed Patents to make, use, sell, offer to sell, import and otherwise transfer the Contribution of such Contributor, if any, in source code and object code form. This patent license shall apply to the combination of the Contribution and the Program if, at the time the Contribution is added by the Contributor, such addition of the Contribution causes such combination to be covered by the Licensed Patents. The patent license shall not apply to any other combinations which include the Contribution. No hardware per se is licensed hereunder.
                c) Recipient understands that although each Contributor grants the licenses to its Contributions set forth herein, no assurances are provided by any Contributor that the Program does not infringe the patent or other intellectual property rights of any other entity. Each Contributor disclaims any liability to Recipient for claims brought by any other entity based on infringement of intellectual property rights or otherwise. As a condition to exercising the rights and licenses granted hereunder, each Recipient hereby assumes sole responsibility to secure any other intellectual property rights needed, if any. For example, if a third party patent license is required to allow Recipient to distribute the Program, it is Recipient's responsibility to acquire that license before distributing the Program.
                d) Each Contributor represents that to its knowledge it has sufficient copyright rights in its Contribution, if any, to grant the copyright license set forth in this Agreement.
                3. REQUIREMENTS

                A Contributor may choose to distribute the Program in object code form under its own license agreement, provided that:

                a) it complies with the terms and conditions of this Agreement; and
                b) its license agreement:
                i) effectively disclaims on behalf of all Contributors all warranties and conditions, express and implied, including warranties or conditions of title and non-infringement, and implied warranties or conditions of merchantability and fitness for a particular purpose;
                ii) effectively excludes on behalf of all Contributors all liability for damages, including direct, indirect, special, incidental and consequential damages, such as lost profits;
                iii) states that any provisions which differ from this Agreement are offered by that Contributor alone and not by any other party; and
                iv) states that source code for the Program is available from such Contributor, and informs licensees how to obtain it in a reasonable manner on or through a medium customarily used for software exchange.
                When the Program is made available in source code form:

                a) it must be made available under this Agreement; and
                b) a copy of this Agreement must be included with each copy of the Program.
                Contributors may not remove or alter any copyright notices contained within the Program.

                Each Contributor must identify itself as the originator of its Contribution, if any, in a manner that reasonably allows subsequent Recipients to identify the originator of the Contribution.

                4. COMMERCIAL DISTRIBUTION

                Commercial distributors of software may accept certain responsibilities with respect to end users, business partners and the like. While this license is intended to facilitate the commercial use of the Program, the Contributor who includes the Program in a commercial product offering should do so in a manner which does not create potential liability for other Contributors. Therefore, if a Contributor includes the Program in a commercial product offering, such Contributor ("Commercial Contributor") hereby agrees to defend and indemnify every other Contributor ("Indemnified Contributor") against any losses, damages and costs (collectively "Losses") arising from claims, lawsuits and other legal actions brought by a third party against the Indemnified Contributor to the extent caused by the acts or omissions of such Commercial Contributor in connection with its distribution of the Program in a commercial product offering. The obligations in this section do not apply to any claims or Losses relating to any actual or alleged intellectual property infringement. In order to qualify, an Indemnified Contributor must: a) promptly notify the Commercial Contributor in writing of such claim, and b) allow the Commercial Contributor to control, and cooperate with the Commercial Contributor in, the defense and any related settlement negotiations. The Indemnified Contributor may participate in any such claim at its own expense.

                For example, a Contributor might include the Program in a commercial product offering, Product X. That Contributor is then a Commercial Contributor. If that Commercial Contributor then makes performance claims, or offers warranties related to Product X, those performance claims and warranties are such Commercial Contributor's responsibility alone. Under this section, the Commercial Contributor would have to defend claims against the other Contributors related to those performance claims and warranties, and if a court requires any other Contributor to pay any damages as a result, the Commercial Contributor must pay those damages.

                5. NO WARRANTY

                EXCEPT AS EXPRESSLY SET FORTH IN THIS AGREEMENT, THE PROGRAM IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, EITHER EXPRESS OR IMPLIED INCLUDING, WITHOUT LIMITATION, ANY WARRANTIES OR CONDITIONS OF TITLE, NON-INFRINGEMENT, MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE. Each Recipient is solely responsible for determining the appropriateness of using and distributing the Program and assumes all risks associated with its exercise of rights under this Agreement , including but not limited to the risks and costs of program errors, compliance with applicable laws, damage to or loss of data, programs or equipment, and unavailability or interruption of operations.

                6. DISCLAIMER OF LIABILITY

                EXCEPT AS EXPRESSLY SET FORTH IN THIS AGREEMENT, NEITHER RECIPIENT NOR ANY CONTRIBUTORS SHALL HAVE ANY LIABILITY FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING WITHOUT LIMITATION LOST PROFITS), HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OR DISTRIBUTION OF THE PROGRAM OR THE EXERCISE OF ANY RIGHTS GRANTED HEREUNDER, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.

                7. GENERAL

                If any provision of this Agreement is invalid or unenforceable under applicable law, it shall not affect the validity or enforceability of the remainder of the terms of this Agreement, and without further action by the parties hereto, such provision shall be reformed to the minimum extent necessary to make such provision valid and enforceable.

                If Recipient institutes patent litigation against any entity (including a cross-claim or counterclaim in a lawsuit) alleging that the Program itself (excluding combinations of the Program with other software or hardware) infringes such Recipient's patent(s), then such Recipient's rights granted under Section 2(b) shall terminate as of the date such litigation is filed.

                All Recipient's rights under this Agreement shall terminate if it fails to comply with any of the material terms or conditions of this Agreement and does not cure such failure in a reasonable period of time after becoming aware of such noncompliance. If all Recipient's rights under this Agreement terminate, Recipient agrees to cease use and distribution of the Program as soon as reasonably practicable. However, Recipient's obligations under this Agreement and any licenses granted by Recipient relating to the Program shall continue and survive.

                Everyone is permitted to copy and distribute copies of this Agreement, but in order to avoid inconsistency the Agreement is copyrighted and may only be modified in the following manner. The Agreement Steward reserves the right to publish new versions (including revisions) of this Agreement from time to time. No one other than the Agreement Steward has the right to modify this Agreement. The Eclipse Foundation is the initial Agreement Steward. The Eclipse Foundation may assign the responsibility to serve as the Agreement Steward to a suitable separate entity. Each new version of the Agreement will be given a distinguishing version number. The Program (including Contributions) may always be distributed subject to the version of the Agreement under which it was received. In addition, after a new version of the Agreement is published, Contributor may elect to distribute the Program (including its Contributions) under the new version. Except as expressly stated in Sections 2(a) and 2(b) above, Recipient receives no rights or licenses to the intellectual property of any Contributor under this Agreement, whether expressly, by implication, estoppel or otherwise. All rights in the Program not expressly granted under this Agreement are reserved.

                This Agreement is governed by the laws of the State of New York and the intellectual property laws of the United States of America. No party to this Agreement will bring a legal action under this Agreement more than one year after the cause of action arose. Each party waives its rights to a jury trial in any resulting litigation.
                """),

        Font(configName: FontName.unifont16,
             humanName: "Unifont 16pt",
             bitmapInfo: unifont,
             subTextScale: 1,
             textScale: 1,
             headerScale: 1,
             author: "Unifoundry",
             attributes: [
                NamedURL("Website", url: URL(string: "http://unifoundry.com/unifont/")!)
             ],
             license: """
                GNU Unifont 15.0.01.
                http://unifoundry.com/unifont/index.html
                License: SIL Open Font License version 1.1

                SIL OPEN FONT LICENSE

                Version 1.1 - 26 February 2007

                PREAMBLE
                The goals of the Open Font License (OFL) are to stimulate worldwide development of collaborative font projects, to support the font creation efforts of academic and linguistic communities, and to provide a free and open framework in which fonts may be shared and improved in partnership with others.

                The OFL allows the licensed fonts to be used, studied, modified and redistributed freely as long as they are not sold by themselves. The fonts, including any derivative works, can be bundled, embedded, redistributed and/or sold with any software provided that any reserved names are not used by derivative works. The fonts and derivatives, however, cannot be released under any other type of license. The requirement for fonts to remain under this license does not apply to any document created using the fonts or their derivatives.

                DEFINITIONS
                "Font Software" refers to the set of files released by the Copyright Holder(s) under this license and clearly marked as such. This may include source files, build scripts and documentation.

                "Reserved Font Name" refers to any names specified as such after the copyright statement(s).

                "Original Version" refers to the collection of Font Software components as distributed by the Copyright Holder(s).

                "Modified Version" refers to any derivative made by adding to, deleting, or substituting — in part or in whole — any of the components of the Original Version, by changing formats or by porting the Font Software to a new environment.

                "Author" refers to any designer, engineer, programmer, technical writer or other person who contributed to the Font Software.

                PERMISSION & CONDITIONS
                Permission is hereby granted, free of charge, to any person obtaining a copy of the Font Software, to use, study, copy, merge, embed, modify, redistribute, and sell modified and unmodified copies of the Font Software, subject to the following conditions:

                1) Neither the Font Software nor any of its individual components, in Original or Modified Versions, may be sold by itself.

                2) Original or Modified Versions of the Font Software may be bundled, redistributed and/or sold with any software, provided that each copy contains the above copyright notice and this license. These can be included either as stand-alone text files, human-readable headers or in the appropriate machine-readable metadata fields within text or binary files as long as those fields can be easily viewed by the user.

                3) No Modified Version of the Font Software may use the Reserved Font Name(s) unless explicit written permission is granted by the corresponding Copyright Holder. This restriction only applies to the primary font name as presented to the users.

                4) The name(s) of the Copyright Holder(s) or the Author(s) of the Font Software shall not be used to promote, endorse or advertise any Modified Version, except to acknowledge the contribution(s) of the Copyright Holder(s) and the Author(s) or with their explicit written permission.

                5) The Font Software, modified or unmodified, in part or in whole, must be distributed entirely under this license, and must not be distributed under any other license. The requirement for fonts to remain under this license does not apply to any document created using the Font Software.

                TERMINATION
                This license becomes null and void if any of the above conditions are not met.

                DISCLAIMER
                THE FONT SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT OF COPYRIGHT, PATENT, TRADEMARK, OR OTHER RIGHT. IN NO EVENT SHALL THE COPYRIGHT HOLDER BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, INCLUDING ANY GENERAL, SPECIAL, INDIRECT, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF THE USE OR INABILITY TO USE THE FONT SOFTWARE OR FROM OTHER DEALINGS IN THE FONT SOFTWARE.
                """),

        Font(configName: FontName.unifont32,
             humanName: "Unifont 32pt",
             bitmapInfo: unifont,
             subTextScale: 1,
             textScale: 2,
             headerScale: 2,
             author: "Unifoundry",
             attributes: [
                NamedURL("Website", url: URL(string: "http://unifoundry.com/unifont/")!)
             ],
             license: """
                GNU Unifont 15.0.01.
                http://unifoundry.com/unifont/index.html
                License: SIL Open Font License version 1.1

                SIL OPEN FONT LICENSE

                Version 1.1 - 26 February 2007

                PREAMBLE
                The goals of the Open Font License (OFL) are to stimulate worldwide development of collaborative font projects, to support the font creation efforts of academic and linguistic communities, and to provide a free and open framework in which fonts may be shared and improved in partnership with others.

                The OFL allows the licensed fonts to be used, studied, modified and redistributed freely as long as they are not sold by themselves. The fonts, including any derivative works, can be bundled, embedded, redistributed and/or sold with any software provided that any reserved names are not used by derivative works. The fonts and derivatives, however, cannot be released under any other type of license. The requirement for fonts to remain under this license does not apply to any document created using the fonts or their derivatives.

                DEFINITIONS
                "Font Software" refers to the set of files released by the Copyright Holder(s) under this license and clearly marked as such. This may include source files, build scripts and documentation.

                "Reserved Font Name" refers to any names specified as such after the copyright statement(s).

                "Original Version" refers to the collection of Font Software components as distributed by the Copyright Holder(s).

                "Modified Version" refers to any derivative made by adding to, deleting, or substituting — in part or in whole — any of the components of the Original Version, by changing formats or by porting the Font Software to a new environment.

                "Author" refers to any designer, engineer, programmer, technical writer or other person who contributed to the Font Software.

                PERMISSION & CONDITIONS
                Permission is hereby granted, free of charge, to any person obtaining a copy of the Font Software, to use, study, copy, merge, embed, modify, redistribute, and sell modified and unmodified copies of the Font Software, subject to the following conditions:

                1) Neither the Font Software nor any of its individual components, in Original or Modified Versions, may be sold by itself.

                2) Original or Modified Versions of the Font Software may be bundled, redistributed and/or sold with any software, provided that each copy contains the above copyright notice and this license. These can be included either as stand-alone text files, human-readable headers or in the appropriate machine-readable metadata fields within text or binary files as long as those fields can be easily viewed by the user.

                3) No Modified Version of the Font Software may use the Reserved Font Name(s) unless explicit written permission is granted by the corresponding Copyright Holder. This restriction only applies to the primary font name as presented to the users.

                4) The name(s) of the Copyright Holder(s) or the Author(s) of the Font Software shall not be used to promote, endorse or advertise any Modified Version, except to acknowledge the contribution(s) of the Copyright Holder(s) and the Author(s) or with their explicit written permission.

                5) The Font Software, modified or unmodified, in part or in whole, must be distributed entirely under this license, and must not be distributed under any other license. The requirement for fonts to remain under this license does not apply to any document created using the Font Software.

                TERMINATION
                This license becomes null and void if any of the above conditions are not met.

                DISCLAIMER
                THE FONT SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO ANY WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT OF COPYRIGHT, PATENT, TRADEMARK, OR OTHER RIGHT. IN NO EVENT SHALL THE COPYRIGHT HOLDER BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, INCLUDING ANY GENERAL, SPECIAL, INDIRECT, INCIDENTAL, OR CONSEQUENTIAL DAMAGES, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF THE USE OR INABILITY TO USE THE FONT SOFTWARE OR FROM OTHER DEALINGS IN THE FONT SOFTWARE.
                """),

        Font(configName: FontName.amiga4Ever,
             humanName: "Amiga Forever",
             uifont: "Amiga Forever",
             subTextSize: 8,
             textSize: 16,
             headerSize: 24,
             author: "ck! [Freaky Fonts]",
             license: """
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

        Font(configName: FontName.heroineSword,
             humanName: "Heroine Sword",
             uifont: "8x8BoldWideMono",
             subTextSize: 16,
             textSize: 32,
             headerSize: 48,
             author: "castpixel",
             license: """
                Font by castpixel <https://www.patreon.com/castpixel>
                https://www.patreon.com/posts/39070970
                License: Free for any use
                """),

        Font(configName: FontName.jinxedWizards,
             humanName: "Jinxed Wizards",
             uifont: "JinxedWizards",
             subTextSize: 16,
             textSize: 16,
             headerSize: 16,
             author: "castpixel",
             license: """
                Font by castpixel <https://www.patreon.com/castpixel>
                https://www.patreon.com/posts/16897144
                License: Free for any use
                """),

        Font(configName: FontName.robotY,
             humanName: "RobotY",
             uifont: "RobotY",
             subTextSize: 16,
             textSize: 32,
             headerSize: 32,
             author: "castpixel",
             license: """
                Font by castpixel <https://www.patreon.com/castpixel>
                https://www.patreon.com/posts/16897144
                License: Free for any use
                """),

        Font(configName: FontName.pixelByzantine,
             humanName: "PixelByzantine",
             uifont: "PixelByzantine",
             subTextSize: 16,
             textSize: 32,
             headerSize: 32,
             author: "castpixel",
             license: """
                Font by castpixel <https://www.patreon.com/castpixel>
                https://www.patreon.com/posts/16897144
                License: Free for any use
                """),

        Font(configName: FontName.chiKareGo,
             humanName: "ChiKareGo",
             uifont: "ChiKareGo",
             subTextSize: 16,
             textSize: 32,
             headerSize: 48,
             author: "Giles Booth",
             license: """
                ChiKareGo by Giles Booth
                http://www.pentacom.jp/pentacom/bitfontmaker2/gallery/?id=3778
                License: Creative Commons Attribution
                """),

        Font(configName: FontName.chiKareGo2,
             humanName: "ChiKareGo 2",
             uifont: "ChiKareGo2",
             subTextSize: 16,
             textSize: 32,
             headerSize: 48,
             author: "Giles Booth",
             license: """
                ChiKareGo2 by Giles Booth
                http://www.pentacom.jp/pentacom/bitfontmaker2/gallery/?id=3780
                License: Creative Commons Attribution
                """),
    ]

    static var licenses: [License] {
        return availableFonts
            .map { $0.license }
    }

}
