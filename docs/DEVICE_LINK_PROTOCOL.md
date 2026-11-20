# Mobile ↔ Desktop linking protocol

The desktop port implements YouTube-Music-style device linking so the Android
app and the desktop app can share one signed-in session over the LAN.

## Desktop side (implemented)

- `lib/services/device_link_service.dart` hosts an HTTP server on **port 8901**.
- `lib/screens/account/device_link_page.dart` shows a fresh 6-digit pairing code
  and the LAN address (`http://<local-ip>:8901`), reachable from
  **Settings → Link mobile device** and **Account → Link mobile device**.

## Mobile side (client steps)

1. On the phone, open **Settings → Account → Link a device** (same menu entry
   as YouTube Music) and choose the LAN / nearby-device option.
2. Discover the desktop on the same Wi-Fi. Either:
   - scan/enter the LAN address shown on desktop, or
   - use UDP broadcast discovery on port **8900** (the existing
     `RemoteControlService` discovery channel).
3. POST a JSON body to `http://<desktop-ip>:8901/`:

   ```json
   {
     "code": "123456",
     "deviceName": "Pixel 8",
     "cookieHeader": "SAPISID=abc; SID=xyz; HSID=..."
   }
   ```

   - `code` must equal the 6-digit code displayed on desktop.
   - `deviceName` is a human label for the linked device.
   - `cookieHeader` is the current signed-in `Cookie:` header from the app's
     `InnerTube` / WebView session (the same value merged into requests).
4. A `200` JSON response `{ "ok": true, "device": "Pixel 8" }` confirms the
   link. The desktop imports the cookies, so both devices now share the same
   Google/YouTube Music account. A wrong code or missing fields returns `400`.

## Result

- The desktop shows the linked device and imports the session immediately
  (`CookieStore.importCookieHeader` + `StreamResolver.clearCache`).
- Playback control continues to work through the existing
  `RemoteControlService` (LAN HTTP + UDP discovery) and the Listen Together
  room (`ListenTogetherService`, port 8900).
