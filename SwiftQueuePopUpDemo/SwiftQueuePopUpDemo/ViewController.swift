import UIKit

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let title = UILabel()
        title.text = "Scene 弹窗队列"
        title.font = .preferredFont(forTextStyle: .title1)
        title.textAlignment = .center
        let stack = UIStackView(arrangedSubviews: [title])
        stack.axis = .vertical
        stack.spacing = 20
        for (index, name) in ["独立窗口 .window", "根控制器 .root", "当前页面 .current"].enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(name, for: .normal)
            button.tag = index
            button.addTarget(self, action: #selector(showQueue(_:)), for: .touchUpInside)
            stack.addArrangedSubview(button)
        }
        if UIApplication.shared.supportsMultipleScenes {
            let button = UIButton(type: .system)
            button.setTitle("打开另一个窗口", for: .normal)
            button.addTarget(self, action: #selector(openWindow), for: .touchUpInside)
            stack.addArrangedSubview(button)
        }
        view.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20)
        ])
    }

    @objc private func showQueue(_ sender: UIButton) {
        let mode: PopUpFromType = [.window, .root, .current][sender.tag]
        for priority in [PopUpPriority.low, .normal, .veryLow] {
            let popup = TestPopViewController(priority: priority, lowerPriorityHidden: priority == .low)
            popup.fromType = mode
            popup.showInQueue(from: self) { _ in }
        }
    }

    @objc private func openWindow() {
        UIApplication.shared.requestSceneSessionActivation(nil, userActivity: nil, options: nil) { error in
            NSLog("Unable to open scene: %@", error.localizedDescription)
        }
    }
}
