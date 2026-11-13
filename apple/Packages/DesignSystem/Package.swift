// swift-tools-version: 6.2
// DesignSystem — theme (JSON), token màu, lớp Liquid Glass, component dùng chung cho app Mac + iOS.
// Phần mô hình theme (Theme.swift) là Foundation thuần để test chạy được trên Linux;
// mọi file dùng SwiftUI bọc trong `#if canImport(SwiftUI)`.
import PackageDescription

let package = Package(
    name: "DesignSystem",
    platforms: [.macOS(.v26), .iOS(.v26)],
    products: [
        .library(name: "DesignSystem", targets: ["DesignSystem"]),
    ],
    targets: [
        .target(
            name: "DesignSystem",
            resources: [.copy("Resources/Themes")]
        ),
        .testTarget(name: "DesignSystemTests", dependencies: ["DesignSystem"]),
    ]
)
