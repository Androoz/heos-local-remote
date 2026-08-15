import XCTest
@testable import HEOSLocalRemote

@MainActor
final class PlayerRepositoryTests: XCTestCase {
    func testPlayersAreAddedAndStateUpdated() {
        let repository = PlayerRepository()
        let player = HEOSPlayer(pid: "10", name: "Kontor", model: nil, version: nil, ip: nil, network: nil, lineOut: nil)
        repository.apply(.players([player]))
        repository.apply(.state(pid: "10", .playing))
        repository.apply(.volume(pid: "10", level: 67, muted: true))
        XCTAssertEqual(repository.players, [player])
        XCTAssertEqual(repository.state(for: "10").playState, .playing)
        XCTAssertEqual(repository.state(for: "10").volume, 67)
        XCTAssertTrue(repository.state(for: "10").isMuted)
    }

    func testLoadingStateTracksPlayerRefresh() {
        let repository = PlayerRepository()
        repository.apply(.loadingPlayers(true))
        XCTAssertTrue(repository.isLoadingPlayers)
        repository.apply(.loadingPlayers(false))
        XCTAssertFalse(repository.isLoadingPlayers)
    }

    func testEventsForUnknownPlayerDoNotCrash() {
        let repository = PlayerRepository()
        repository.apply(.state(pid: "unknown", .paused))
        XCTAssertEqual(repository.state(for: "unknown").playState, .paused)
    }

    func testSelectionResetsWhenPlayerDisappears() {
        let repository = PlayerRepository()
        repository.apply(.players(MockData.players))
        repository.selectedPlayerID = MockData.players[0].pid
        repository.apply(.playerRemoved(MockData.players[0].pid))
        XCTAssertNil(repository.selectedPlayerID)
    }

    func testMediaAffectsOnlyMatchingPlayer() {
        let repository = PlayerRepository()
        repository.apply(.players(MockData.players))
        repository.apply(.media(pid: "2", NowPlaying(song: "Ny låt", artist: "Ny artist")))
        XCTAssertEqual(repository.state(for: "2").song, "Ny låt")
        XCTAssertNotEqual(repository.state(for: "1").song, "Ny låt")
    }

    func testGroupsAndGroupStateAreAssociatedWithPlayers() {
        let repository = PlayerRepository()
        repository.apply(.players(MockData.players))
        repository.apply(.groups(MockData.groups))
        repository.apply(.groupVolume(gid: "10", level: 44))
        repository.apply(.groupMute(gid: "10", muted: true))
        XCTAssertEqual(repository.group(for: "2")?.name, "Nedervåning")
        XCTAssertEqual(repository.groupVolumes["10"], 44)
        XCTAssertEqual(repository.groupMutes["10"], true)
    }

    func testUniformGroupVolumeSetsEveryMemberToSameLevel() {
        let repository = PlayerRepository()
        repository.apply(.players(MockData.players))
        let group = MockData.groups[0]
        repository.apply(.groups([group]))

        repository.setUniformGroupVolume(group, level: 37)

        XCTAssertEqual(repository.groupVolumes[group.gid], 37)
        XCTAssertEqual(repository.state(for: "1").volume, 37)
        XCTAssertEqual(repository.state(for: "2").volume, 37)
        XCTAssertNotEqual(repository.state(for: "3").volume, 37)
    }

    func testSoundbarWithEmptyPlayingMetadataFallsBackToTVSource() {
        let repository = PlayerRepository()
        repository.apply(.players(MockData.players))
        repository.apply(.state(pid: "2", .playing))
        repository.apply(.media(pid: "2", NowPlaying()))
        XCTAssertEqual(repository.state(for: "2").sourceKind, .television)
        XCTAssertEqual(repository.state(for: "2").displayTitle, "TV-ljud")
    }
}
