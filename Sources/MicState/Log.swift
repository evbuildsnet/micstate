import Foundation

/// Appends to ~/Library/Logs/MicState.log so device-switch issues can be inspected after the fact.
enum Log {
    private static let url = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/Logs/MicState.log")
    private static let stamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return f
    }()

    static func info(_ message: String) {
        let line = "\(stamp.string(from: Date())) \(message)\n"
        NSLog("MicState: %@", message)
        guard let data = line.data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: url)
        }
    }
}
