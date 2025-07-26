# Adding Typesense Swift SDK to Your Project

## Using Swift Package Manager

1. In Xcode, select File > Swift Packages > Add Package Dependency
2. Enter the repository URL: https://github.com/typesense/typesense-swift.git
3. Select the version you want to use (latest stable is recommended)
4. Add the package to your target

## Manual Installation

If you prefer to add it manually to your Package.swift:

```swift
dependencies: [
    .package(url: "https://github.com/typesense/typesense-swift.git", from: "0.1.0")
],
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["Typesense"]),
]
```
