# HEOS Remote

HEOS Remote is a native iPhone and iPad app for local control of Denon HEOS players, including older first-generation devices. It connects directly to the HEOS Command Line Interface over TCP port 1255. No HEOS account, cloud service, or external backend is used.

> [!IMPORTANT]
> This is an independent, unofficial hobby project. It is not affiliated with, endorsed by, or supported by Denon, HEOS, or their respective owners.

## Project status

The project is published as a practical reference for people working with local HEOS control. It is maintained when time and interest permit. Issues and pull requests are welcome, but responses, fixes, releases, and support are not guaranteed.

## Features

- Automatic SSDP discovery of HEOS devices on the local network
- Manual fallback connection using an IPv4 address, IPv6 address, or local hostname
- Automatic reconnection to the last saved controller address
- Player discovery through `player/get_players`
- Source-aware Now Playing display for music, radio, TV/HDMI, external inputs, and Bluetooth
- Play/pause, next, previous, volume, and mute controls when supported by the active source
- Create, modify, and dissolve speaker groups
- Group volume, group mute, and individual room volume within a group
- Quick play/pause, mute, and volume controls in the Rooms view
- Group cards containing every room name
- Live updates through HEOS change events
- Robust buffering of fragmented and combined TCP messages
- Heartbeats, bounded reconnection with increasing delays, and refresh when the app becomes active
- Swedish and English interfaces that follow the device language
- Localized errors and local-network permission guidance
- Mock data for music, TV audio, and groups in SwiftUI previews

## Architecture

`HEOSConnection` is an actor around a long-lived `NWConnection`. `HEOSMessageParser` splits the stream on LF or CRLF while retaining incomplete lines. `HEOSClient` correlates normal responses with sent commands through the HEOS response's `command` field and handles asynchronous events separately. `PlayerRepository` runs on the main actor and is the single source of player, playback, connection, and error state. SwiftUI views and small view models sit on top of the repository.

Payloads are first decoded into the type-safe `JSONValue` enum and then into the appropriate model, such as `HEOSPlayer` or `NowPlaying`.

## Requirements

- A current stable version of Xcode
- iOS or iPadOS 17 or later
- A HEOS player on the same local network for physical-device testing

## Build and test

1. Open `HEOSLocalRemote.xcodeproj` in Xcode.
2. Select the **HEOSLocalRemote** scheme.
3. Select an iPhone or iPad simulator and choose Run, or select a physical device.
4. Run the unit tests with **Product > Test** (`Command-U`).

Command-line example:

```sh
xcodebuild -project HEOSLocalRemote.xcodeproj -scheme HEOSLocalRemote \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

For a physical device, select your own development team in Xcode. Automatic SSDP discovery uses the `com.apple.developer.networking.multicast` entitlement. Apple must approve this capability for the team and App ID before it can be included in a signed device or TestFlight build. Manual address entry remains available when multicast discovery is unavailable.

## Test with a physical HEOS device

The iPhone or iPad and the HEOS player must be connected to the same local network.

1. Launch the app and allow local-network access.
2. Let the app discover the HEOS system automatically. If discovery does not find a device, enter the IP address or hostname of any HEOS player manually.
3. From a Mac on the same network, you can confirm that the HEOS CLI port responds:

   ```sh
   nc -v 192.168.1.50 1255
   ```

4. Once connected, enter the following command and press Return. The command must end with a newline:

   ```text
   heos://player/get_players
   ```

   A JSON response confirms that CLI communication works.
5. Install the app on a physical iPhone or iPad from Xcode and verify that every player appears.
6. Open an older or first-generation player and verify play/pause, next/previous, mute, and volume.
7. Change playback or volume in the official HEOS app and verify that HEOS Remote updates.
8. Temporarily disable Wi-Fi, return to the app, and use **Try Again** to verify reconnection.
9. Create a group with two rooms, change the group volume, and dissolve the group.

The controller address can be changed at any time from **More > Change HEOS Address** in the Rooms view.

HEOS HomeCinema and HEOS Bar devices can return `eid=7` when TV audio or an external input is active. Stop TV audio or enable **Group TV Sound** in the soundbar settings in the official HEOS app before creating the group.

The room from which the group editor was opened becomes the group leader. When a normal music player is the leader, TV or external audio on selected soundbar members is stopped after a one-time confirmation. When the editor is opened from a soundbar, its TV or HDMI source is retained and the soundbar becomes the leader; **Group TV Sound** must then be enabled on the device.

If local-network access was denied, enable it under **Settings > HEOS Remote > Local Network**.

Private TestFlight distribution is described in [TESTFLIGHT.md](TESTFLIGHT.md). Uploading a TestFlight build does not publish the app on the App Store.

## Implemented HEOS commands

- `player/get_players`
- `player/get_play_state`
- `player/get_now_playing_media`
- `player/get_volume` and `player/set_volume`
- `player/get_mute` and `player/set_mute`
- `player/set_play_state`
- `player/play_next` and `player/play_previous`
- `system/register_for_change_events`
- `system/heart_beat`
- `group/get_groups` and `group/set_group`
- `group/get_volume` and `group/set_volume`
- `group/get_mute` and `group/set_mute`

## Known limitations and troubleshooting

- Port 1256 (secure CLI), queue management, favorites, repeat, and shuffle do not have a user interface in this app.
- SSDP requires Apple's Multicast Networking approval and a provisioning profile containing the entitlement.
- iOS may suspend the TCP connection while the app is in the background. The app checks and refreshes the connection when it becomes active again rather than using aggressive background execution.
- TV/HDMI and other external sources often provide no track metadata. The app displays the source type and an appropriate placeholder instead.
- Artwork is shown only when HEOS supplies a URL that iOS can load.
- If the connection fails, check the controller address, Wi-Fi network, guest-network or client-isolation settings, local-network permission, and the `nc` test above.

See [docs/ROADMAP.md](docs/ROADMAP.md) for possible future work.

## License

The source code is available under the [MIT License](LICENSE).

HEOS and Denon names and trademarks belong to their respective owners. Use of those names in this repository is solely to describe compatibility.
