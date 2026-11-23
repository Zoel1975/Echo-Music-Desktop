# Piano per parità Android → Desktop ≥90%

Obiettivo misurabile: 36 dei 40 elementi della matrice qui sotto devono essere
`DONE` con codice reale e test. Stato iniziale (audit 2026-11-23): ~70-75%.

## Fase A — etichette e bug evidenti (1 giorno)
- [x] Rimuovere "coming soon" da schermate reali (Explore, Library podcast, Player settings)
- [x] Shuffle nel player full: chiamare `setShuffleModeEnabled`
- [x] Test di regressione sulle etichette

## Fase B — identità visiva (1-2 settimane)
- [x] Bundle dei font Android (Google Sans Flex / Outfit / Plus Jakarta / BBH Bartle)
- [x] Unificare i 3 sistemi tipografici in `themes/typography.dart`
- [x] `EchoGlass` (BackdropFilter + tint 0.4 + highlight + shadow) usato da card/nav/player
- [x] Tipografia selezionabile dalle impostazioni

## Fase C — player (1-2 settimane)
- [x] 7 background player come Android (DEFAULT, GRADIENT, BLUR, GLOW_ANIMATED, APPLE_MUSIC, LIVE_MESH, LIQUID_GLASS)
- [x] Collegare il setting `playerBackgroundStyle` al player
- [x] Wavy / Squiggly slider (CustomPainter)
- [x] HeartBurst sull'anima preferiti
- [x] Marquee in mini-player (queue/playlist/ricerca: parziale)

## Fase D — micro-effetti e schermate firma (2-3 settimane)
- [x] Shimmer host riutilizzabile (placeholder scheletri)
- [ ] Wrapped: slide animate con spring, meter, equalizzatore (PART)
- [x] EQ circolare Canvas
- [x] Ambient con palette estratta dall'artwork

## Fase E — funzioni mancanti (2-3 settimane)
- [x] Music Flow: collegare i 7 toggle al feed
- [x] Wiring dei toggle impostazioni top (tema/variante, glass, thumbnail, font)
- [x] Export: copertina MP3 (stream sorgente: non ancora)
- [ ] Commenti (endpoint InnerTube)
- [ ] Riconoscimento brani: resta placeholder dichiarato (non portable)

## Fase F — verifica
- [x] `flutter analyze` 0 errori, `flutter test` verde, build release, installer
- [x] Aggiornare matrice con conteggio DONE e percentuale (45/48 = 93,75%)

## Non portable (esclusi dal denominatore)
Widget Android, notifica Media3, QS tile, haptics, ringtones, USB bit-perfect,
Material You dal wallpaper, RenderEffect con rifrazione reale.
