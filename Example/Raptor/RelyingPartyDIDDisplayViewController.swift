//
//  RelyingPartyDIDDisplayViewController.swift
//  Raptor_Example
//
//  Created by tom danner on 5/16/20.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import UIKit
import Raptor
import SwiftyJSON

class RelyingPartyDIDDisplayViewController: UIViewController {

    let raptor = Raptor.Engine.sharedTest
    
    override func viewDidLoad() {
        super.viewDidLoad()

        var k = JSON()
        k["did"].string = raptor.getMyDidDoc()?.did
        k["relayUrl"].string = "https://relay.fhirblocks.io/joesbar"
        var t = k.rawString()
        
        qrCode.image = generateQRCode(from: t!)
    }

    private func generateQRCode(from: String) -> UIImage? {
        let data = from.data(using: String.Encoding.ascii)
        if let filter = CIFilter(name: "CIQRCodeGenerator") {
            filter.setValue(data, forKey: "inputMessage")
            let transform = CGAffineTransform (scaleX: 6, y:6)
            if let output = filter.outputImage?.transformed(by: transform) {
                return UIImage(ciImage: output)
            }
        }
        return nil
    }
    
    
    @IBOutlet weak var qrCode: UIImageView!

}
