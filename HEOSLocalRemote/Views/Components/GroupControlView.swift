import SwiftUI

struct GroupControlView: View {
    @ObservedObject var repository: PlayerRepository
    let group: HEOSGroup

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label(group.name, systemImage: "speaker.wave.2.bubble.fill").font(.headline)
                Spacer()
                Button("Dela grupp", role: .destructive) { repository.ungroup(group) }
                    .font(.subheadline)
            }

            VolumeControl(
                volume: repository.groupVolumes[group.gid] ?? averageVolume,
                isMuted: repository.groupMutes[group.gid] ?? false,
                setVolume: { repository.setGroupVolume(gid: group.gid, level: $0) },
                toggleMute: { repository.toggleGroupMute(gid: group.gid) }
            )

            DisclosureGroup("Volym per rum") {
                VStack(spacing: 16) {
                    ForEach(group.players) { member in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(member.name).font(.subheadline.weight(.medium))
                            VolumeControl(
                                volume: repository.state(for: member.pid).volume,
                                isMuted: repository.state(for: member.pid).isMuted,
                                setVolume: { repository.setVolume(pid: member.pid, level: $0) },
                                toggleMute: { repository.toggleMute(pid: member.pid) }
                            )
                        }
                    }
                }
                .padding(.top, 10)
            }
        }
        .padding(18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private var averageVolume: Int {
        guard !group.players.isEmpty else { return 0 }
        return group.players.map { repository.state(for: $0.pid).volume }.reduce(0, +) / group.players.count
    }
}
