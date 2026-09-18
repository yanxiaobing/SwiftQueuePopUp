# SwiftQueuePopUp

支持优先级、临时让位和按 `UIWindowScene` 隔离的 UIKit 弹窗队列。

## Swift Package Manager

支持 iOS 15+，库本身没有第三方依赖。Xcode 中选择 **File → Add Package Dependencies**，输入仓库地址：

```text
https://github.com/yanxiaobing/SwiftQueuePopUp.git
```

选择包含 `Package.swift` 的版本或分支，将 `SwiftQueuePopUp` 产品添加到 App Target，然后使用：

```swift
import SwiftQueuePopUp
```

当前 2.0.0 尚未发布；远程接入需要先推送这些改动。在此之前，可用 Xcode 的 **Add Local** 选择本仓库目录验证。发布 `2.0.0` 标签后，其他 Swift Package 可以这样依赖：

```swift
dependencies: [
    .package(url: "https://github.com/yanxiaobing/SwiftQueuePopUp.git", from: "2.0.0")
]
// 在需要使用弹窗库的 target 的 dependencies 中添加：
// .product(name: "SwiftQueuePopUp", package: "SwiftQueuePopUp")
```

SPM 和 CocoaPods 使用相同的库源码；Demo 和它的 SnapKit 依赖不会被打包。每个 App Target 选择一种接入方式，避免同时通过 SPM、CocoaPods 或直接编译源码引入同一个库。

## 2.0 迁移

- 最低部署版本调整为 **iOS 15**，与 Xcode 27 的部署目标要求一致；需要支持 iOS 11–14 的项目应暂留 1.x。
- 宿主 App 必须自行配置 UIScene 生命周期。更新弹窗库不会自动迁移宿主的 AppDelegate、深链或推送路由。
- Demo 已配置 SceneDelegate，并开启 iPad 多窗口用于验证；宿主不需要多窗口时，可以把 `UIApplicationSupportsMultipleScenes` 设为 `false`。
- 保留 `showInQueue { ... }`、`PopUpQueue.shared.addPopUp(...)` 和原 `PopUpDelegate` 协议。场景式 App 的旧入口只在**恰好一个前台活跃的 UIWindowScene** 时自动路由；没有合适的 Scene 或存在歧义时通过错误回调/日志报告，不随机选窗口。
- `dismiss()` 和 `dismiss(animated:completion:)` 现在都会关闭 UI 并移除队列项；不再需要在完成回调里额外调用一次 `dismiss()`。

## 推荐调用

从已显示的业务页面指定来源，三种 `fromType` 都限定在该页面的窗口场景内：

```swift
let popup = PopUpViewController(fromType: .window)
popup.presentationFailureBlock = { error in
    print("弹窗未展示或已因 Scene 断开而取消：", error)
}
popup.showInQueue(from: self) { hideType in
    // 空白区域、选择或关闭按钮引起的业务回调
}
```

控制器必须已经挂到可见窗口上。不要在页面的 `viewDidLoad()` 中调用页面入口；使用 `viewDidAppear`，或者在 Scene 已连接后明确指定它：

```swift
popup.showInQueue(in: windowScene) { hideType in
    // Scene 未激活时先排队，激活后再展示
}
```

自定义 `PopUpDelegate` 可以在主线程取得对应队列：

```swift
PopUpQueue.queue(for: windowScene).addPopUp(customPopup)
```

协议没有新增要求。自定义实现仍负责自身窗口的 Scene 绑定及转场完成；队列把其 `present()` 视为同步开始展示，并依靠 `temporarilyDismiss` 的 completion 推进。继承 `PopUpViewController` 的实现应保留 `super` 调用。

## 行为约定

- `.window`：创建绑定来源 Scene 的独立窗口；关闭时仅在它仍占据 key window 且原窗口有效、Scene 活跃时恢复焦点。
- `.root`：从来源业务窗口的根控制器展示。根控制器已有模态页面时报告 `presenterUnavailable`，不会覆盖已有展示。
- `.current`：沿模态页面、导航、Tab 和 Split 容器查找当前控制器。
- 同一 Scene 内按优先级调度，同优先级保持入队顺序。仅当当前弹窗允许 `lowerPriorityHidden` 且新项优先级更高时暂时隐藏，之后恢复。
- 展示、关闭、抢占串行执行。动画中关闭会等转场完成；取消尚未展示的项不会影响当前弹窗。
- Scene 失活时暂停启动新弹窗；恢复活跃后继续。Scene 断开时清空该 Scene 的队列并释放弹窗窗口，重连后由业务重新提交需要的弹窗，不保留旧 UIViewController。
- UI 操作、入队和关闭入口自动切到主线程。弹窗属性配置及 `queue(for:)` 的访问仍应在主线程执行。

`presentationFailureBlock` 在主线程报告：

| 错误 | 含义 |
| --- | --- |
| `contextUnavailable` | 来源页面未挂到窗口、没有活跃 Scene 或没有可用业务窗口 |
| `ambiguousContext` | 旧入口无法从多个活跃 Scene 中唯一确定目标 |
| `presenterUnavailable` | 展示控制器已有模态页面、正在转场或未挂到目标窗口 |
| `sceneDisconnected` | Scene 断开，当前项和待展示项被取消 |

失败项会移出队列，后续项可以继续。未设置错误回调时输出日志。失败/Scene 取消不会伪装成用户关闭，也不会调用 `didHidenBlock`；尚未完成的关闭 completion 在 Scene 取消时也不会调用。业务若需要重试，应在页面就绪或 Scene 恢复后重新提交，避免在失败回调里无条件立即重试。

## Demo 与测试

打开 `SwiftQueuePopUpDemo/SwiftQueuePopUpDemo.xcworkspace`，运行共享 Scheme `SwiftQueuePopUpDemo`。
Demo 提供三种弹窗模式；支持多窗口的设备可用“打开另一个窗口”检查队列隔离。

```sh
xcodebuild \
  -workspace SwiftQueuePopUpDemo/SwiftQueuePopUpDemo.xcworkspace \
  -scheme SwiftQueuePopUpDemo \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath .build/DerivedData \
  CODE_SIGNING_ALLOWED=NO test
```

Xcode 27 自带的 XCTest 运行库要求 iOS 17，因此仅测试 Target 设为 iOS 17；库和 Demo 仍为 iOS 15。

`SwiftQueuePopUpTests` 包含窗口归属、焦点恢复、连续抢占、同优先级 FIFO、重复入队/关闭、展示失败、Scene 断开清理及动画中关闭的回归测试。多 Scene 测试需要在 iPad 模拟器运行，在 iPhone 上跳过。

仍建议在宿主 App 真机检查：输入框/键盘、旋转和窗口缩放、系统弹窗与其他浮层叠加、自定义转场、后台启动和深链路由。

Apple 文档：[UIScene 生命周期迁移](https://developer.apple.com/documentation/uikit/transitioning-to-the-uikit-scene-based-life-cycle)。
