//
//  ViewController.swift
//  Raptor
//
//  Created by downthefallline on 05/05/2020.
//  Copyright (c) 2020 downthefallline. All rights reserved.
//

import UIKit
import Raptor


class ViewController: UIViewController {

    // listen for update notifications from the raptor engine
  
    var raptor = Raptor.Engine(prodChain: false)
    
    @objc private func updateState() {
        state.text = raptor.getState()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
     
       
        
       
       NotificationCenter.default.addObserver(self, selector: #selector(updateState), name: NSNotification.Name(rawValue: RaptorStateUpdate), object: nil)
    }

    @IBOutlet weak var state: UILabel!
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

