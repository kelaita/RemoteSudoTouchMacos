// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "RemoteSudoTouchMacos",
  platforms: [
    .macOS(.v14),
  ],
  products: [
    .library(name: "RemoteSudoTouchCore", targets: ["RemoteSudoTouchCore"]),
    .executable(name: "remote-sudo-touch-macos", targets: ["remote-sudo-touch-macos"]),
    .executable(name: "rsudo", targets: ["rsudo"]),
  ],
  targets: [
    .target(
      name: "RemoteSudoTouchCore"
    ),
    .executableTarget(
      name: "remote-sudo-touch-macos",
      dependencies: ["RemoteSudoTouchCore"]
    ),
    .executableTarget(
      name: "rsudo",
      dependencies: ["RemoteSudoTouchCore"]
    ),
  ]
)
