// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "NusaMac",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "NusaMac", targets: ["NusaMac"])
    ],
    targets: [
        .executableTarget(
            name: "NusaMac",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("IOKit"),
                .linkedFramework("CoreWLAN"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("UserNotifications")
            ]
        )
    ]
)
