// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Span",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Span", targets: ["Span"])],
    targets: [
        .executableTarget(
            name: "Span",
            path: "Sources/Span",
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
