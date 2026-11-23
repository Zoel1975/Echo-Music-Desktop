# Piano per parità Android → Desktop ≥90%

Obiettivo misurabile: 36 dei 40 elementi della matrice qui sotto devono essere
`DONE` con codice reale e test. Stato iniziale (audit 2026-11-23): ~70-75%.

## Fase A — etichette e bug evidenti (1 giorno)
- [ ] Rimuovere "coming soon" da schermate reali (Explore, Library podcast, Player settings)
- [ ] Shuffle nel player full: chiamare `setShuffleModeEnabled`
- [ ] Test di regressione sulle etichette

## Fase B — identità visiva (1-2 settimane)
- [ ] Bundle dei font Android (Google Sans Flex / Outfit / Plus Jakarta / BBH Bartle)
- [ ] Unificare i 3 sistemi tipografici in `themes/typography.dart`
- [ ] `EchoGlass` (BackdropFilter + tint 0.4 + highlight + shadow) usato da card/nav/player
- [ ] Tipografia selezionabile dalle impostazioni

## Fase C — player (1-2 settimane)
- [ ] 7 background player come Android (DEFAULT, GRADIENT, BLUR, GLOW_ANIMATED, APPLE_MUSIC, LIVE_MESH, LIQUID_GLASS)
- [ ] Collegare il setting `playerBackgroundStyle` al player
- [ ] Wavy / Squiggly slider (CustomPainter)
- [ ] HeartBurst sull'anima preferiti
- [ ] Marquee in mini-player, queue, playlist, ricerca

## Fase D — micro-effetti e schermate firma (2-3 settimane)
- [ ] Shimmer host riutilizzabile (placeholder scheletri)
- [ ] Wrapped: slide animate con spring, meter, equalizzatore
- [ ] EQ circolare Canvas
- [ ] Ambient con palette estratta dall'artwork

## Fase E — funzioni mancanti (2-3 settimane)
- [ ] Music Flow: collegare i 7 toggle al feed
- [ ] Wiring dei toggle impostazioni top (tema/AMOLED, glass, player colors, lyrics animation)
- [ ] Export: stream sorgente + copertina MP3
- [ ] Commenti (endpoint InnerTube)
- [ ] Riconoscimento brani: resta placeholder dichiarato (non portable)

## Fase F — verifica
- [ ] `flutter analyze` 0 errori, `flutter test` verde, build release, installer
- [ ] Aggiornare matrice con conteggio DONE e percentuale

## Non portable (esclusi dal denominatore)
Widget Android, notifica Media3, QS tile, haptics, ringtones, USB bit-perfect,
Material You dal wallpaper, RenderEffect con rifrazione reale.
