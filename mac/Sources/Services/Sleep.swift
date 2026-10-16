import Foundation

/// Puts the Mac to sleep with `pmset sleepnow`, which needs no root or extra permission.
enum SystemSleep {
    static func sleepNow() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = ["sleepnow"]
        try? process.run()
    }
}
