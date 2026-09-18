import UIKit

open class PopUpViewController: UIViewController, PopUpDelegate, UIViewControllerTransitioningDelegate {
    open var priority: PopUpPriority
    open var fromType: PopUpFromType
    open var emptyAreaEnabled: Bool
    open var lowerPriorityHidden: Bool
    open lazy var popUpView = UIView()
    open var presentTransitioning: UIViewControllerAnimatedTransitioning?
    open var dismissTransitioning: UIViewControllerAnimatedTransitioning?
    open var willHideBlock: PopUpViewWillHideBlock?
    open var didHidenBlock: PopUpViewDidHidenBlock?
    /// Called on the main thread for failed presentation or scene disconnection.
    /// Cancellation does not invoke didHidenBlock, which represents user actions.
    open var presentationFailureBlock: ((PopUpPresentationError) -> Void)?

    weak var owningQueue: PopUpQueue?
    private weak var sourceWindow: UIWindow?
    private var popUpWindow: PopUpWindowController?
    private var presentationNavigation: UINavigationController?
    private var presentationGeneration = 0
    private var hideRequested = false

    public init(priority: PopUpPriority = .normal, fromType: PopUpFromType = .window,
                emptyAreaEnabled: Bool = true, lowerPriorityHidden: Bool = false) {
        self.priority = priority
        self.fromType = fromType
        self.emptyAreaEnabled = emptyAreaEnabled
        self.lowerPriorityHidden = lowerPriorityHidden
        super.init(nibName: nil, bundle: nil)
        presentTransitioning = PopUpTransition(dismiss: false)
        dismissTransitioning = PopUpTransition(dismiss: true)
        willHideBlock = { [weak self] reason in self?.hide(reason: reason) }
    }

    required public init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// Compatibility entry point. Requires exactly one active scene in scene-based apps.
    open func showInQueue(_ didHidenBlock: @escaping PopUpViewDidHidenBlock) {
        popUpOnMain { [self] in
            guard self.owningQueue == nil else { return }
            self.prepare(didHidenBlock)
            self.sourceWindow = nil
            PopUpQueue.shared.addPopUp(self)
        }
    }

    /// The source controller must already belong to a visible window.
    open func showInQueue(from controller: UIViewController, _ didHidenBlock: @escaping PopUpViewDidHidenBlock) {
        popUpOnMain { [self] in
            guard self.owningQueue == nil else { return }
            self.prepare(didHidenBlock)
            guard let window = controller.viewIfLoaded?.window, !window.isHidden else {
                self.reportFailure(.contextUnavailable)
                return
            }
            // Nested popup requests inherit the scene, never the overlay as their presenter.
            self.sourceWindow = window.rootViewController is PopUpWindowController ? nil : window
            if #available(iOS 13.0, *), let scene = window.windowScene {
                PopUpQueue.queue(for: scene).addPopUp(self)
            } else { PopUpQueue.shared.addPopUp(self) }
        }
    }

    /// May be enqueued before activation; presentation waits until the scene becomes active.
    @available(iOS 13.0, *)
    open func showInQueue(in scene: UIWindowScene, _ didHidenBlock: @escaping PopUpViewDidHidenBlock) {
        popUpOnMain { [self] in
            guard self.owningQueue == nil else { return }
            self.prepare(didHidenBlock)
            self.sourceWindow = nil
            guard scene.activationState != .unattached, scene.session.role == .windowApplication else {
                self.reportFailure(.contextUnavailable)
                return
            }
            PopUpQueue.queue(for: scene).addPopUp(self)
        }
    }

    private func prepare(_ callback: @escaping PopUpViewDidHidenBlock) {
        didHidenBlock = callback
        hideRequested = false
    }

    override open func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(white: 0, alpha: 0.7)
        view.addSubview(popUpView)
    }

    open func present() {
        popUpOnMain { [self] in
            guard let queue = self.owningQueue else {
                PopUpQueue.shared.addPopUp(self)
                return
            }
            guard queue.currentPopUp === self, self.presentationNavigation == nil else { return }
            guard let window = queue.sourceWindow(preferred: self.sourceWindow),
                  let root = window.rootViewController else {
                queue.presentationCompleted(self, error: .contextUnavailable)
                return
            }
            let presenter = self.fromType == .current
                ? UIViewController.currentViewControllerFrom(viewController: root) : root
            if self.fromType != .window {
                guard presenter.viewIfLoaded?.window === window,
                      !presenter.isBeingDismissed, !presenter.isBeingPresented,
                      presenter.presentedViewController == nil,
                      presenter.transitionCoordinator == nil else {
                    queue.presentationCompleted(self, error: .presenterUnavailable)
                    return
                }
            }
            self.presentationGeneration += 1
            let token = self.presentationGeneration
            let navigation = UINavigationController(rootViewController: self)
            navigation.setNavigationBarHidden(true, animated: false)
            if self.presentTransitioning != nil || self.dismissTransitioning != nil {
                navigation.modalPresentationStyle = .custom
                navigation.transitioningDelegate = self
            } else { navigation.modalPresentationStyle = .overCurrentContext }
            self.presentationNavigation = navigation
            self.view.alpha = 1
            self.popUpView.transform = .identity
            let completed = { [weak self, weak queue] in
                guard let self = self, self.presentationGeneration == token else { return }
                queue?.presentationCompleted(self, error: nil)
            }
            if self.fromType == .window {
                let host = PopUpWindowController(navigation: navigation,
                                                 window: queue.makeOverlayWindow(source: window), source: window)
                self.popUpWindow = host
                host.show(animated: true, completion: completed)
            } else {
                let previousContext = presenter.definesPresentationContext
                presenter.definesPresentationContext = navigation.modalPresentationStyle == .overCurrentContext
                presenter.present(navigation, animated: true) {
                    presenter.definesPresentationContext = previousContext
                    completed()
                }
            }
        }
    }

    /// Closes both the UI and its queue entry.
    open func dismiss() { dismiss(animated: true) }

    open override func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {
        popUpOnMain { [self] in
            if let queue = self.owningQueue {
                queue.close(self, animated: flag, completion: completion)
            } else { self.temporarilyDismiss(animated: flag, completion: { completion?() }) }
        }
    }

    open func temporarilyDismiss(animated: Bool, completion: @escaping () -> Void) {
        popUpOnMain { [self] in
            let token = self.presentationGeneration
            let finish = { [weak self] in
                if let self = self, self.presentationGeneration == token {
                    self.popUpWindow = nil
                    self.presentationNavigation?.setViewControllers([], animated: false)
                    self.presentationNavigation = nil
                }
                completion()
            }
            if let host = self.popUpWindow {
                host.close(animated: animated, completion: finish)
            } else if let navigation = self.presentationNavigation, navigation.presentingViewController != nil {
                navigation.dismiss(animated: animated, completion: finish)
            } else { finish() }
        }
    }

    func cancelPresentation() {
        presentationGeneration += 1
        popUpWindow?.tearDown(restoreFocus: false)
        popUpWindow = nil
        presentationNavigation?.dismiss(animated: false)
        presentationNavigation?.setViewControllers([], animated: false)
        presentationNavigation = nil
    }

    func reportFailure(_ error: PopUpPresentationError) {
        if let callback = presentationFailureBlock { callback(error) }
        else { NSLog("SwiftQueuePopUp: %@", String(describing: error)) }
    }

    private func hide(reason: PopUpHideType) {
        popUpOnMain { [self] in
            guard !self.hideRequested else { return }
            self.hideRequested = true
            let callback = self.didHidenBlock
            self.dismiss(animated: true) { callback?(reason) }
        }
    }

    open func animationController(forPresented presented: UIViewController, presenting: UIViewController,
                                  source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        presentTransitioning
    }

    open func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        dismissTransitioning
    }

    override open func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard emptyAreaEnabled, let point = touches.first?.location(in: popUpView),
              !popUpView.bounds.contains(point) else { return }
        hide(reason: .emptyArea)
    }
}

class PopUpWindowController: UIViewController {
    private var window: UIWindow?
    private weak var previousKeyWindow: UIWindow?
    private let navigation: UINavigationController

    init(navigation: UINavigationController, window: UIWindow, source: UIWindow) {
        self.navigation = navigation
        self.window = window
        if #available(iOS 13.0, *), let scene = source.windowScene {
            previousKeyWindow = scene.windows.first(where: { $0.isKeyWindow })
        } else { previousKeyWindow = source }
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func show(animated: Bool, completion: @escaping () -> Void) {
        window?.rootViewController = self
        window?.windowLevel = .alert + 1
        window?.makeKeyAndVisible()
        definesPresentationContext = navigation.modalPresentationStyle == .overCurrentContext
        present(navigation, animated: animated, completion: completion)
    }

    func close(animated: Bool, completion: @escaping () -> Void) {
        super.dismiss(animated: animated) { [weak self] in
            self?.tearDown(restoreFocus: true)
            completion()
        }
    }

    func tearDown(restoreFocus: Bool) {
        guard let window = window else { return }
        var canRestore = restoreFocus && window.isKeyWindow
        if #available(iOS 13.0, *) {
            canRestore = canRestore && previousKeyWindow?.windowScene === window.windowScene
                && window.windowScene?.activationState == .foregroundActive
        }
        window.isHidden = true
        window.rootViewController = nil
        self.window = nil
        if canRestore, let previous = previousKeyWindow, !previous.isHidden { previous.makeKey() }
    }
}
