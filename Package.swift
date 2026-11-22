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
                "Assets.xcassets",
                "Resources",
                "Utilities",
                "ViewModels",
                "Views",
                "Services/NotificationService.swift"
            ],
            sources: [
                "Models/Reminder.swift",
                "Models/Completion.swift",
                "Models/BreakActivity.swift",
                "Models/BreakSession.swift",
                "Models/Medicine.swift",
                "Services/BackupCodec.swift",
                "Services/MedicineSchedule.swift",
                "Services/MedicineStore.swift",
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
