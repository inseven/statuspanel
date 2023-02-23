//
//  NSImage.swift
//  StatusPanel Simulator
//
//  Created by Jason Barrie Morley on 23/02/2023.
//

import AppKit

extension NSImage {

    convenience init(ciImage: CIImage) {
        let rep = NSCIImageRep(ciImage: ciImage)
        self.init(size: rep.size)
        addRepresentation(rep)
    }

    // TODO: Better API
    static func generateQRCode(from string: String) -> NSImage? {
        let data = string.data(using: String.Encoding.ascii)

        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            let transform = CGAffineTransform(scaleX: 3, y: 3)

            if let output = filter.outputImage?.transformed(by: transform) {
                return NSImage(ciImage: output)
            }
        }

        return nil
    }

}
