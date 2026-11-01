# Feature Migration: IPTVnator to Tamba IPTV (Flutter)

This document maps features from IPTVnator (Angular 19 / Electron / Node) to their Flutter implementations in **Tamba IPTV**.

---

## Comprehensive Feature Migration Matrix

| Original IPTVnator feature | Original implementation | Flutter implementation | Status |
|---|---|---|---|
| **M3U / M3U8 File Import** | Electron `fs.readFile` + `iptv-playlist-parser` fork in worker thread | `file_picker` + Streaming Dart M3U isolate parser (`m3u_parser.dart`) | **Completed** |
| **M3U URL Import & Auto-refresh** | Node `fetch` / Axios with custom User-Agent in worker | `Dio` streaming fetch + background isolate parser + timer refresh | **Completed** |
| **KODIPROP & DASH Extraction** | Parser fork buffering `#KODIPROP` directives | Dart M3U token reader preserving license and stream metadata | **Completed** |
| **Pipe-parameter Stripping** | String split regex | `|User-Agent=...&Referer=...` header extraction in `m3u_parser.dart` | **Completed** |
| **Multi-Playlist Management** | Angular NgRx store + Electron SQLite `playlists` table | Drift ORM `PlaylistsTable` + Riverpod `PlaylistNotifier` | **Completed** |
| **Xtream Codes Authentication** | `player_api.php` (`get_account_info`, `get_profile`) via Axios | `Dio` client `XtreamClient` with secure credentials | **Completed** |
| **Xtream Live Categories & Streams** | `get_live_categories`, `get_live_streams` | Drift relational cache + Riverpod `XtreamNotifier` | **Completed** |
| **Xtream VOD Movies Catalog** | `get_vod_categories`, `get_vod_streams`, `get_vod_info` | Drift `ContentItems` + Riverpod `movies_view.dart` | **Completed** |
| **Xtream TV Series & Seasons** | `get_series_categories`, `get_series`, `get_series_info` | Hierarchical Series/Season model + Riverpod `series_view.dart` | **Completed** |
| **Xtream Short EPG & Full EPG** | `get_short_epg`, `get_simple_data_table` | Structured EPG repository with time-window queries in `XtreamClient` | **Completed** |
| **XMLTV EPG Streaming Parser** | Node worker with `saxes` + `epg-optional-gunzip` | Dart `xml` SAX event parser + `archive` (gunzip) in isolate (`xmltv_parser.dart`) | **Completed** |
| **Channel-to-EPG Matching** | Fuzzy matching on `tvg-id`, `tvg-name`, normalized channel title | Dart normalized multi-strategy matcher (`channel_matcher.dart`) | **Completed** |
| **EPG Timeline & Programme Grid** | Angular virtual-scroller timeline component | `EpgTimelineWidget` with current show progress and upcoming schedule | **Completed** |
| **Native Media Playback** | Electron `node-mpv` / embedded `libmpv` | `media_kit` + `media_kit_video` (`libmpv` native bindings) | **Completed** |
| **Streaming Formats (HLS, TS, MP4)** | libmpv & ArtPlayer/Video.js web fallbacks | `media_kit` universal hardware-accelerated pipeline | **Completed** |
| **Floating Mini-Player Pill** | Not present in original IPTVnator (full player only) | Sleek frosted-glass floating mini-player pill docked at bottom | **Completed** |
| **Fullscreen Player View** | Angular fullscreen overlay | Flutter `FullscreenPlayerView` with auto-hiding controls overlay | **Completed** |
| **Favorites Management** | SQLite `favorites` table with drag-and-drop ordering | Drift `FavoritesTable` + `FavoritesView` screen + toggle button | **Completed** |
| **Recently Watched / History** | SQLite `recently_viewed` table with timestamp | Drift `RecentlyViewedTable` + reactive Riverpod stream | **Completed** |
| **Continue Watching & Progress** | SQLite `playback_positions` table (percentage & seconds) | Drift `PlaybackPositionsTable` with auto-save & resume in `PlayerController` | **Completed** |
| **Parental Lock PIN Protection** | 4-8 digit SHA-256 PIN hash, category lock | `crypto` SHA-256 + `flutter_secure_storage` + `PinPromptDialog` | **Completed** |
| **Download Manager** | Electron download worker with partial byte tracking | `Dio` file chunk downloader with pause/resume & `DownloadsView` | **Completed** |
| **10-Foot UI & D-pad Navigation** | Separate Preact `apps/tv` subproject | `FocusableActionDetector` + `CallbackShortcuts` + D-pad borders | **Completed** |
| **Keyboard Navigation & Hotkeys** | Mousetrap / Electron global shortcuts | Global `CallbackShortcuts` for Space, F, Esc, Arrow Keys | **Completed** |
| **Web Remote Control Server** | Node Express HTTP server + static Angular web app | `shelf` embedded HTTP server + mobile touch controller at port 8383 | **Completed** |
| **Settings & Cache Management** | Settings screen in Angular | Flutter `SettingsView` with EPG URL import, history & cache purge | **Completed** |
| **Light & Dark Theme Support** | Angular SCSS variables and theme toggle | High-contrast Netflix-dark aesthetic with Inter typography | **Completed** |
| **Stalker Portal (Ministra)** | Handshake, token auth, `/load.php` (ITV, VOD, Series) | Full Stalker/Ministra client (`StalkerClient`), repository sync, and multi-tab playlist manager | **Completed** |
| **Deep TMDB Metadata Enrichment** | TMDB v3 API with `append_to_response: credits,videos,recommendations,release_dates` | Full `TmdbService` with in-memory caching, cast avatars, trailers, recommendations, and regional age rating | **Completed** |
| **Xtream Short EPG in Live Grid** | `action=get_short_epg` fallback for channel cards | Automatic short EPG retrieval and base64 decode on Live TV cards | **Completed** |
| **Catchup / Timeshift Playback** | Timeshift URL builder (`timeshift.php` / REST `/timeshift/...`) | EpgTimelineWidget replay button with time-window offset calculation | **Completed** |
| **Stalker Series Drilling** | `get_ordered_list&type=series&movie_id=...` | Stalker season/episode tree parsing & `createLink` streaming | **Completed** |
| **Category Parental Lock PIN** | Category pin gate for adult/restricted content | Interactive `PinPromptDialog` interceptor in Live TV, Movies, and Series | **Completed** |
| **Universal Global Search** | Cross-playlist `/search` route grouping Live, Movies, Series | Unified `GlobalSearchView` (`/search`) with reactive cross-catalog queries | **Completed** |
| **Backup & Restore (JSON)** | Full `.json` export/import in Settings > Backup | Pure Dart `BackupService` with playlist, favorites, and settings export/restore | **Completed** |
| **Live Stream DVR Recording** | MPV stream-dump recording in Electron | `StreamRecordingNotifier` background chunk sink to Documents/Recordings with live timer | **Completed** |
| **External Player Launch** | "Open in VLC / MPV" context action | `ExternalPlayerService` with decoupled Process spawn for VLC and standalone MPV | **Completed** |
| **Multi-Channel 2D EPG Matrix** | Full-screen continuous 2D schedule grid | `EpgGridView` (`/epg`) with X-axis timeline ruler, Y-axis channels, and Jump to Now | **Completed** |
| **Custom Stream Headers** | Global User-Agent and Referer overrides | Settings persistence for custom User-Agent and Referer headers | **Completed** |
