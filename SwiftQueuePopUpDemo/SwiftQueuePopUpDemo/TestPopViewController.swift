//
//  TestPopViewController.swift
//  QuitSmoke
//
//  Created by xbingo on 2019/12/26.
//  Copyright © 2019 Xbingo. All rights reserved.
//

import UIKit
import SnapKit

class TestPopViewController: PopUpViewController {
    
    
    init(priority:PopUpPriority,lowerPriorityHidden:Bool) {
        super.init(priority: priority, fromType: .window, emptyAreaEnabled: true, lowerPriorityHidden: lowerPriorityHidden)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.popUpView.backgroundColor = UIColor.yellow
        self.popUpView.snp.makeConstraints({ (make) in
            make.size.equalTo(CGSize(width: 300, height: 300))
            make.center.equalTo(self.view.snp_center)
        })
        
        let textLab = UILabel()
        textLab.textAlignment = NSTextAlignment.center
        switch priority {
        case .veryLow:
            textLab.text = "veryLow"
        case .low:
            textLab.text = "low"
        case .normal:
            textLab.text = "normal"
        case .high:
            textLab.text = "high"
            break
        case .veryHigh:
            textLab.text = "veryHight"
        }
        self.popUpView.addSubview(textLab)
        textLab.snp.makeConstraints { (make) in
            make.edges.equalTo(self.popUpView);
        }
        
    }

}
