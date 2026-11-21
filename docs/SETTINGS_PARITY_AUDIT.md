# Settings parity audit (Android → desktop)

Font: `app/src/main/kotlin/com/music/echo/ui/screens/settings/SettingsScreen.kt`
(15 voci principali). Ogni schermata è stata aperta a runtime e catturata in
`docs/settings_parity_contact_sheet.png`.

| # | Android (route) | Desktop route | Stato | Screenshot |
|---|---|---|---|---|
| 1 | `settings/account` | `/account` | DONE | `account` |
| 2 | `settings/ai` | `/settings/ai` | DONE | `settings_ai` |
| 3 | `settings/listening_summary` | `/settings/listening_summary` | DONE | `settings_listening_summary` |
| 4 | `wrapped` | `/settings/wrapped` | DONE | `settings_wrapped` |
| 5 | `settings/appearance` | `/settings/appearance` | DONE | `settings_appearance` |
| 6 | `settings/player` | `/settings/player` | DONE | `settings_player` |
| 7 | `settings/music_flow` | `/settings/music_flow` | DONE (aggiunta in questo audit) | `settings_music_flow` |
| 8 | `Screens.ListenTogether` | `/listen_together` | DONE | `listen_together` |
| 9 | `settings/content` | `/settings/content` | DONE | `settings_content` |
| 10 | `settings/privacy` | `/settings/privacy` | DONE | `settings_privacy` |
| 11 | `settings/storage` | `/settings/storage` | DONE | `settings_storage` |
| 12 | `settings/backup_restore` | `/settings/backup_storage` | DONE | `settings_backup_storage` |
| 13 | `settings/update` | `/settings/update` | DONE (aggiunta in questo audit) | `settings_update` |
| 14 | Supported Links (system intent) | placeholder dichiarato | PLACEHOLDER esplicito (non applicabile su desktop) | menu `settings` |
| 15 | `settings/about` | `/settings/about` | DONE | `settings_about` |

## Note
- Le voci mancanti prima dell'audit (`settings/music_flow` e `settings/update`)
  ora sono schermate reali con back button e impostazioni persistenti.
- `Linked devices` è una voce extra desktop (Cast), non presente su Android.
- Le impostazioni Music Flow usano le stesse 7 chiavi booleane di Android
  (`enable`, `autoplay`, `auto next`, `hide recent`, `animated background`,
  `lyrics`, `cellular prefetch`), persistite via `SettingsManager.extra`.
- La pagina Update mostra versione installata, controllo manuale e stato,
  riproducendo `UpdateSettings.kt`.
- Test automatico: `test/settings_parity_test.dart` verifica le 15 voci del menu
  e l'esistenza di tutte le route.
