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
  
    var raptor = Raptor.Engine.sharedTest
    
    @objc private func updateState() {
        state.text = raptor.getState()
        didGuidLabel.text = raptor.getMyDidDoc()?.did
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
     
       
        
       
       NotificationCenter.default.addObserver(self, selector: #selector(updateState), name: NSNotification.Name(rawValue: RaptorStateUpdate), object: nil)
    }

    @IBAction func zeroizeClicked(_ sender: Any) {
        let k = raptor.getMyDidDoc()?.did
        print("DD")
        raptor.autoDestruct()
    }
    
    @IBOutlet weak var state: UILabel!
    
    @IBOutlet var didGuidLabel: UILabel!
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

