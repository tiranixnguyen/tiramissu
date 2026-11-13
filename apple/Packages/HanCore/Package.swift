// swift-tools-version: 6.2
// HanCore — logic thuần của Tiramissu: mô hình dữ liệu, StudyEngine, lịch ôn, nhập JSON, đồng bộ.
// KHÔNG import SwiftUI/AppKit/UIKit để `swift test` chạy được cả trên Linux.
import PackageDescription

let package = Package(
    name: "HanCore",
    platforms: [.macOS(.v26), .iOS(.v26)],
    products: [
        .library(name: "HanCore", targets: ["HanCore"]),
    ],
    targets: [
        .target(name: "HanCore"),
        .testTarget(name: "HanCoreTests", dependencies: ["HanCore"], resources: [.copy("Resources")]),
    ]
)
