//
//  PopUpUI.swift
//  QuitSmoke
//
//  Created by xbingo on 2019/12/26.
//  Copyright © 2019 Xbingo. All rights reserved.
//

import UIKit

open class PopUpViewController: UIViewController,PopUpDelegate,UIViewControllerTransitioningDelegate {
    
    open var priority: PopUpPriority
    
    open var fromType: PopUpFromType
    
    open var emptyAreaEnabled: Bool
    
    open var lowerPriorityHidden: Bool
    
    open lazy var popUpView : UIView = {
        let view = UIView()
        return view
    }()
    
    open var presentTransitioning: UIViewControllerAnimatedTransitioning?
    
    open var dismissTransitioning: UIViewControllerAnimatedTransitioning?
    
    open var willHideBlock: PopUpViewWillHideBlock?
    
    open var didHidenBlock: PopUpViewDidHidenBlock?
    
    private var popUpWindow : PopUpWindowController?
    
    convenience init(){
        self.init()
    }
    
    public init(priority:PopUpPriority = .normal,fromType: PopUpFromType = .window,emptyAreaEnabled: Bool = true,lowerPriorityHidden: Bool = false){
        
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
    
    open func showInQueue(_ didHidenBlock: @escaping PopUpViewDidHidenBlock) {
        self.didHidenBlock = didHidenBlock
        PopUpQueue.shared.addPopUp(self)
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.init(white: 0, alpha: 0.7)
        self.view.addSubview(popUpView)
    }
    
    open func present() {
        
        // 是否存在自定义动画
        let existTransitioning = presentTransitioning != nil || dismissTransitioning != nil
        
        // 构建弹窗导航控制器
        let navVC = UINavigationController.init(rootViewController: self)
        navVC.setNavigationBarHidden(true, animated: false)
        if existTransitioning {
            navVC.modalPresentationStyle = UIModalPresentationStyle.custom
            navVC.transitioningDelegate = self
        }else{
            navVC.modalPresentationStyle = UIModalPresentationStyle.overCurrentContext
        }
        
        if fromType == .window {
            popUpWindow = PopUpWindowController.init(popUpViewController: navVC)
            popUpWindow?.present(animated: true, completion: nil)
            return
        }
        
        var rootVC : UIViewController?
        if fromType == PopUpFromType.current{
            rootVC =  UIViewController.currentViewController()
        }else{
            rootVC = UIApplication.shared.delegate?.window??.rootViewController
        }
        rootVC?.definesPresentationContext = navVC.modalPresentationStyle == .overCurrentContext
        rootVC?.present(navVC, animated: true, completion: nil)
    }
    
    open func dismiss() {
        PopUpQueue.shared.removePopUp(self)
    }
    
    open override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        if fromType != .window {
            super.dismiss(animated: flag, completion: completion)
            return
        }
        
        weak var weakSelf = self
        popUpWindow?.dismiss(animated: flag, completion: {
            weakSelf?.popUpWindow = nil
            weakSelf?.dismiss()
        })
    }
    
    open func temporarilyDismiss(animated: Bool, completion: @escaping () -> Void) {
        
        if fromType != .window {
            super.dismiss(animated: animated) {
                completion()
            }
        }else{
            weak var weakSelf = self
            popUpWindow?.dismiss(animated: animated, completion: {
                weakSelf?.popUpWindow = nil
                completion()
            })
        }
    }
    
    open func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return presentTransitioning
    }
    
    open func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return dismissTransitioning
    }
    
    override open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        
        if emptyAreaEnabled {
            
            guard let point = touches.first?.location(in: self.view) else{
                return
            }
            
            let targetP = self.popUpView.layer.convert(point, from:  self.view.layer) 
            
            if self.popUpView.layer.contains(targetP) {
                return
            }
            
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
open class PopUpTransition: NSObject,UIViewControllerAnimatedTransitioning {
    
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
            let navVC = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.from)
            let vc = navVC?.children.first as! PopUpViewController
            
            UIView.animate(withDuration: duration,
                           delay: 0,
                           options: UIView.AnimationOptions.curveEaseInOut,
                           animations: {
                            vc.view.alpha = 0
                            vc.popUpView.transform = CGAffineTransform.init(scaleX: self.minScale, y: self.minScale)
                            
                           }) { (finished) in
                vc.view.removeFromSuperview()
                transitionContext.completeTransition(true)
            }
        }else{
            
            let navVC = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to)
            
            let vc = navVC?.children.first as! PopUpViewController
            
            transitionContext.containerView.addSubview(vc.view)
            
            vc.view.alpha = 0
            
            vc.popUpView.transform = CGAffineTransform.init(scaleX: self.minScale, y: self.minScale)
            
            UIView.animate(withDuration: duration,
                           delay: 0,
                           options:UIView.AnimationOptions.curveEaseInOut,
                           animations: {
                            vc.view.alpha = 1
                            vc.popUpView.transform = CGAffineTransform.init(scaleX: self.maxScale, y: self.maxScale)
                           }) { (finished) in
                transitionContext.completeTransition(true)
            }
        }
    }
}


class PopUpWindowController: UIViewController {
    
    // MARK: - Properties
    
    private lazy var window: UIWindow? = UIWindow(frame: UIScreen.main.bounds)
    private var popUpViewController: UINavigationController
    
    // MARK: - Initialization
    
    init(popUpViewController: UINavigationController) {
        
        self.popUpViewController = popUpViewController
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder aDecoder: NSCoder) {
        
        fatalError("This initializer is not supported")
    }
    
    // MARK: - Presentation
    
    func present(animated: Bool, completion: (() -> Void)?) {
        window?.rootViewController = self
        window?.windowLevel = UIWindow.Level.alert + 1
        window?.makeKeyAndVisible()
        self.definesPresentationContext = popUpViewController.modalPresentationStyle == .overCurrentContext
        present(popUpViewController, animated: animated, completion: completion)
    }
    
    // MARK: - Overrides
    
    override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        weak var weakSelf = self
        super.dismiss(animated: flag) {
            weakSelf?.window = nil
            completion?()
        }
    }
    
    deinit {
        debugPrint("PopUpWindowController is deinit")
    }
}
