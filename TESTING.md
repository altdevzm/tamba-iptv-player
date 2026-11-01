# Testing & Quality Assurance Plan: Tamba IPTV

This document establishes the testing strategy, test cases, and verification protocols for **Tamba IPTV**.

---

## 1. Unit Testing Strategy

### A. M3U Parser Verification
- Standard `#EXTINF` format parsing with multiple attributes (`tvg-id`, `tvg-name`, `tvg-logo`, `group-title`).
- Resilience against malformed playlist lines and irregular whitespace.
- Pipe-delimited headers stripping: `http://stream.example/live.m3u8|User-Agent=CustomUA&Referer=https://ref.com` -> cleanly separates playback URL and HTTP headers.
- Multi-line `#KODIPROP` tag capture and DASH ClearKey license properties association.
- Radio stream detection (`radio="true"`).

### B. Xtream Codes Client Verification
- URL normalization (handling IP addresses, hostnames, port numbers, trailing slashes, HTTP vs HTTPS).
- Authentication flow (`get_account_info`, `get_profile`) with active, expired, and disabled states.
- Live, VOD, and Series category querying and parsing.
- Stream URL generation for Live (`.ts` / `.m3u8`), Movie (`.mp4` / `.mkv`), and Series episodes.
- Server timezone conversion for EPG timestamps.

### C. XMLTV / EPG Parsing & Channel Matching
- Decompression of compressed GZIP XMLTV files (`.xml.gz`).
- Streaming XML element processing for thousands of programmes without memory leaks.
- Channel matching accuracy:
  - Exact match on `tvg-id`
  - Case-insensitive match on `tvg-name`
  - Normalized clean title matching (stripping HD, FHD, 4K, prefixes)

### D. Drift Database Migrations & CRUD
- Foreign key cascade deletions (deleting a playlist cascades to its categories, channels, and favorites).
- Playback position update debounce and query performance.
- Favorites reordering and positional sorting.

---

## 2. Integration & Playback Testing

### A. Media Playback (`media_kit`)
- HLS live stream playback with adaptive bitrate switching.
- MPEG-TS live stream playback.
- VOD seeking, resume position accuracy, and duration retrieval.
- Audio track switching and subtitle track rendering.
- Seamless transition between Fullscreen Player and Floating Mini-Player Pill.

### B. Network & Offline Resilience
- Graceful handling of network drops and reconnection attempts.
- Offline playback of downloaded VOD movies and episodes.
- Cached catalog browsing when offline or when provider is temporarily unreachable.

---

## 3. Platform Verification Matrix

| Platform | Target Engine | Video Acceleration | Credential Storage | Status |
|---|---|---|---|---|
| **Linux (x86_64)** | Flutter Engine + libmpv | VAAPI / VDPAU / NVDEC | Secret Service (libsecret) | Ready for test |
| **Windows (x64)** | Flutter Engine + libmpv | Direct3D 11 / NVDEC | Windows Credential Manager | Ready for test |
| **Android (Mobile & TV)**| Flutter Engine + libmpv/exo | MediaCodec | Android Keystore | Ready for test |
| **macOS (arm64/x64)** | Flutter Engine + libmpv | VideoToolbox | Apple Keychain | Ready for test |
| **iOS** | Flutter Engine + libmpv | VideoToolbox | Apple Keychain | Ready for test |
