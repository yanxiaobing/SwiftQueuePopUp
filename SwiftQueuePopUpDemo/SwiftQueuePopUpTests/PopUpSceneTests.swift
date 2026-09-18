import XCTest
@testable import SwiftQueuePopUpDemo

@MainActor
final class PopUpSceneTests: XCTestCase {
    private func scene() async throws -> UIWindowScene {
        try await eventually {
            UIApplication.shared.connectedScenes.contains { $0.activationState == .foregroundActive }
        }
        return try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive })
    }

    private func eventually(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
        let deadline = Date().addingTimeInterval(5)
        while !condition(), Date() < deadline { try await Task.sleep(nanoseconds: 20_000_000) }
        XCTAssertTrue(condition(), "Timed out waiting for UI state", file: file, line: line)
    }

    private func visible(_ popup: PopUpViewController) -> Bool {
        popup.viewIfLoaded?.window != nil && popup.navigationController?.presentingViewController != nil
            && popup.navigationController?.isBeingPresented == false
            && popup.navigationController?.transitionCoordinator == nil
    }

    private func close(_ popup: PopUpViewController) async {
        await withCheckedContinuation { continuation in
            popup.dismiss(animated: false) { continuation.resume() }
        }
    }

    func testAllPresentationModesUseOriginSceneAndRestoreKeyWindow() async throws {
        let scene = try await scene()
        let original = try XCTUnwrap(scene.windows.first { $0.isKeyWindow })
        let root = try XCTUnwrap(original.rootViewController)
        for mode in [PopUpFromType.window, .root, .current] {
            let popup = PopUpViewController(fromType: mode)
            popup.presentationFailureBlock = { XCTFail("Unexpected error: \($0)") }
            popup.showInQueue(from: root) { _ in }
            try await eventually { self.visible(popup) }
            XCTAssertTrue(popup.view.window?.windowScene === scene)
            XCTAssertGreaterThan(popup.view.bounds.width, 0)
            XCTAssertGreaterThan(popup.view.bounds.height, 0)
            if mode == .window { XCTAssertFalse(popup.view.window === original) }
            else { XCTAssertTrue(popup.view.window === original) }
            await close(popup)
            XCTAssertTrue(original.isKeyWindow)
            XCTAssertNil(popup.owningQueue)
        }
    }

    func testRapidPreemptionQueuedCancellationAndSingleHideCallback() async throws {
        let scene = try await scene()
        let queue = PopUpQueue.queue(for: scene)
        let low = PopUpViewController(priority: .low, lowerPriorityHidden: true)
        let high = PopUpViewController(priority: .high, lowerPriorityHidden: true)
        let highest = PopUpViewController(priority: .veryHigh)
        var hides = 0
        low.showInQueue(in: scene) { _ in }
        // Enqueue while the first presentation may still be animating.
        try await eventually { queue.currentPopUp === low }
        high.showInQueue(from: low) { _ in }
        highest.showInQueue(in: scene) { _ in hides += 1 }
        await close(high)
        try await eventually { self.visible(highest) }
        XCTAssertNil(low.viewIfLoaded?.window)
        highest.willHideBlock?(.closeView)
        highest.willHideBlock?(.closeView)
        try await eventually { hides == 1 && self.visible(low) }
        XCTAssertEqual(hides, 1)
        XCTAssertFalse(queue.queue.contains { $0 === high })
        await close(low)
        XCTAssertTrue(queue.queue.isEmpty)
    }

    func testEqualPriorityFIFOAndDuplicateEnqueue() async throws {
        let scene = try await scene()
        let queue = PopUpQueue.queue(for: scene)
        let first = PopUpViewController()
        let second = PopUpViewController()
        first.showInQueue(in: scene) { _ in }
        second.showInQueue(in: scene) { _ in }
        first.showInQueue(in: scene) { _ in XCTFail("Duplicate enqueue replaced callback") }
        try await eventually { self.visible(first) }
        XCTAssertEqual(queue.queue.count, 2)
        await close(first)
        try await eventually { self.visible(second) }
        await close(second)
        XCTAssertTrue(queue.queue.isEmpty)
    }

    func testUnavailablePresenterFailsAndQueueContinues() async throws {
        let scene = try await scene()
        let window = try XCTUnwrap(scene.windows.first { $0.isKeyWindow })
        let root = try XCTUnwrap(window.rootViewController)
        let modal = UIViewController()
        await withCheckedContinuation { continuation in
            root.present(modal, animated: false) { continuation.resume() }
        }
        let bad = PopUpViewController(fromType: .root)
        let good = PopUpViewController(fromType: .current)
        var failures = 0
        bad.presentationFailureBlock = { error in
            if case .presenterUnavailable = error { failures += 1 } else { XCTFail("Wrong failure") }
        }
        bad.showInQueue(from: root) { _ in XCTFail("Failure is not a user hide") }
        good.showInQueue(from: root) { _ in }
        try await eventually { failures == 1 && self.visible(good) }
        XCTAssertTrue(good.navigationController?.presentingViewController === modal)
        await close(good)
        await withCheckedContinuation { continuation in
            modal.dismiss(animated: false) { continuation.resume() }
        }
    }

    func testMissingSourceFailsWithoutEnqueueing() {
        let popup = PopUpViewController()
        var failures = 0
        popup.presentationFailureBlock = { error in
            if case .contextUnavailable = error { failures += 1 }
        }
        popup.showInQueue(from: UIViewController()) { _ in XCTFail("Unexpected hide") }
        XCTAssertEqual(failures, 1)
        XCTAssertNil(popup.owningQueue)
    }

    func testDisconnectCancelsVisibleAndPendingAndAllowsFreshQueue() async throws {
        let scene = try await scene()
        let queue = PopUpQueue.queue(for: scene)
        let first = PopUpViewController()
        let second = PopUpViewController()
        var cancellations = 0
        for popup in [first, second] {
            popup.presentationFailureBlock = { error in
                if case .sceneDisconnected = error { cancellations += 1 }
            }
            popup.showInQueue(in: scene) { _ in XCTFail("Cancellation is not a user hide") }
        }
        try await eventually { self.visible(first) }
        // Drive the exact notification consumed by the library without destroying the test host.
        NotificationCenter.default.post(name: UIScene.didDisconnectNotification, object: scene)
        XCTAssertEqual(cancellations, 2)
        XCTAssertTrue(queue.queue.isEmpty)
        XCTAssertNil(first.owningQueue)
        XCTAssertNil(second.owningQueue)
        XCTAssertNil(first.viewIfLoaded?.window)
        let fresh = PopUpQueue.queue(for: scene)
        XCTAssertFalse(queue === fresh)
        let next = PopUpViewController()
        next.showInQueue(in: scene) { _ in }
        try await eventually { self.visible(next) }
        await close(next)
    }

    func testDismissDuringPresentationDoesNotStallNextItem() async throws {
        let scene = try await scene()
        let first = PopUpViewController()
        let second = PopUpViewController()
        first.showInQueue(in: scene) { _ in }
        try await eventually { PopUpQueue.queue(for: scene).currentPopUp === first }
        second.showInQueue(in: scene) { _ in }
        await close(first)
        try await eventually { self.visible(second) }
        await close(second)
    }

    func testCurrentControllerTraversalHandlesModalAndEmptyContainers() {
        let emptyNavigation = UINavigationController()
        XCTAssertTrue(UIViewController.currentViewControllerFrom(viewController: emptyNavigation) === emptyNavigation)
        let emptyTabs = UITabBarController()
        XCTAssertTrue(UIViewController.currentViewControllerFrom(viewController: emptyTabs) === emptyTabs)
    }
    func testZMultipleScenesHaveIndependentQueuesAndInactiveSceneWaits() async throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip("Requires iPad multiwindow") }
        let original = try await scene()
        let existing = Set(UIApplication.shared.connectedScenes.map { ObjectIdentifier($0) })
        UIApplication.shared.requestSceneSessionActivation(nil, userActivity: nil, options: nil) { error in
            XCTFail("Scene activation failed: \(error)")
        }
        try await eventually {
            UIApplication.shared.connectedScenes.contains {
                !existing.contains(ObjectIdentifier($0)) && $0.activationState == .foregroundActive
            }
        }
        let other = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first { !existing.contains(ObjectIdentifier($0)) })
        let first = PopUpViewController(priority: .low, lowerPriorityHidden: true)
        let second = PopUpViewController(priority: .veryHigh)
        first.showInQueue(in: original) { _ in }
        second.showInQueue(in: other) { _ in }
        let a = PopUpQueue.queue(for: original)
        let b = PopUpQueue.queue(for: other)
        XCTAssertFalse(a === b)
        XCTAssertTrue(first.owningQueue === a)
        XCTAssertTrue(second.owningQueue === b)
        XCTAssertEqual(a.queue.count, 1)
        XCTAssertEqual(b.queue.count, 1)
        if original.activationState != .foregroundActive {
            try await Task.sleep(nanoseconds: 100_000_000)
            XCTAssertNil(a.currentPopUp)
            XCTAssertNil(first.viewIfLoaded?.window)
        }
        try await eventually { self.visible(second) }
        await close(second)
        UIApplication.shared.requestSceneSessionActivation(original.session, userActivity: nil, options: nil) { error in
            XCTFail("Scene reactivation failed: \(error)")
        }
        try await eventually { self.visible(first) }
        XCTAssertTrue(first.view.window?.windowScene === original)
        await close(first)
        UIApplication.shared.requestSceneSessionDestruction(other.session, options: nil) { error in
            XCTFail("Scene cleanup failed: \(error)")
        }
    }

}
