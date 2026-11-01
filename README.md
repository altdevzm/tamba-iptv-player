# Tamba IPTV

**Tamba IPTV** is an open-source media player for user-configured external sources. It does not provide playlists or media content. Users are responsible for ensuring they have authorization to access the content they configure.

---

## Key Highlights

- **Native Flutter Architecture**: High-speed, responsive performance across Linux, Windows, macOS, Android, Android TV, and iOS without Electron or Web runtime overhead.
- **Multi-Protocol IPTV Ingestion**: Full support for M3U/M3U8 URLs & files, Xtream Codes API (`player_api.php`), and Stalker / Ministra portals with token handshakes.
- **Hardware-Accelerated Playback**: Powered by `media_kit` with native `libmpv` supporting HLS, MPEG-TS, MP4, MKV, multiple audio tracks, subtitles, and aspect-ratio controls.
- **Modern Streaming UI**: Clean Netflix-dark aesthetic featuring a collapsible sidebar, Hero spotlight banner, continue watching rails with progress indicators, and a persistent **floating frosted-glass mini-player pill**.
- **10-Foot UI & D-pad Navigation**: Seamless remote control and keyboard navigation for Android TV and desktop with focus highlights, Enter/Select activation, and global shortcuts (Space, F, Esc).
- **Metadata Enrichment (TMDB v3)**: Automatic synchronization of 4K posters, backdrops, ratings, and synopses from The Movie Database API.
- **Offline Download Manager**: Background chunked downloading via `Dio` for offline movies and episodes with pause/resume and dedicated downloads management.
- **Offline Persistence & Speed**: Backed by **Drift** (SQLite) running in background isolates with write-ahead logging (WAL) for instant indexing of 100,000+ channels.
- **Secure by Default**: Passwords, tokens, and parental lock PINs are encrypted using platform-native secure credential storage (`flutter_secure_storage`).
- **Embedded Web Remote Control**: Control playback, seek, volume, and navigation from any smartphone or tablet browser on your local network (`http://<device-ip>:8383`).

---

## Core Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md): Comprehensive system design, module boundaries, database schemas, and threading architecture.
- [FEATURE_MIGRATION.md](FEATURE_MIGRATION.md): Complete mapping matrix between original IPTVnator features and Flutter implementations.
- [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md): Current implementation progress, checklist, and phase milestones.
- [TESTING.md](TESTING.md): Quality assurance, unit testing, and cross-platform verification protocols.

---

## Automated Builds

GitHub Actions runs analysis and tests, then builds platform downloads for each push to `main`. Version tags beginning with `v` also publish the build files to a GitHub Release:

- **Android:** one adaptive APK for Android phones and Android TV, plus an Android App Bundle.
- **Windows:** a per-user setup installer (`.exe`).
- **macOS:** a disk image (`.dmg`).
- **Linux:** Debian (`.deb`), Fedora-compatible RPM (`.rpm`), Arch (`.pkg.tar.zst`), and a portable x64 `.tar.gz`.

The Linux packages depend on the target distribution's GTK 3, mpv, and libsecret runtime libraries. The portable archive is for other x64 Linux distributions with those libraries installed.

Windows and macOS downloads are not code-signed or notarized yet; SmartScreen or Gatekeeper may show a first-run warning.

## Development Prerequisites

### Linux Host Dependencies
For Linux native builds, install the system build packages:
```bash
sudo apt-get update
sudo apt-get install -y libsecret-1-dev libmpv-dev mpv
```

### Running Tests
Execute the automated test suite covering M3U parsing, pipe headers, comments, and XMLTV:
```bash
flutter test
```

### Running the Application
```bash
# Run on Linux Desktop
flutter run -d linux

# Run on Android Device / Emulator
flutter run -d android

# Run on Windows Desktop
flutter run -d windows
```
