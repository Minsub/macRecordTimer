// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RecordTimer",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "RecordTimer", targets: ["RecordTimer"])],
    targets: [.executableTarget(name: "RecordTimer")]
)
