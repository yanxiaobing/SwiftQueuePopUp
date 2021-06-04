//
//  ViewController.swift
//  SwiftQueuePopUpDemo
//
//  Created by xbingo on 2019/12/27.
//  Copyright © 2019 Xbingo. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.white
        // Do any additional setup after loading the view.
        
        let btn = UIButton()
        btn.backgroundColor = UIColor.red
        btn.addTarget(self, action: #selector(buttonClick(sender:)), for: UIControl.Event.touchUpInside)
        self.view.addSubview(btn)
        
        btn.snp.makeConstraints { (make) in
            make.center.equalTo(self.view)
            make.size.equalTo(CGSize(width: 100, height: 100))
        }
    }

    @objc func buttonClick(sender:UIButton?){
        
        TestPopViewController.init(priority: .low, lowerPriorityHidden: true).showInQueue { (hideType) in

        }

        TestPopViewController.init(priority: .normal, lowerPriorityHidden: false).showInQueue { (hideType) in

        }
        
        TestPopViewController.init(priority: .veryLow, lowerPriorityHidden: false).showInQueue { (hideType) in

        }
    }
}

