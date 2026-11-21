# UI parity audit — remaining interfaces

Confronto tra le schermate Android (`echo-music-reference/Echo-Music`) e quelle
desktop. Ogni schermata desktop è stata aperta e catturata a runtime in
`docs/ui_parity_contact_sheet.png`.

| Interfaccia | Android reference | Desktop | Stato | Note |
|---|---|---|---|---|
| Home | `ui/screens/HomeScreen.kt` | `screens/home/home_page.dart` | DONE | Sezioni personalizzabili (preferiti, playlist, feed, classifiche), chips, refresh |
| Player | `ui/screens/PlayerScreen.kt` + componenti | `screens/player/player_page.dart`, `widgets/*` | DONE | Play/pause, queue, lyrics, cast, sleep timer, EQ, 3 layout |
| Library | `ui/screens/library/LibraryScreen.kt` (6 filtri) | `screens/library/ytm_library_page.dart` + `library_page.dart` | DONE* | 4 tab YTM + libreria locale con Songs/Albums/Artists/Podcasts; filtro "Local" è schermata separata |
| Playlist | `ui/screens/playlist/OnlinePlaylistScreen.kt` | `screens/detail/playlist_page.dart` | DONE | Header, Play/Shuffle, menu brano, aggiungi/rimuovi, coda = playlist |
| Search | `ui/screens/search/SearchScreen.kt` | `screens/search/search_page.dart` + cubit | DONE | Ricerca online + locale, risultati con navigazione reale |
| Cast | `ui/component/CastButton.kt`, `CastDevicePickerSheet.kt`, `CastSessionSheet.kt` | `screens/connect/cast_page.dart`, `services/cast/*` | DONE* | Stesso protocollo CastV2 (mDNS + DIAL); picker e sessione in un'unica pagina; nessun GMS su desktop |
| Explore | `ui/screens/ExploreScreen.kt` (tab di navigazione) | `screens/explore/explore_page.dart` raggiungibile da Home/Impostazioni | PLACEHOLDER di layout | Shell desktop ha 4 branch (Home/Search/Library/Settings): Explore non è una quinta tab fissa |
| Podcast | `LibraryPodcastsScreen.kt` | `library_page.dart` tile + `chip_page.dart` (`/podcasts`) | DONE | Rimosso solo da "More from mobile" su richiesta; resta nella libreria |

## Etichette allineate
- `AI Hub` → `AI lyrics & translation` (Android `R.string.ai_lyrics_translation`).

## Differenze dichiarate (non applicabili al desktop)
- Android "Supported Links" apre un intent di sistema: placeholder esplicito.
- Android Cast usa Google Play Services: il desktop parla CastV2 direttamente,
  senza GMS (stessa scoperta e stesso controllo dispositivi).
- Android ha 5 tab di navigazione; il desktop ne mantiene 4 per decisione di design.
