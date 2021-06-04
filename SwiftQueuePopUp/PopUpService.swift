//
//  XBPopUpProtocol.swift
//  QuitSmoke
//
//  Created by xbingo on 2019/12/25.
//  Copyright © 2019 Xbingo. All rights reserved.
//

import UIKit

public enum PopUpFromType{
    case window
    case root
    case current
}

public enum PopUpHideType{
    case emptyArea
    case afterSelected
    case closeView
}

public enum PopUpPriority : Int {
    case veryLow = -2
    case low = -1
    case normal = 0
    case high = 1
    case veryHigh = 2
}

public typealias PopUpViewWillHideBlock = ((PopUpHideType)->())
public typealias PopUpViewDidHidenBlock = ((PopUpHideType)->())


//MARK: PopUpDelegate
public protocol PopUpDelegate : NSObjectProtocol{
    
    // 弹窗出场优先级
    var priority : PopUpPriority { get set }
    // 从哪个控制器弹出
    var fromType : PopUpFromType { get set }
    // 空白区域点击是否响应
    var emptyAreaEnabled : Bool { get set }
    // 如果当前弹窗支持，则有优先级更高的弹窗时，会暂时隐藏当前弹窗
    var lowerPriorityHidden : Bool { get set }
    // 自定义弹出动画
    var presentTransitioning : UIViewControllerAnimatedTransitioning? { get set }
    // 自定义隐藏动画
    var dismissTransitioning : UIViewControllerAnimatedTransitioning? { get set }
    
    // 弹窗内容容器，默认做transform scale 动画
    var popUpView : UIView { get set}
    // 内部处理，告知弹窗即将隐藏
    var willHideBlock : PopUpViewWillHideBlock? { get set }
    // 外部处理，处理弹窗操作事件
    var didHidenBlock : PopUpViewDidHidenBlock? { get set }
    
    func present()
    func dismiss()
    func temporarilyDismiss( animated:Bool, completion:@escaping()->Void )
}

//MARK: PopUpQueue
public class PopUpQueue : NSObject{
    
    public static let shared = PopUpQueue()
    
    override init() {
        super.init()
    }
    
    var currentPopUp : PopUpDelegate?
    
    var queue = [PopUpDelegate]()
    
    public func addPopUp(_ popUp:PopUpDelegate){
        
        let exists = queue.contains { (target) -> Bool in
            return target.isEqual(popUp)
        }
        
        if exists { return }
        
        queue.append(popUp)
        
        if queue.count == 1 {
            currentPopUp = popUp;
            popUp.present()
        }else{
            // 根据优先级进行排序
            sortPopUps()
            // 当前弹窗不支持临时隐藏
            if !currentPopUp!.lowerPriorityHidden {
                return
            }
            // 当前弹窗为优先级最高
            if currentPopUp!.isEqual(queue.first!) {
                return
            }
            // 临时隐藏，为更高优先级弹窗让路
            currentPopUp!.temporarilyDismiss(animated: true) {
                self.queue.first!.present()
            }
            currentPopUp = self.queue.first!
        }
    }
    
    func removePopUp(_ popUp:PopUpDelegate) {
        
        let exists = queue.contains { (target) -> Bool in
            return target.isEqual(popUp)
        }
        if exists {
            queue.removeAll { (target) -> Bool in
                return target.isEqual(popUp)
            }
            if queue.count > 0 {
                currentPopUp = queue.first!
                queue.first!.present()
            }else{
                currentPopUp = nil
            }
        }
    }
    
    fileprivate func sortPopUps() {
        queue.sort(by:{ (popUp1:PopUpDelegate, popUp2:PopUpDelegate) -> Bool in
            popUp1.priority.rawValue > popUp2.priority.rawValue
        })
    }
}

//MARK: GET FromVC
extension UIViewController{
    
    class func currentViewController() -> UIViewController? {
        if let root = UIApplication.shared.delegate?.window??.rootViewController {
            return currentViewControllerFrom(viewController: root);
        }
        return nil
    }
    
    class func currentViewControllerFrom(viewController:UIViewController) -> UIViewController {
        
        if viewController.isKind(of: UINavigationController.self) {
            return currentViewControllerFrom(viewController: viewController.children.last!)
        }
        if viewController.isKind(of: UITabBarController.self) {
            let tabbarVC = viewController as! UITabBarController
            return currentViewControllerFrom(viewController: tabbarVC.selectedViewController!)
        }
        if (viewController.presentedViewController != nil){
            return currentViewControllerFrom(viewController: viewController.presentedViewController!)
        }
        return viewController
    }
}
