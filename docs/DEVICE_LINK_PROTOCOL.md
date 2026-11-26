# Mobile ↔ Desktop linking protocol

Linking uses the YouTube Music playback state: the desktop announces its signed-in account and current playback state on the LAN UDP discovery channel, and any peer on the same Wi-Fi with the same account fingerprint links automatically.

## Desktop side (implemented)

- `lib/services/remote_control_service.dart` (port 8899 HTTP + port 8898 UDP):
  - Every ~2s it broadcasts a `DeviceLinkAnnounce` datagram:
    `{proto: "echo-desktop-link", id, name, account, playing, songId, title, updatedAt}`
    to `255.255.255.255:8898` and the LAN host — the announce *is* the YT Music
    playback state of the desktop.
  - `probePlaying` ("ECHO_MUSIC_PLAYING") replies with the live playback state.
  - The existing `discoveryProbe` ("ECHO_MUSIC_DISCOVER") reply now also carries
    `account` (fingerprint), `deviceId`, `announceProto`.
  - `deviceLinkAnnounces` / `linkedByAccount` expose received announces
    (`RemoteControlService.deviceLinkId` = stable per-install desktop id).
  - Desktop page `/device_link` lists linked devices (name, account fp, playing state).
- `lib/services/device_link_announcement.dart`: `accountFingerprint()` (SHA-256 of
  the signed-in cookies — stable per account), `DeviceLinkAnnounce` (JSON over UDP),
  `playingStateJson()`.
- Legacy 6-digit-code pairing (`DeviceLinkService`, port 8901) was removed: linking
  is now entirely via the YT Music playback-state announces above.

## Linking rule (matches YouTube Music UX)

1. Both devices are signed in as the **same Google/YouTube account**
   (cookies shared; desktop injects them — see GoogleLoginService).
2. The desktop announces its `account` fingerprint + name + playing state.
3. A peer sees an announce with the **same account fingerprint** → **linked**.
4. To see the other device's playback, the peer either reads its own
   `deviceLinkAnnounces`, or sends a `ECHO_MUSIC_PLAYING` probe to the desktop's
   discovery port and reads the JSON response (`playing`, `songId`, `title`).

## Mobile client (implement with the same rules)

- On device: if any announce on `255.255.255.255:8898` has `account == yours`
  (compute the fingerprint the same way: SHA-256 of sorted `k=v` cookie pairs of
  the `InnerTubeCookie`), the devices are linked — show/pair it with the desktop
  by `id`/`name`.
- While linked, poll the desktop on port 8899 (`/status` or `ECHO_MUSIC_PLAYING`)
  to show the real playback state (the YouTube Music state-of-playback).
