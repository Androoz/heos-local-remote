import XCTest
@testable import HEOSLocalRemote

final class HEOSCommandTests: XCTestCase {
    func testPathsAndParameters() {
        XCTAssertEqual(HEOSCommand.getPlayers.string, "heos://player/get_players")
        XCTAssertEqual(HEOSCommand.getPlayState(pid: "12").string, "heos://player/get_play_state?pid=12")
        XCTAssertEqual(HEOSCommand.setVolume(pid: "12", level: 150).string, "heos://player/set_volume?pid=12&level=100")
        XCTAssertEqual(HEOSCommand.setMute(pid: "12", muted: true).string, "heos://player/set_mute?pid=12&state=on")
        XCTAssertEqual(HEOSCommand.setPlayState(pid: "12", state: .stopped).string, "heos://player/set_play_state?pid=12&state=stop")
        XCTAssertEqual(HEOSCommand.registerForEvents.string, "heos://system/register_for_change_events?enable=on")
        XCTAssertEqual(HEOSCommand.heartBeat.string, "heos://system/heart_beat")
        XCTAssertEqual(HEOSCommand.getGroups.string, "heos://group/get_groups")
        XCTAssertEqual(HEOSCommand.setGroup(playerIDs: ["1", "2", "3"]).string, "heos://group/set_group?pid=1,2,3")
        XCTAssertEqual(HEOSCommand.setGroup(playerIDs: ["1"]).string, "heos://group/set_group?pid=1")
        XCTAssertEqual(HEOSCommand.setGroupVolume(gid: "7", level: -1).string, "heos://group/set_volume?gid=7&level=0")
        XCTAssertEqual(HEOSCommand.setGroupMute(gid: "7", muted: true).string, "heos://group/set_mute?gid=7&state=on")
    }

    func testPercentEncoding() {
        XCTAssertTrue(HEOSCommand.getVolume(pid: "room & one").string.contains("pid=room%20%26%20one"))
    }

    func testWireDataEndsWithCRLF() {
        XCTAssertEqual(String(data: HEOSCommand.next(pid: "1").wireData, encoding: .utf8), "heos://player/play_next?pid=1\r\n")
    }
}
