# UI parity audit — remaining interfaces

Comparison between the Android screens (`echo-music-reference/Echo-Music`) and the desktop ones. Every desktop screen was opened and captured at runtime in `docs/ui_parity_contact_sheet.png`.

| Interface | Android reference | Desktop | Status | Notes |
|---|---|---|---|---|
| Home | `ui/screens/HomeScreen.kt` | `screens/home/home_page.dart` | DONE | Customizable sections (favorites, playlists, feed, charts), chips, refresh |
| Player | `ui/screens/PlayerScreen.kt` + components | `screens/player/player_page.dart`, `widgets/*` | DONE | Play/pause, queue, lyrics, cast, sleep timer, EQ, 3 layouts |
| Library | `ui/screens/library/LibraryScreen.kt` (6 filters) | `screens/library/ytm_library_page.dart` | DONE | 6 filters in a single view: Playlists, Songs, Albums, Artists, Podcasts, Local |
| Playlist | `ui/screens/playlist/OnlinePlaylistScreen.kt` | `screens/detail/playlist_page.dart` | DONE | Header, Play/Shuffle, song menu, add/remove, queue = playlist |
| Search | `ui/screens/search/SearchScreen.kt` | `screens/search/search_page.dart` + cubit | DONE | Online + local search, results with real navigation |
| Cast | `ui/component/CastButton.kt`, `CastDevicePickerSheet.kt`, `CastSessionSheet.kt` | `screens/connect/cast_page.dart` + `cast_session_page.dart` | DONE* | Picker and session separate as on Android; direct CastV2 (mDNS + DIAL) instead of GMS |
| Explore | `ui/screens/ExploreScreen.kt` (navigation tab) | `screens/explore/explore_page.dart` (branch 2) | DONE | Fifth tab of the floating nav: Home, Search, Explore, Library, Settings |
| Podcast | `LibraryPodcastsScreen.kt` | `library_page.dart` tile + `chip_page.dart` (`/podcasts`) | DONE | Removed only from "More from mobile" on request; still in the library |

## Aligned labels

- `AI Hub` → `AI lyrics & translation` (Android `R.string.ai_lyrics_translation`).

## Declared differences (not applicable to desktop)

- Android "Supported Links" opens a system intent: explicit placeholder.
- Android Cast uses Google Play Services: desktop speaks CastV2 directly without GMS (same discovery, same picker, same session).
- The desktop "Linked devices" entry was removed from the Settings menu: Cast remains reachable from the player icon and from Account.
