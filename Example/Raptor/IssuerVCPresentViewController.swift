//
//  IssuerVCPresentViewController.swift
//  Raptor_Example
//
//  Created by tom danner on 5/7/20.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import UIKit

class IssuerVCPresentViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        var did: String? = "Hello Buddy"
               if (did != nil) {
                   did = did?.replacingOccurrences(of: ":", with: "\\:")
                   let qr = generateQRCode(from: did!)
                   QRCode.image=qr
               }
    }
    
    func generateQRCode(from string: String) -> UIImage? {
           let data = string.data(using: String.Encoding.ascii)
           if let filter = CIFilter(name: "CIQRCodeGenerator") {
               filter.setValue(data, forKey: "inputMessage")
               let transform = CGAffineTransform(scaleX: 6, y: 6)
               if let output = filter.outputImage?.transformed(by: transform) {
                   return UIImage(ciImage: output)
               }
           }
           return nil
       }

    @IBOutlet var QRCode: UIImageView!
    

}
