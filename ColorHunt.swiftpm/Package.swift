// swift-tools-version: 5.6

// Color Hunt — 小学3年生 外国語活動用 App Playground
//
// Swift Playgrounds (iPad) と Xcode の両方で開けます。
// 注意: Swift Playgrounds の「App Settings」を UI から変更すると、
//       このファイルが自動生成で上書きされることがあります。
//       その場合は exclude: ["README.md"] が消えることがありますが、
//       ビルドには影響しません（警告が出るだけです）。

import PackageDescription
import AppleProductTypes

let package = Package(
    name: "ColorHunt",
    platforms: [
        .iOS("16.0")
    ],
    products: [
        .iOSApplication(
            name: "Color Hunt",
            targets: ["AppModule"],
            bundleIdentifier: "com.example.colorhunt",
            displayVersion: "1.0",
            bundleVersion: "1",
            accentColor: .presetColor(.red),
            supportedDeviceFamilies: [
                .pad,
                .phone
            ],
            supportedInterfaceOrientations: [
                .portrait,
                .landscapeRight,
                .landscapeLeft,
                .portraitUpsideDown(.when(deviceFamilies: [.pad]))
            ],
            capabilities: [
                .camera(purposeString: "いろをさがすために、カメラをつかいます。")
            ]
        )
    ],
    targets: [
        .executableTarget(
            name: "AppModule",
            path: ".",
            exclude: ["README.md"]
        )
    ]
)
