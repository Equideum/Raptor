//
//  ScanMyCovidStatusViewController.swift
//  Raptor_Example
//
//  Created by tom danner on 5/13/20.
//  Copyright © 2020 CocoaPods. All rights reserved.
//

import UIKit

class ScanMyCovidStatusViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

          var did: String? = "Hello Buddy"
                           if (did != nil) {
                               did = did?.replacingOccurrences(of: ":", with: "\\:")
                               let qr = generateQRCode(from: did!)
                               qrCode.image=qr
                           }
    }
    
    func generateQRCode(from string: String) -> UIImage? {
           let data = string.data(using: String.Encoding.ascii)
           if let filter = CIFilter(name: "CIQRCodeGenerator") {
               filter.setValue(data, forKey: "inputMessage")
               let transform = CGAffineTransform(scaleX: 8, y: 8)
               if let output = filter.outputImage?.transformed(by: transform) {
                   return UIImage(ciImage: output)
               }
           }
           return nil
       }
    
    @IBOutlet weak var qrCode: UIImageView!
    
    @IBAction func backHit(_ sender: Any) {
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
