import Foundation

struct HEOSMessageParser: Sendable {
    private var buffer = Data()
    private(set) var invalidLineCount = 0

    mutating func append(_ data: Data) -> [HEOSResponse] {
        buffer.append(data)
        var responses: [HEOSResponse] = []

        while let newline = buffer.firstIndex(of: 0x0A) {
            var line = buffer[..<newline]
            buffer.removeSubrange(...newline)
            while let last = line.last, Self.ignorableBytes.contains(last) { line = line.dropLast() }
            while let first = line.first, Self.ignorableBytes.contains(first) { line = line.dropFirst() }
            guard !line.isEmpty else { continue }
            do {
                responses.append(try JSONDecoder().decode(HEOSResponse.self, from: Data(line)))
            } catch {
                invalidLineCount += 1
                HEOSLogger.parsing.error("Ignorerade ogiltig JSON-rad: \(error.localizedDescription, privacy: .public)")
            }
        }
        return responses
    }

    private static let ignorableBytes: Set<UInt8> = [0x00, 0x09, 0x0D, 0x20]

    mutating func reset() {
        buffer.removeAll(keepingCapacity: true)
        invalidLineCount = 0
    }
}
