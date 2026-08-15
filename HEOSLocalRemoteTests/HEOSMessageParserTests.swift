import XCTest
@testable import HEOSLocalRemote

final class HEOSMessageParserTests: XCTestCase {
    private let first = #"{"heos":{"command":"player/get_play_state","result":"success","message":"pid=1&state=play"}}"#
    private let second = #"{"heos":{"command":"player/get_volume","result":"success","message":"pid=1&level=30"}}"#

    func testCompleteObjectWithCRLF() {
        var parser = HEOSMessageParser()
        let values = parser.append(Data((first + "\r\n").utf8))
        XCTAssertEqual(values.count, 1)
        XCTAssertEqual(values.first?.heos.command, "player/get_play_state")
    }

    func testSplitObjectAcrossPackets() {
        var parser = HEOSMessageParser()
        let bytes = Array((first + "\n").utf8)
        XCTAssertTrue(parser.append(Data(bytes.prefix(20))).isEmpty)
        XCTAssertEqual(parser.append(Data(bytes.dropFirst(20))).count, 1)
    }

    func testSeveralObjectsLFAndEmptyLines() {
        var parser = HEOSMessageParser()
        let values = parser.append(Data((first + "\n\n" + second + "\n").utf8))
        XCTAssertEqual(values.map(\.heos.command), ["player/get_play_state", "player/get_volume"])
    }

    func testWhitespaceOnlyAndRepeatedCarriageReturnsAreIgnored() {
        var parser = HEOSMessageParser()
        let data = Data(("\r\r\n   \r\n\t\r\n\0\r\n" + first + "\r\r\n").utf8)
        let values = parser.append(data)
        XCTAssertEqual(values.map(\.heos.command), ["player/get_play_state"])
        XCTAssertEqual(parser.invalidLineCount, 0)
    }

    func testInvalidJSONDoesNotBlockFollowingObject() {
        var parser = HEOSMessageParser()
        let values = parser.append(Data(("not-json\n" + second + "\n").utf8))
        XCTAssertEqual(values.count, 1)
        XCTAssertEqual(parser.invalidLineCount, 1)
    }
}
