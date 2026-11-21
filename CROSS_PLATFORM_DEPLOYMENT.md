# Tamba IPTV – Cross-Platform Audit, Architecture & Deployment Guide

## 1. Platform Compatibility Matrix (Phase 1 Audit)

| Target Platform | Runtime / Client | Playback Engine | Input Model | Package Format |
|---|---|---|---|---|
| **Android Mobile & Tablet** | Flutter (this repo) | `media_kit` (`libmpv`) + bundled `LibVLC 3.6` (LGPL v2.1) | Touch, gestures, PiP drag | `.apk`, `.aab` (Google Play) |
| **Android TV / Google TV / Fire TV / Android-based Smart TVs** | Flutter (this repo, `DeviceFormFactor.isTv`) | `media_kit` / bundled `LibVLC 3.6` | D-pad remote, OK/Back, Channel Up/Down, Play/Pause, FF/RW | `.apk` / `.aab` (Leanback launcher) |
| **Samsung Smart TV (Tizen OS)** | Dedicated Tizen Web Client (`clients/smart_tv_web/`) | HTML5 + HLS.js / Samsung AVPlay | Samsung Remote (`10009` Back, `427`/`428` Ch Up/Down, `10252` Play/Pause) | `.wgt` (Tizen Studio) |
| **LG Smart TV (webOS)** | Dedicated webOS Web Client (`clients/smart_tv_web/`) | HTML5 + HLS.js / webOS media pipeline | Magic Remote + standard remote (`461` Back) | `.ipk` (webOS TV CLI) |
| **Windows Desktop** | Flutter Windows (`windows/`) | `media_kit` (`libmpv` D3D11VA/DXVA2) | Mouse, keyboard shortcuts (`Space`, `F`, `Ctrl+F`, arrows) | `.exe` / `.msix` (`packaging/windows/`) |
| **macOS Desktop** | Flutter macOS (`macos/`) | `media_kit` (`libmpv` VideoToolbox) | Trackpad, mouse, keyboard shortcuts (`Cmd+F`, `Space`, `F`) | Signed & notarized `.dmg` |
| **Linux Desktop** | Flutter Linux (`linux/`) | `media_kit` (`libmpv` VAAPI/VDPAU) | Mouse, keyboard shortcuts | `.deb` / `.AppImage` |
| **Web Browser** | Responsive Web Client (`clients/smart_tv_web/`) | HTML5 MSE + HLS.js | Mouse, touch, keyboard | Static HTTPS + CDN |

> **Chinese Smart TV Note (Hisense, TCL, Xiaomi, Skyworth, Vivo, etc.):**
> - Models running **Android TV / Google TV / AOSP TV** install the Flutter Android TV APK directly.
> - Models running proprietary Linux/VIDAA/HarmonyOS TV OSes do **not** run Android APKs natively and should use the `clients/smart_tv_web/` client packaged for their respective web-app SDK.

---

## 2. Smart TV 10-Foot Experience (Implemented in Flutter)

- **Leanback Manifest**: `android/app/src/main/AndroidManifest.xml` declares `LEANBACK_LAUNCHER`, `android:banner`, `android.software.leanback` (`required="false"`), and `android.hardware.touchscreen` (`required="false"`).
- **Auto-Expanding D-Pad Sidebar** (`lib/shared/widgets/platform_navigation_sidebar.dart`): Automatically expands when D-pad focus enters the sidebar and collapses when focus moves back to content.
- **Full Remote-Control Player** (`lib/features/player/presentation/fullscreen_player_view.dart`):
  - `OK / Enter / Select`: Wakes controls or toggles Play/Pause.
  - `Channel Up / Down` (`PageUp` / `PageDown`): Instant Live TV channel zapping.
  - `Media Play/Pause`, `Fast Forward (+30s)`, `Rewind (-30s)`.
  - `C` / `Menu` / **Channels button**: Opens the **In-Player Live Channel Drawer** without interrupting playback.
  - `L`: Returns to the previously watched Live TV channel.
  - `Back / Escape`: Closes channel drawer first, then exits player cleanly.

---

## 3. Build & Deployment Commands

### Android Mobile & Android TV (APK / AAB)
```bash
# Release AAB for Google Play (automatic per-ABI slicing)
flutter build appbundle --release

# Split-per-ABI APKs for direct sideloading / Fire TV / Android TV boxes
flutter build apk --release --split-per-abi
```
- **Google Play Store**: Configure release signing in `android/key.properties` and `android/app/build.gradle.kts`, upload `.aab`, and opt into **Android TV** in Play Console with TV screenshots and banner graphic.
- **LGPL v2.1 Compliance (LibVLC)**: Dynamic `.so` linking is preserved; LGPL v2.1 notice is shown in Settings → About.

### Samsung Smart TV (Tizen `.wgt`)
1. Copy `clients/smart_tv_web/` into a Tizen Studio TV Web Application project with `clients/smart_tv_web/tizen/config.xml` at the root (add `icon.png` 512×512).
2. Sign with a Samsung Author + Distributor certificate in Tizen Studio.
3. Package `.wgt` (`tizen package -t wgt`) and test on a Samsung TV Emulator or Developer Mode TV before submitting to Samsung Seller Office.

### LG Smart TV (webOS `.ipk`)
1. Copy `clients/smart_tv_web/` with `clients/smart_tv_web/webos/appinfo.json` at the root (add `icon.png` 80×80 and `largeIcon.png` 130×130).
2. Package using LG webOS TV CLI:
   ```bash
   ares-package clients/smart_tv_web -o dist/webos
   ares-install --device tv dist/webos/com.tambaiptv.webos_1.0.4_all.ipk
   ```
3. Submit to LG Seller Lounge after testing Magic Remote + Back key (`461`).

### Windows Desktop (EXE / MSIX)
```bash
flutter build windows --release
```
- Use `packaging/windows/` (Inno Setup / MSIX packaging) and sign the installer with an Authenticode code-signing certificate.

### macOS Desktop (Signed & Notarized DMG)
```bash
flutter build macos --release
# Sign with Developer ID Application certificate, wrap in DMG (create-dmg), and notarize:
# xcrun notarytool submit TambaIPTV.dmg --keychain-profile "AC_PASSWORD" --wait
# xcrun stapler staple TambaIPTV.dmg
```

### Web Deployment (HTTPS / CDN)
Deploy `clients/smart_tv_web/` to any static HTTPS host (Cloudflare Pages, Netlify, Vercel, Nginx + CDN). Note: browsers require HTTPS streams (or CORS-enabled proxy) to avoid mixed-content blocking, and codec support depends on the host browser (H.264/AAC HLS via HLS.js is universally supported).

---

## 4. QA & Automated Testing Checklist
- **Automated Flutter tests**: `flutter test` (M3U parser, XMLTV EPG parser, `DeviceFormFactor` Android/TV/Desktop classification, playlist file persistence).
- **Remote-control TV QA**: Verify zero mouse/touch dependency on Android TV emulator, Fire TV, Samsung Tizen emulator, and LG webOS simulator (D-pad focus visibility, sidebar expand/collapse, channel zapping, Back key behavior, network drop recovery).
