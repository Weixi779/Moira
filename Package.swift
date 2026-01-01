// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "Moira",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "Moira",
            targets: ["Moira"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.9.0")
    ],
    targets: [
        .target(
            name: "Moira",
            dependencies: [
                .product(name: "Alamofire", package: "Alamofire")
            ]
        ),
        .testTarget(
            name: "MoiraTests",
            dependencies: [
                "Moira"
            ]
        ),
    ]
)
