import Foundation

extension String {
    @inlinable
    var djb2: Int {
        unicodeScalars
            .map { $0.value }
            .reduce(5381) { ($0 << 5) &+ $0 &+ Int($1) }
    }

    @inlinable
    public var djb2Hex: String {
        String(format: "%02x", djb2)
    }
}
