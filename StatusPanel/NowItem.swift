//
//  NowItem.swift
//  StatusPanel
//
//  Created by Pavlos Vinieratos on 11/05/2020.
//  Copyright © 2020 Tom Sutcliffe. All rights reserved.
//


class NowItem : DataItemBase {
    init(_ text: String, flags: Set<DataItemFlag> = Set()) {
        self.text = text
        self.flags = flags
    }

    let text: String
    let flags: Set<DataItemFlag>

    func getPrefix() -> String {
        return ""
    }

    func getText(checkFit: (String) -> Bool) -> String {
        return text
    }

    func getFlags() -> Set<DataItemFlag> {
        return flags
    }

    func getSubText() -> String? {
        return nil
    }
}
