import Foundation

/// Production-safe debug print - only outputs in DEBUG builds
/// Use this instead of print() for debug logging
@inline(__always)
func debugLog(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
    let output = items.map { "\($0)" }.joined(separator: separator)
    print(output, terminator: terminator)
    #endif
}

/// Structured logger for categorized logging (only in DEBUG builds)
struct Logger {
    
    enum Level: String {
        case debug = "🔍"
        case info = "ℹ️"
        case warning = "⚠️"
        case error = "❌"
        case success = "✅"
    }
    
    @inline(__always)
    static func log(_ message: String, level: Level = .debug) {
        #if DEBUG
        print("\(level.rawValue) \(message)")
        #endif
    }
    
    @inline(__always) static func debug(_ message: String) { log(message, level: .debug) }
    @inline(__always) static func info(_ message: String) { log(message, level: .info) }
    @inline(__always) static func warning(_ message: String) { log(message, level: .warning) }
    @inline(__always) static func error(_ message: String) { log(message, level: .error) }
    @inline(__always) static func success(_ message: String) { log(message, level: .success) }
}
