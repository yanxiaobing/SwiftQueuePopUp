//
//  BottomToTopTransition.swift
//  SwiftQueuePopUpDemo
//
//  Created by xbingo on 2024/1/3.
//  Copyright © 2024 Xbingo. All rights reserved.
//

import UIKit

open class BottomToTopTransition: NSObject, UIViewControllerAnimatedTransitioning {
    
    open var dismiss: Bool = false
    open var duration: TimeInterval = 0.25
    
    convenience init(dismiss:Bool = false) {
        self.init(duration:0.25, dismiss:dismiss)
    }
    
    public init(duration:TimeInterval,dismiss:Bool) {
        super.init()
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
                targetVc.popUpView.transform = CGAffineTransform.init(scaleX: 0, y: targetVc.popUpView.bounds.height)
                
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
            
            targetVc.view.alpha = 0.25
            
            targetVc.popUpView.transform = CGAffineTransform.init(translationX: 0, y: targetVc.popUpView.bounds.height)
            
            UIView.animate(withDuration: duration,
                           delay: 0,
                           options:UIView.AnimationOptions.curveEaseInOut,
                           animations: {
                targetVc.view.alpha = 1
                targetVc.popUpView.transform = CGAffineTransform.identity
            }) { finished in
                transitionContext.completeTransition(true)
            }
        }
    }
}

