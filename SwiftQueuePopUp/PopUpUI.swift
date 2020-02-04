//
//  PopUpUI.swift
//  QuitSmoke
//
//  Created by xbingo on 2019/12/26.
//  Copyright © 2019 Xbingo. All rights reserved.
//

import UIKit

open class PopUpViewController: UIViewController,PopUpDelegate,UIViewControllerTransitioningDelegate {
    
    var priority: PopUpPriority
    
    var fromType: PopUpFromType
    
    var emptyAreaEnabled: Bool
    
    var lowerPriorityHidden: Bool
    
    var popUpView: UIView?
    
    var presentTransitioning: UIViewControllerAnimatedTransitioning?
    
    var dismissTransitioning: UIViewControllerAnimatedTransitioning?
    
    var willHideBlock: PopUpViewWillHideBlock?
    
    var didHidenBlock: PopUpViewDidHidenBlock?
    
    convenience init(){
        
        self.init(priority:PopUpPriority.normal,
                  fromType:PopUpFromType.root,
                  emptyAreaEnabled:true,
                  lowerPriorityHidden:false)
    }
    
    init(priority:PopUpPriority,fromType: PopUpFromType,emptyAreaEnabled: Bool,lowerPriorityHidden: Bool){
        
        self.priority = priority;
        self.fromType = fromType;
        self.emptyAreaEnabled = emptyAreaEnabled;
        self.lowerPriorityHidden = lowerPriorityHidden;
        
        super.init(nibName: nil, bundle: nil)
        
        presentTransitioning = PopUpTransition.init(dismiss: false)
        dismissTransitioning = PopUpTransition.init(dismiss: true)
        
        self.willHideBlock = {[weak self] (hideType)->()in
            
            self?.dismiss(animated: true) {
                self?.dismiss()
                if self?.didHidenBlock != nil {
                    self?.didHidenBlock!(hideType)
                }
            }
        }
    }
    
    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func showInQueue(_ didHidenBlock: @escaping PopUpViewDidHidenBlock) {
        self.didHidenBlock = didHidenBlock
        PopUpQueue.shared.addPopUp(self)
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor.init(white: 0, alpha: 0.7)
        
        popUpView = UIView.init()
        self.view.addSubview(popUpView!)
    }
    
    func present() {
        
        var rootVC : UIViewController?
        
        if fromType == PopUpFromType.current{
            rootVC =  UIViewController.currentViewController()
        }else{
            rootVC = UIApplication.shared.delegate?.window??.rootViewController
        }
        
        let navVC = UINavigationController.init(rootViewController: self)
        
        navVC.setNavigationBarHidden(true, animated: false)
        
        if presentTransitioning != nil || dismissTransitioning != nil{
            navVC.modalPresentationStyle = UIModalPresentationStyle.custom
            navVC.transitioningDelegate = self
        }else{
            navVC.modalPresentationStyle = UIModalPresentationStyle.overCurrentContext
            rootVC?.definesPresentationContext = true
        }
        rootVC?.present(navVC, animated: true, completion: nil)
    }
    
    func dismiss() {
        PopUpQueue.shared.removePopUp(self)
    }
    
    func temporarilyDismiss(animated: Bool, completion: @escaping () -> Void) {
        self.dismiss(animated: animated) {
            completion()
        }
    }
    
    public func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return presentTransitioning
    }
    
    public func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return dismissTransitioning
    }
    
    override open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if emptyAreaEnabled {
            self.dismiss(animated: true) {
                self.dismiss()
                if self.didHidenBlock != nil {
                    self.didHidenBlock!(PopUpHideType.emptyArea)
                }
            }
        }
    }
    
    deinit {
        debugPrint("PopUpViewController is deinit")
    }
}


// MARK: PopUpTransition
class PopUpTransition: NSObject,UIViewControllerAnimatedTransitioning {
    
    var minScale : CGFloat = 0.85
    var maxScale : CGFloat = 1.0
    var dismiss : Bool = false
    var duration : TimeInterval = 0.25
    
    convenience init(dismiss:Bool = false) {
        self.init(minScale:0.85,maxScale:1.0,duration:0.25,dismiss:dismiss)
    }
    
    init(minScale:CGFloat,maxScale:CGFloat,duration:TimeInterval,dismiss:Bool) {
        super.init()
        self.minScale = minScale
        self.maxScale = maxScale
        self.duration = duration
        self.dismiss = dismiss
    }
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return duration
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        
        let duration = self.transitionDuration(using: transitionContext)
        
        if self.dismiss {
            let navVC = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.from)
            let vc = navVC?.children.first as! PopUpViewController
            
            UIView.animate(withDuration: duration,
                           delay: 0,
                           options: UIView.AnimationOptions.curveEaseInOut,
                           animations: {
                            vc.view.alpha = 0
                            vc.popUpView?.transform = CGAffineTransform.init(scaleX: self.minScale, y: self.minScale)
                            
            }) { (finished) in
                vc.view.removeFromSuperview()
                transitionContext.completeTransition(true)
            }
        }else{
            
            let navVC = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to)
            
            let vc = navVC?.children.first as! PopUpViewController
            
            transitionContext.containerView.addSubview(vc.view)
            
            vc.view.alpha = 0
            
            vc.popUpView?.transform = CGAffineTransform.init(scaleX: self.minScale, y: self.minScale)
            
            UIView.animate(withDuration: duration,
                           delay: 0,
                           options:UIView.AnimationOptions.curveEaseInOut,
                           animations: {
                            vc.view.alpha = 1
                            vc.popUpView?.transform = CGAffineTransform.init(scaleX: self.maxScale, y: self.maxScale)
            }) { (finished) in
                transitionContext.completeTransition(true)
            }
        }
    }
}
