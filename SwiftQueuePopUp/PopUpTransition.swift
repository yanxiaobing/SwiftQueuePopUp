//
//  PopUpTransition.swift
//  SwiftQueuePopUpDemo
//
//  Created by xbingo on 2024/1/3.
//  Copyright © 2024 Xbingo. All rights reserved.
//

import UIKit

// MARK: PopUpTransition
open class PopUpTransition: NSObject, UIViewControllerAnimatedTransitioning {
    
    open var minScale : CGFloat = 0.85
    open var maxScale : CGFloat = 1.0
    open var dismiss : Bool = false
    open var duration : TimeInterval = 0.25
    
    convenience init(dismiss:Bool = false) {
        self.init(minScale:0.85,maxScale:1.0,duration:0.25,dismiss:dismiss)
    }
    
    public init(minScale:CGFloat,maxScale:CGFloat,duration:TimeInterval,dismiss:Bool) {
        super.init()
        self.minScale = minScale
        self.maxScale = maxScale
        self.duration = duration
        self.dismiss = dismiss
    }
    
    open func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return duration
    }
    
    open func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        
        let duration = self.transitionDuration(using: transitionContext)
        
        if self.dismiss {
            
            guard let navVC = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.from),
                  let targetVc = navVC.children.first as? PopUpViewController else {
                transitionContext.completeTransition(true)
                return
            }
            
            UIView.animate(withDuration: duration,
                           delay: 0,
                           options: UIView.AnimationOptions.curveEaseInOut,
                           animations: {
                targetVc.view.alpha = 0
                targetVc.popUpView.transform = CGAffineTransform.init(scaleX: self.minScale, y: self.minScale)
                
            }) { (finished) in
                targetVc.view.removeFromSuperview()
                transitionContext.completeTransition(true)
            }
            
        } else {
            
            guard let navVC = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to),
                  let targetVc = navVC.children.first as? PopUpViewController else {
                transitionContext.completeTransition(true)
                return
            }
            
            transitionContext.containerView.addSubview(navVC.view)
            
            targetVc.view.alpha = 0
            
            targetVc.popUpView.transform = CGAffineTransform.init(scaleX: self.minScale, y: self.minScale)
            
            UIView.animate(withDuration: duration,
                           delay: 0,
                           options:UIView.AnimationOptions.curveEaseInOut,
                           animations: {
                targetVc.view.alpha = 1
                targetVc.popUpView.transform = CGAffineTransform.init(scaleX: self.maxScale, y: self.maxScale)
            }) { (finished) in
                transitionContext.completeTransition(true)
            }
        }
    }
}
