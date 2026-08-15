import XCTest
@testable import HEOSLocalRemote

final class HEOSResponseTests: XCTestCase {
    func testGetPlayersFixture() throws {
        let response = try decode(#"{"heos":{"command":"player/get_players","result":"success","message":""},"payload":[{"name":"Kök","pid":"1","model":"HEOS 3","version":"3.34","ip":"192.168.1.9","network":"wired","lineout":"0"}]}"#)
        XCTAssertEqual(response.payload?.arrayValue?.first?.objectValue?.string("name"), "Kök")
    }

    func testOlderPlayerPayloadAcceptsNumericFields() throws {
        let data = Data(#"{"name":"Äldre HEOS","pid":1,"model":"HEOS 3","version":3.1,"ip":"192.168.1.9","network":"wired","lineout":0}"#.utf8)
        let player = try JSONDecoder().decode(HEOSPlayer.self, from: data)
        XCTAssertEqual(player.pid, "1")
        XCTAssertEqual(player.lineOut, "0")
    }

    func testStatusFixtures() throws {
        let cases = [
            (#"{"heos":{"command":"player/get_play_state","result":"success","message":"pid=1&state=play"}}"#, "state", "play"),
            (#"{"heos":{"command":"player/get_volume","result":"success","message":"pid=1&level=42"}}"#, "level", "42"),
            (#"{"heos":{"command":"player/get_mute","result":"success","message":"pid=1&state=off"}}"#, "state", "off")
        ]
        for (fixture, key, expected) in cases { XCTAssertEqual(try decode(fixture).heos.messageParameters[key], expected) }
    }

    func testNowPlayingFixtureDecodesTypedPayload() throws {
        let response = try decode(#"{"heos":{"command":"player/get_now_playing_media","result":"success","message":"pid=1"},"payload":{"type":"song","song":"Track","artist":"Artist","album":"Album","image_url":"https://example.test/a.jpg","album_id":"2","mid":"3","qid":"4","sid":"5"}}"#)
        let data = try JSONEncoder().encode(response.payload)
        let media = try JSONDecoder().decode(NowPlaying.self, from: data)
        XCTAssertEqual(media.song, "Track")
        XCTAssertEqual(media.sourceID, "5")
    }

    func testNowPlayingAcceptsNumericIdentifiersAndRecognizesTVInput() throws {
        let data = Data(#"{"type":"HDMI ARC","song":"TV Audio","album_id":2,"mid":3,"qid":4,"sid":5}"#.utf8)
        let media = try JSONDecoder().decode(NowPlaying.self, from: data)
        XCTAssertEqual(media.sourceID, "5")
        XCTAssertEqual(media.albumID, "2")
        XCTAssertEqual(media.sourceKind, .television)
        XCTAssertTrue(media.sourceKind.isExternalInput)
        XCTAssertFalse(media.sourceKind.supportsSkipping)
    }

    func testOlderGroupPayloadAcceptsNumericIdentifiers() throws {
        let data = Data(#"{"name":"Nedervåning","gid":10,"players":[{"name":"Kök","pid":1,"role":"leader"},{"name":"TV-rum","pid":"2","role":"member"}]}"#.utf8)
        let group = try JSONDecoder().decode(HEOSGroup.self, from: data)
        XCTAssertEqual(group.gid, "10")
        XCTAssertEqual(group.leaderPID, "1")
        XCTAssertEqual(group.playerIDs, ["1", "2"])
        XCTAssertEqual(group.displayName, "Kök + TV-rum")
    }


    func testHEOSCommandErrorExtractsErrorID() {
        let error = HEOSCommandError.failed("eid=7&text=Command not executed&pid=-1,-2")
        XCTAssertEqual(error.heosErrorID, 7)
    }

    func testEventFixtures() throws {
        let fixtures = [
            (#"{"heos":{"command":"event/player_state_changed","result":"success","message":"pid=1&state=pause"}}"#, "1"),
            (#"{"heos":{"command":"event/player_volume_changed","result":"success","message":"pid=2&level=51&mute=on"}}"#, "2"),
            (#"{"heos":{"command":"event/player_now_playing_changed","result":"success","message":"pid=3"}}"#, "3")
        ]
        for (fixture, pid) in fixtures { XCTAssertEqual(try decode(fixture).heos.messageParameters["pid"], pid) }
    }

    private func decode(_ string: String) throws -> HEOSResponse {
        try JSONDecoder().decode(HEOSResponse.self, from: Data(string.utf8))
    }
}
