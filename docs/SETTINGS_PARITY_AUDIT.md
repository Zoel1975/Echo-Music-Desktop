# Settings parity audit (Android → Desktop)

Source: `app/src/main/kotlin/com/music/echo/ui/screens/settings/SettingsScreen.kt` (15 main entries). Every screen was opened at runtime and captured in `docs/settings_parity_contact_sheet.png`.

| # | Android (route) | Desktop route | Status | Screenshot |
|---|---|---|---|---|
| 1 | `settings/account` | `/account` | DONE | `account` |
| 2 | `settings/ai` | `/settings/ai` | DONE | `settings_ai` |
| 3 | `settings/listening_summary` | `/settings/listening_summary` | DONE | `settings_listening_summary` |
| 4 | `wrapped` | `/settings/wrapped` | DONE | `settings_wrapped` |
| 5 | `settings/appearance` | `/settings/appearance` | DONE | `settings_appearance` |
| 6 | `settings/player` | `/settings/player` | DONE | `settings_player` |
| 7 | `settings/music_flow` | `/settings/music_flow` | DONE (added in this audit) | `settings_music_flow` |
| 8 | `Screens.ListenTogether` | `/listen_together` | DONE | `listen_together` |
| 9 | `settings/content` | `/settings/content` | DONE | `settings_content` |
| 10 | `settings/privacy` | `/settings/privacy` | DONE | `settings_privacy` |
| 11 | `settings/storage` | `/settings/storage` | DONE | `settings_storage` |
| 12 | `settings/backup_restore` | `/settings/backup_storage` | DONE | `settings_backup_storage` |
| 13 | `settings/update` | `/settings/update` | DONE (added in this audit) | `settings_update` |
| 14 | Supported Links (system intent) | declared placeholder | EXPLICIT PLACEHOLDER (not applicable on desktop) | `settings` menu |
| 15 | `settings/about` | `/settings/about` | DONE | `settings_about` |

## Notes

- The entries missing before the audit (`settings/music_flow` and `settings/update`) are now real screens with a back button and persisted settings.
- `Linked devices` is an extra desktop entry (Cast), not present on Android.
- Music Flow settings use the same 7 boolean keys as Android (`enable`, `autoplay`, `auto next`, `hide recent`, `animated background`, `lyrics`, `cellular prefetch`), persisted through `SettingsManager.extra`.
- The Update page shows the installed version, a manual check, and status, reproducing `UpdateSettings.kt`.
- Automated test: `test/settings_parity_test.dart` verifies the 15 menu entries and the existence of all routes.
