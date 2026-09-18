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
    
    public init(duration: TimeInterval = 0.25, dismiss: Bool = false) {
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
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
                return
            }
            
            UIView.animate(withDuration: duration,
                           delay: 0,
                           options: UIView.AnimationOptions.curveEaseInOut,
                           animations: {
                targetVc.view.alpha = 0
                targetVc.popUpView.transform = CGAffineTransform.init(translationX: 0, y: targetVc.popUpView.bounds.height)
                
            }) { (finished) in
                if transitionContext.transitionWasCancelled {
                    targetVc.view.alpha = 1
                    targetVc.popUpView.transform = .identity
                }
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            }
            
        } else {
            
            guard let navVC = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to),
                  let targetVc = navVC.children.first as? PopUpViewController else {
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
                return
            }
            
            navVC.view.frame = transitionContext.finalFrame(for: navVC)
            transitionContext.containerView.addSubview(navVC.view)
            navVC.view.setNeedsLayout()
            navVC.view.layoutIfNeeded()
                        
            targetVc.popUpView.transform = CGAffineTransform.init(translationX: 0, y: targetVc.popUpView.bounds.height)
            
            UIView.animate(withDuration: duration,
                           delay: 0,
                           options:UIView.AnimationOptions.curveEaseInOut,
                           animations: {
                targetVc.popUpView.transform = CGAffineTransform.identity
            }) { finished in
                transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
            }
        }
    }
}
