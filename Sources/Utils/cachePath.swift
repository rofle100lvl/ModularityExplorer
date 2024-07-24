import Foundation

public enum Constants {
    public static func cachePath() throws -> URL {
        let url = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        return url.appendingPathComponent("com.github.usegraph")
    }
}
