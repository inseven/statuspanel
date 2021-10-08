//
//  String.swift
//  String
//
//  Created by Jason Barrie Morley on 07/10/2021.
//  Copyright © 2021 Tom Sutcliffe. All rights reserved.
//

import Foundation

extension String {

    func dropPrefix(_ prefix: String) -> Substring {
        dropFirst(prefix.count)
    }

}
