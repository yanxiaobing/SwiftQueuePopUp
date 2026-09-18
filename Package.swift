// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "SwiftQueuePopUp",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "SwiftQueuePopUp", targets: ["SwiftQueuePopUp"])
    ],
    targets: [
        .target(name: "SwiftQueuePopUp", path: "SwiftQueuePopUp")
    ],
    swiftLanguageVersions: [.v5]
)
