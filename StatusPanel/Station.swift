//
//  Station.swift
//  StatusPanel
//
//  Created by Tom Sutcliffe on 30/03/2019.
//  Copyright © 2019 Tom Sutcliffe. All rights reserved.
//

import Foundation

// Note, stations.json was converted from the CSV at
// http://www.nationalrail.co.uk/stations_destinations/48541.aspx

class Station: NSObject, NSCoding, Codable {

    @objc let name: String
    @objc let code: String

    init(name: String, code: String) {
        self.name = name
        self.code = code
    }

    required init?(coder aDecoder: NSCoder) {
        name = aDecoder.decodeObject(forKey: "name") as! String
        code = aDecoder.decodeObject(forKey: "code") as! String
    }

    func encode(with aCoder: NSCoder) {
        aCoder.encode(name, forKey: "name")
        aCoder.encode(code, forKey: "code")
    }

    var nameAndCode: String {
        get {
            return "\(name) (\(code))"
        }
    }

}
