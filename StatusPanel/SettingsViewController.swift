//
//  SettingsViewController.swift
//  StatusPanel
//
//  Created by Jason Barrie Morley on 13/01/2019.
//  Copyright © 2019 Tom Sutcliffe. All rights reserved.
//

import UIKit

class SettingsViewController: UIViewController {

    @IBOutlet weak var departuresSwitch: UISwitch!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.departuresSwitch.isOn = Config().isDeparturesEnabled
        self.departuresSwitch.addTarget(self, action: #selector(departuresSwitchDidChange), for: UIControlEvents.valueChanged)
    }

    @objc func departuresSwitchDidChange(sender: Any) {
        guard let senderSwitch = sender as? UISwitch else {
            return
        }
        Config().isDeparturesEnabled = senderSwitch.isOn
    }
    
    @IBAction func cancelTapped(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
