# UI parity audit — remaining interfaces

Confronto tra le schermate Android (`echo-music-reference/Echo-Music`) e quelle
desktop. Ogni schermata desktop è stata aperta e catturata a runtime in
`docs/ui_parity_contact_sheet.png`.

| Interfaccia | Android reference | Desktop | Stato | Note |
|---|---|---|---|---|
| Home | `ui/screens/HomeScreen.kt` | `screens/home/home_page.dart` | DONE | Sezioni personalizzabili (preferiti, playlist, feed, classifiche), chips, refresh |
| Player | `ui/screens/PlayerScreen.kt` + componenti | `screens/player/player_page.dart`, `widgets/*` | DONE | Play/pause, queue, lyrics, cast, sleep timer, EQ, 3 layout |
| Library | `ui/screens/library/LibraryScreen.kt` (6 filtri) | `screens/library/ytm_library_page.dart` | DONE | 6 filtri in un'unica vista: Playlist, Brani, Album, Artisti, Podcast, Local |
| Playlist | `ui/screens/playlist/OnlinePlaylistScreen.kt` | `screens/detail/playlist_page.dart` | DONE | Header, Play/Shuffle, menu brano, aggiungi/rimuovi, coda = playlist |
| Search | `ui/screens/search/SearchScreen.kt` | `screens/search/search_page.dart` + cubit | DONE | Ricerca online + locale, risultati con navigazione reale |
| Cast | `ui/component/CastButton.kt`, `CastDevicePickerSheet.kt`, `CastSessionSheet.kt` | `screens/connect/cast_page.dart` + `cast_session_page.dart` | DONE* | Picker e sessione separati come Android; protocollo CastV2 diretto (mDNS + DIAL) invece di GMS |
| Explore | `ui/screens/ExploreScreen.kt` (tab di navigazione) | `screens/explore/explore_page.dart` (branch 2) | DONE | Quinta tab della floating nav: Home, Search, Esplora, Libreria, Impostazioni |
| Podcast | `LibraryPodcastsScreen.kt` | `library_page.dart` tile + `chip_page.dart` (`/podcasts`) | DONE | Rimosso solo da "More from mobile" su richiesta; resta nella libreria |

## Etichette allineate
- `AI Hub` → `AI lyrics & translation` (Android `R.string.ai_lyrics_translation`).

## Differenze dichiarate (non applicabili al desktop)
- Android "Supported Links" apre un intent di sistema: placeholder esplicito.
- Android Cast usa Google Play Services: il desktop parla CastV2 direttamente,
  senza GMS (stessa scoperta, stesso picker e stessa sessione).
- La voce desktop "Linked devices" è stata rimossa dal menu Impostazioni: il
  Cast resta raggiungibile dall'icona nel player e da Account.
