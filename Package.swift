// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EyeRestLogic",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "EyeRestLogic", targets: ["EyeRestLogic"])
    ],
    targets: [
        .target(
            name: "EyeRestLogic",
            path: "EyeRest",
            exclude: [
                "EyeRestApp.swift",
                "EyeRest.entitlements",
                "Info.plist",
                "Resources",
                "Utilities",
                "ViewModels",
                "Views",
                "Services/NotificationService.swift"
            ],
            sources: [
                "Models/Reminder.swift",
                "Models/Completion.swift",
                "Models/BreakSession.swift",
                "Services/BackupCodec.swift",
                "Services/NotificationPlanner.swift",
                "Services/PersistenceService.swift",
                "Services/ScheduleRules.swift"
            ]
        ),
        .testTarget(
            name: "EyeRestLogicTests",
            dependencies: ["EyeRestLogic"],
            path: "Tests/EyeRestLogicTests"
        )
    ]
)
