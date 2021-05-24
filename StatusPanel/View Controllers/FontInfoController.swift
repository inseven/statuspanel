//
//  FontInfoController.swift
//  StatusPanel
//
//  Created by Tom Sutcliffe on 10/07/2020.
//  Copyright © 2020 Tom Sutcliffe. All rights reserved.
//

import UIKit

class FontInfoController : UIViewController {
    @IBOutlet weak var textView: UITextView!
    var font: Config.Font!

    override func viewWillAppear(_ animated: Bool) {
        textView.text = font.attribution
        self.navigationItem.title = font.humanReadableName

        super.viewWillAppear(animated)
    }
}
