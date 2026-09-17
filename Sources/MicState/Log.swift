import Foundation

/// Appends to ~/Library/Logs/MicState.log so device-switch issues can be inspected after the fact.
enum Log {
    private static let path = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/Logs/MicState.log").path
    private static let queue = DispatchQueue(label: "net.evbuilds.micstate.log")
    private static let stamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    static func info(_ message: String) {
        let line = "\(stamp.string(from: Date())) \(message)\n"
        NSLog("MicState: %@", message)
        queue.async {
            let fd = open(path, O_WRONLY | O_APPEND | O_CREAT, 0o644)
            guard fd >= 0 else { return }
            line.withCString { _ = write(fd, $0, strlen($0)) }
            close(fd)
        }
    }
}
