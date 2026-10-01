// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WebBridge-Kit",
    products: [
        .library(name: "WBKCore", targets: ["WBKCore"]),
        .library(name: "WBKBridge", targets: ["WBKBridge"]),
        .library(name: "WBKAuth", targets: ["WBKAuth"]),
        .library(name: "WBKCapabilities", targets: ["WBKCapabilities"]),
        .library(name: "WBKSecurity", targets: ["WBKSecurity"]),
        .library(name: "WebBridge-Kit", targets: ["WBKCore", "WBKBridge", "WBKAuth", "WBKCapabilities", "WBKSecurity"])
    ],
    targets: [
        // MARK: - Core: envelope, status codes, module registry
        // No dependency on any other target. Everything else depends on this.
        .target(
            name: "WBKCore",
            dependencies: []
        ),
        .testTarget(
            name: "WBKCoreTests",
            dependencies: ["WBKCore"]
        ),

        // MARK: - Bridge: WKWebView container + WKScriptMessageHandler transport
        // Depends on Core only. Must NOT depend on Auth, Capabilities, or Security directly —
        // those are wired in by the composition root (the Example app), not by Bridge itself.
        .target(
            name: "WBKBridge",
            dependencies: ["WBKCore"]
        ),
        .testTarget(
            name: "WBKBridgeTests",
            dependencies: ["WBKBridge"]
        ),

        // MARK: - Auth: PKCE / GrabID-style login flow
        // Depends on Core only (for envelope/error types). No dependency on Bridge.
        .target(
            name: "WBKAuth",
            dependencies: ["WBKCore"]
        ),
        .testTarget(
            name: "WBKAuthTests",
            dependencies: ["WBKAuth"]
        ),

        // MARK: - Capabilities: Device, Storage, Location modules
        // Depends on Core + Security (needs scope gate) + Bridge (needs module registry protocol).
        .target(
            name: "WBKCapabilities",
            dependencies: ["WBKCore", "WBKSecurity", "WBKBridge"]
        ),
        .testTarget(
            name: "WBKCapabilitiesTests",
            dependencies: ["WBKCapabilities"]
        ),

        
        // MARK: - Security: scope gate, min-host-version gate
        // Depends on Core only. Capabilities and Bridge call into Security; Security calls into nothing.
        .target(
            name: "WBKSecurity",
            dependencies: ["WBKCore"]
        ),
        .testTarget(
            name: "WBKSecurityTests",
            dependencies: ["WBKSecurity"]
        )
    ]
)
