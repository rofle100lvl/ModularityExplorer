import Combine
import Foundation

public final class System {
    public static let shared = System()

    private init() {}

    public func run(_ cmd: String) -> String {
        let pipe = Pipe()
        let process = Process()
        process.launchPath = "/bin/sh"
        process.arguments = ["-c", String(format: "%@", cmd)]
        process.standardOutput = pipe
        let fileHandle = pipe.fileHandleForReading
        process.launch()
        return String(data: fileHandle.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
}

enum ProcessError: Error {
    case system(Error)
    case terminated(code: Int)
}
