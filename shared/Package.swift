// swift-tools-version: 5.9
import PackageDescription

// HockeyContract — the Swift binding of contract/openapi.yaml.
//
// The iOS and watch apps both depend on this package so the contract-mirroring
// models and JSON coding live in exactly one place (no per-app drift). Owned by
// shared-agent; changes here follow a contract change, never lead one.
let package = Package(
    name: "HockeyContract",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10),
    ],
    products: [
        .library(name: "HockeyContract", targets: ["HockeyContract"]),
    ],
    targets: [
        .target(name: "HockeyContract"),
        .testTarget(name: "HockeyContractTests", dependencies: ["HockeyContract"]),
    ]
)
