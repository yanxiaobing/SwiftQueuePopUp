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

/// Presentation failures and scene cancellation are separate from user hide actions.
public enum PopUpPresentationError: Error {
    case contextUnavailable
    case ambiguousContext
    case presenterUnavailable
    case sceneDisconnected
}

// All queue operations are serialized on the main thread, including legacy callers.
func popUpOnMain(_ action: @escaping () -> Void) {
    if Thread.isMainThread { action() } else { DispatchQueue.main.async(execute: action) }
}

public class PopUpQueue: NSObject {
    public static let shared = PopUpQueue()
    private static var sceneQueues: [ObjectIdentifier: PopUpQueue] = [:]
    private weak var sceneObject: AnyObject?
    private let sceneScoped: Bool
    private var disconnected = false
    private var observers: [NSObjectProtocol] = []
    private var generation = 0
    private var busy = false
    private var scheduled = false
    private(set) var currentPopUp: PopUpDelegate?
    private(set) var queue: [PopUpDelegate] = []

    private class CloseRequest {
        let animated: Bool
        var completions: [() -> Void] = []
        init(animated: Bool) { self.animated = animated }
    }
    private var closing: [ObjectIdentifier: CloseRequest] = [:]

    private init(scene: AnyObject? = nil) {
        sceneObject = scene
        sceneScoped = scene != nil
        super.init()
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: UIWindow.didBecomeVisibleNotification,
                                             object: nil, queue: .main) { [weak self] _ in self?.schedule() })
        observers.append(center.addObserver(forName: UIApplication.didBecomeActiveNotification,
                                             object: nil, queue: .main) { [weak self] _ in self?.schedule() })
        if #available(iOS 13.0, *), let scene = scene as? UIWindowScene {
            observers.append(center.addObserver(forName: UIScene.didActivateNotification,
                                                 object: scene, queue: .main) { [weak self] _ in self?.schedule() })
            observers.append(center.addObserver(forName: UIScene.didDisconnectNotification,
                                                 object: scene, queue: .main) { [weak self] _ in self?.disconnect() })
        }
    }

    deinit { observers.forEach(NotificationCenter.default.removeObserver) }

    /// Access on the main thread. The returned queue belongs only to this scene.
    @available(iOS 13.0, *)
    public static func queue(for scene: UIWindowScene) -> PopUpQueue {
        precondition(Thread.isMainThread, "Access scene queues on the main thread")
        let key = ObjectIdentifier(scene)
        if let queue = sceneQueues[key] { return queue }
        let queue = PopUpQueue(scene: scene)
        sceneQueues[key] = queue
        return queue
    }

    public func addPopUp(_ popUp: PopUpDelegate) {
        popUpOnMain { self.enqueue(popUp) }
    }

    private func enqueue(_ popUp: PopUpDelegate) {
        if let popup = popUp as? PopUpViewController, popup.owningQueue != nil { return }
        if !sceneScoped, #available(iOS 13.0, *), !UIApplication.shared.connectedScenes.isEmpty {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
                .filter { $0.session.role == .windowApplication && $0.activationState == .foregroundActive }
            guard scenes.count == 1, let scene = scenes.first else {
                reject(popUp, error: scenes.isEmpty ? .contextUnavailable : .ambiguousContext)
                return
            }
            Self.queue(for: scene).enqueue(popUp)
            return
        }
        guard !disconnected else {
            reject(popUp, error: .sceneDisconnected)
            return
        }
        guard !queue.contains(where: { $0 === popUp }) else { return }
        (popUp as? PopUpViewController)?.owningQueue = self
        queue.append(popUp)
        schedule()
    }

    private func reject(_ popup: PopUpDelegate, error: PopUpPresentationError) {
        if let popup = popup as? PopUpViewController { popup.reportFailure(error) }
        else { NSLog("SwiftQueuePopUp: %@", String(describing: error)) }
    }

    var isActive: Bool {
        if #available(iOS 13.0, *), sceneScoped {
            return (sceneObject as? UIWindowScene)?.activationState == .foregroundActive
        }
        return UIApplication.shared.applicationState == .active
    }

    func sourceWindow(preferred: UIWindow?) -> UIWindow? {
        if #available(iOS 13.0, *), sceneScoped {
            guard let scene = sceneObject as? UIWindowScene else { return nil }
            if let preferred = preferred, preferred.windowScene === scene,
               !preferred.isHidden, !(preferred.rootViewController is PopUpWindowController) { return preferred }
            let windows = scene.windows.filter {
                !$0.isHidden && $0.windowLevel == .normal && !($0.rootViewController is PopUpWindowController)
            }
            return windows.first(where: { $0.isKeyWindow }) ?? (windows.count == 1 ? windows.first : nil)
        }
        return preferred ?? UIApplication.shared.delegate?.window ?? nil
    }

    func makeOverlayWindow(source: UIWindow) -> UIWindow {
        if #available(iOS 13.0, *), let scene = source.windowScene {
            return UIWindow(windowScene: scene)
        }
        return UIWindow(frame: source.bounds)
    }

    private func schedule() {
        guard !scheduled, !disconnected else { return }
        scheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.scheduled = false
            self.advance()
        }
    }

    private func advance() {
        guard !busy, !disconnected else { return }
        // Closing queued items must also work while the scene is inactive.
        if let popup = queue.first(where: { closing[ObjectIdentifier($0)] != nil }) {
            let key = ObjectIdentifier(popup)
            guard let request = closing[key] else { return }
            let finish = { [weak self] in
                guard let self = self else { return }
                let completions = self.closing.removeValue(forKey: key)?.completions ?? []
                self.remove(popup)
                self.busy = false
                completions.forEach { $0() }
                self.schedule()
            }
            if currentPopUp === popup {
                busy = true
                let token = generation
                popup.temporarilyDismiss(animated: request.animated) { [weak self] in
                    popUpOnMain { if self?.generation == token { finish() } }
                }
            } else { finish() }
            return
        }
        guard isActive, !queue.isEmpty else { return }
        // Select without sorting: equal priorities retain FIFO order.
        let next = queue.dropFirst().reduce(queue[0]) {
            $1.priority.rawValue > $0.priority.rawValue ? $1 : $0
        }
        if let current = currentPopUp {
            guard current.lowerPriorityHidden, next.priority.rawValue > current.priority.rawValue else { return }
            busy = true
            let token = generation
            current.temporarilyDismiss(animated: true) { [weak self] in
                popUpOnMain {
                    guard let self = self, self.generation == token else { return }
                    self.currentPopUp = nil
                    self.busy = false
                    self.schedule()
                }
            }
            return
        }
        currentPopUp = next
        busy = true
        next.present()
        // Existing custom PopUpDelegate implementations retain their synchronous contract.
        if !(next is PopUpViewController) { presentationCompleted(next, error: nil) }
    }

    func presentationCompleted(_ popup: PopUpDelegate, error: PopUpPresentationError?) {
        guard currentPopUp === popup, !disconnected else { return }
        busy = false
        if let error = error {
            remove(popup)
            closing.removeValue(forKey: ObjectIdentifier(popup))
            (popup as? PopUpViewController)?.reportFailure(error)
        }
        schedule()
    }

    func close(_ popup: PopUpDelegate, animated: Bool, completion: (() -> Void)?) {
        let key = ObjectIdentifier(popup)
        guard queue.contains(where: { $0 === popup }) else { completion?(); return }
        let request = closing[key] ?? CloseRequest(animated: animated)
        if let completion = completion { request.completions.append(completion) }
        closing[key] = request
        schedule()
    }

    private func remove(_ popup: PopUpDelegate) {
        queue.removeAll { $0 === popup }
        if currentPopUp === popup { currentPopUp = nil }
        (popup as? PopUpViewController)?.owningQueue = nil
    }

    private func disconnect() {
        disconnected = true
        generation += 1
        let cancelled = queue
        queue.removeAll()
        currentPopUp = nil
        closing.removeAll()
        busy = false
        if let scene = sceneObject { Self.sceneQueues.removeValue(forKey: ObjectIdentifier(scene)) }
        for popup in cancelled {
            if let popup = popup as? PopUpViewController {
                popup.owningQueue = nil
                popup.cancelPresentation()
                popup.reportFailure(.sceneDisconnected)
            } else { popup.temporarilyDismiss(animated: false, completion: {}) }
        }
    }
}

extension UIViewController {
    class func currentViewControllerFrom(viewController: UIViewController) -> UIViewController {
        if let presented = viewController.presentedViewController, !presented.isBeingDismissed {
            return currentViewControllerFrom(viewController: presented)
        }
        if let navigation = viewController as? UINavigationController, let visible = navigation.visibleViewController {
            return currentViewControllerFrom(viewController: visible)
        }
        if let tabs = viewController as? UITabBarController, let selected = tabs.selectedViewController {
            return currentViewControllerFrom(viewController: selected)
        }
        if let split = viewController as? UISplitViewController, let last = split.viewControllers.last {
            return currentViewControllerFrom(viewController: last)
        }
        return viewController
    }
}
