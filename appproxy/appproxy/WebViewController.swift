//
//  WebViewController.swift
//  appproxy
//
//  Created by Tomasen on 2/6/16.
//  Copyright © 2016 PINIDEA LLC. All rights reserved.
//

import UIKit

class WebViewController: UIViewController {

    @IBOutlet weak var wv: UIWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        wv.loadRequest(NSURLRequest(URL: NSURL(string: "https://www.google.com")!))
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
