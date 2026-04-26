// swift-tools-version:5.9

import PackageDescription

let package = Package(
    name: "Moira",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "Moira",
            targets: ["Moira"]
        ),
        .library(
            name: "MoiraAlamofire",
            targets: ["MoiraAlamofire"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.9.0"),
    ],
    targets: [
        .target(
            name: "Moira",
            dependencies: []
        ),
        .target(
            name: "MoiraAlamofire",
            dependencies: [
                "Moira",
                .product(name: "Alamofire", package: "Alamofire"),
            ]
        ),
        .testTarget(
            name: "MoiraTests",
            dependencies: [
                "Moira",
                "MoiraAlamofire",
            ]
        ),
    ]
)
