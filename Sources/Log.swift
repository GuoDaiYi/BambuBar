import Foundation

enum Log {
    static let path: String = {
        let dir = ("~/Library/Logs/BambuBar" as NSString).expandingTildeInPath
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        return dir + "/BambuBar.log"
    }()

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    static func write(_ message: String) {
        let line = "[\(formatter.string(from: Date()))] \(message)\n"
        print(line, terminator: "")
        guard let data = line.data(using: .utf8) else { return }
        let fm = FileManager.default
        if !fm.fileExists(atPath: path) {
            fm.createFile(atPath: path, contents: data)
            return
        }
        if let attrs = try? fm.attributesOfItem(atPath: path),
           let size = attrs[.size] as? Int, size > 2_000_000 {
            try? fm.removeItem(atPath: path)
            fm.createFile(atPath: path, contents: data)
            return
        }
        if let handle = FileHandle(forWritingAtPath: path) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        }
    }
}
