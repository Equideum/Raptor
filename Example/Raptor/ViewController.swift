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

    override func viewDidLoad() {
        super.viewDidLoad()
     
        var raptor = Raptor.Engine(prodChain: false)
        raptor.k=nil
       
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

