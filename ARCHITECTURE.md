# Application Architecture: Tamba IPTV

This document establishes the architectural foundation, module structure, runtime models, and technical design patterns for **Tamba IPTV**.

---

## 1. System Architecture Overview

Tamba IPTV is built as a Flutter desktop, mobile, and TV application using feature-driven architecture, native media playback (`libmpv`), reactive state management (`Riverpod`), background tasks, and SQLite persistence (`Drift`). It is a player only and does not provide media content.

```
┌────────────────────────────────────────────────────────────────────────┐
│                   PRESENTATION TIER (Flutter / Dart)                    │
│                                                                        │
│  ┌───────────────────────┐  ┌────────────────────────────────────────┐ │
│  │   Sidebar Navigation  │  │        GoRouter Viewport Shell         │ │
│  │ (Home, TV, VOD, Lib)  │  │  (Hero Spotlight, Rails, Grids, EPG)   │ │
│  └───────────────────────┘  └────────────────────────────────────────┘ │
│  ┌───────────────────────────────────────────────────────────────────┐ │
│  │           Floating Mini-Player Pill / Fullscreen Overlay           │ │
│  └───────────────────────────────────────────────────────────────────┘ │
└────────────────────────────────────┬───────────────────────────────────┘
                                     │
                                     ▼
┌────────────────────────────────────────────────────────────────────────┐
│                 APPLICATION / STATE MANAGEMENT (Riverpod)               │
│                                                                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐ │
│  │ Playlists    │  │ Live TV &    │  │ VOD Movies & │  │ Player      │ │
│  │ Notifiers    │  │ EPG State    │  │ Series State │  │ Controller  │ │
│  └──────────────┘  └──────────────┘  └──────────────┘  └─────────────┘ │
└────────────────────────────────────┬───────────────────────────────────┘
                                     │
                                     ▼
┌────────────────────────────────────────────────────────────────────────┐
│                      DOMAIN & SERVICE LAYER (Dart)                     │
│                                                                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐ │
│  │ M3U Streaming│  │ Xtream Codes │  │ XMLTV Stream │  │ TMDB Enrich │ │
│  │ Parser       │  │ API Client   │  │ Parser       │  │ Service     │ │
│  └──────────────┘  └──────────────┘  └──────────────┘  └─────────────┘ │
└────────────────────────────────────┬───────────────────────────────────┘
                                     │
                                     ▼
┌────────────────────────────────────────────────────────────────────────┐
│                 INFRASTRUCTURE & PERSISTENCE TIER                      │
│                                                                        │
│  ┌───────────────────────────┐  ┌────────────────────────────────────┐ │
│  │       Drift + SQLite      │  │        media_kit / libmpv          │ │
│  │  (Isolate-backed DB, WAL) │  │   (Hardware-accelerated engine)    │ │
│  └───────────────────────────┘  └────────────────────────────────────┘ │
│  ┌───────────────────────────┐  ┌────────────────────────────────────┐ │
│  │   flutter_secure_storage  │  │     Shelf Embedded HTTP Server     │ │
│  │  (OS Keychain/Credentials)│  │     (Mobile Remote Control API)    │ │
│  └───────────────────────────┘  └────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Layered Structure & Clean Architecture

Each functional feature adheres to the three-tier separation of concerns:
```
feature/
├── data/
│   ├── datasources/       # Remote HTTP/API sources and Local DB queries
│   ├── models/            # JSON / DTO serialization and Drift entity mappers
│   └── repositories/      # Repository implementations connecting domain to data
├── domain/
│   ├── entities/          # Pure immutable business entities
│   ├── repositories/      # Abstract repository interfaces
│   └── usecases/          # Granular business use cases
└── presentation/
    ├── controllers/       # Riverpod AsyncNotifiers and StateNotifiers
    ├── views/             # Screens, layouts, responsive scaffolds
    └── widgets/           # Atomic, feature-specific UI components
```

---

## 3. Data Tier: Drift ORM Schema Design

All structured local data is persisted using **Drift** (SQLite) configured with write-ahead logging (`WAL`), background thread execution through native Dart isolates, and typed queries.

### Core Relational Schema

1. **`Playlists`**:
   - `id`: Text (UUID Primary Key)
   - `name`: Text
   - `type`: Text (`m3u_file`, `m3u_url`, `m3u_text`, `xtream`, `stalker`)
   - `url` / `filePath` / `serverUrl` / `portalUrl`: Text (Nullable)
   - `username` / `password`: Stored securely (or reference to secure storage)
   - `macAddress`: Text (Nullable, for Stalker)
   - `userAgent` / `origin` / `referrer`: Text (Nullable)
   - `epgUrls` / `detectedEpgUrls` / `manualEpgUrls`: Text (JSON string)
   - `autoRefresh`: Boolean (default `false`)
   - `channelCount`: Integer (default 0)
   - `position`: Integer (sort order)
   - `createdAt` / `updatedAt` / `lastUsage`: DateTime

2. **`Categories`**:
   - `id`: Integer (Auto-increment PK)
   - `playlistId`: Text (Foreign Key -> `Playlists.id`, Cascade Delete)
   - `name`: Text
   - `type`: Text (`live`, `movies`, `series`)
   - `providerId`: Integer / Text (ID from Xtream/Stalker)
   - `hidden`: Boolean (default `false`)
   - `locked`: Boolean (parental lock PIN protected, default `false`)
   - *Indexes*: `(playlistId, type, providerId)` unique index; `(playlistId, type, hidden)` partial covering index.

3. **`ContentItems` (Streams, Movies, Series)**:
   - `id`: Integer (Auto-increment PK)
   - `categoryId`: Integer (Foreign Key -> `Categories.id`, Cascade Delete)
   - `playlistId`: Text (Foreign Key -> `Playlists.id`, Cascade Delete)
   - `title`: Text
   - `type`: Text (`live`, `movie`, `series`)
   - `providerId`: Integer / Text (Xtream/Stalker ID)
   - `streamUrl` / `directSource`: Text (Nullable)
   - `containerExtension`: Text (Nullable, e.g. `mp4`, `mkv`, `ts`)
   - `posterUrl` / `backdropUrl`: Text (Nullable)
   - `rating`: Real (Nullable)
   - `releaseYear`: Integer (Nullable)
   - `epgChannelId`: Text (Nullable)
   - `tvArchive`: Integer (catchup archive duration in days/hours)
   - `tmdbId`: Integer (Nullable, TMDB resolution)
   - `addedAt`: DateTime (Nullable)

4. **`Favorites`**:
   - `id`: Integer (Auto-increment PK)
   - `playlistId`: Text (Foreign Key -> `Playlists.id`, Cascade Delete)
   - `contentId`: Integer (Nullable, Foreign Key -> `ContentItems.id`, Set Null)
   - `providerId`: Integer / Text
   - `type`: Text (`live`, `movie`, `series`)
   - `title`: Text
   - `posterUrl` / `backdropUrl`: Text (Nullable)
   - `position`: Integer (User-ordered sorting)
   - `addedAt`: DateTime

5. **`RecentlyViewed` / `PlaybackPositions`**:
   - `id`: Integer (Auto-increment PK)
   - `playlistId`: Text (Foreign Key -> `Playlists.id`, Cascade Delete)
   - `contentId`: Integer (Foreign Key -> `ContentItems.id`, Cascade Delete)
   - `contentType`: Text (`live`, `vod`, `episode`)
   - `seriesProviderId`: Integer (Nullable)
   - `seasonNumber` / `episodeNumber`: Integer (Nullable)
   - `positionSeconds`: Integer (Current playback head)
   - `durationSeconds`: Integer (Total media duration)
   - `updatedAt`: DateTime

6. **`EpgChannels` & `EpgPrograms`**:
   - `channelId`: Text (Unique channel ID in XMLTV)
   - `sourceUrl`: Text (EPG feed URL)
   - `displayName`: Text
   - `iconUrl`: Text (Nullable)
   - `start`: DateTime (Indexed)
   - `stop`: DateTime (Indexed)
   - `title`: Text
   - `description`: Text (Nullable)
   - `category`: Text (Nullable)
   - `episodeNum`: Text (Nullable)
   - *Indexes*: Composite index on `(channelId, start, stop)` for high-speed current/next lookups.

7. **`Downloads`**:
   - `id`: Integer (Auto-increment PK)
   - `playlistId`: Text
   - `providerId`: Integer / Text
   - `contentType`: Text (`vod`, `episode`, `catchup`)
   - `title`: Text
   - `downloadUrl`: Text
   - `localPath`: Text
   - `status`: Text (`queued`, `downloading`, `paused`, `completed`, `failed`, `canceled`)
   - `bytesDownloaded`: Int64
   - `totalBytes`: Int64
   - `errorMessage`: Text (Nullable)
   - `createdAt` / `updatedAt`: DateTime

8. **`TmdbCache`**:
   - `lookupKey`: Text (PK, e.g. `movie:title_normalized:year` or `id:tmdb_id`)
   - `mediaType`: Text (`movie`, `tv`, `person`)
   - `payloadJson`: Text
   - `expiresAt`: DateTime

---

## 4. State Management with Riverpod

State management follows strict Riverpod 2.x patterns:
- **No business logic in UI widgets**: All workflows, mutations, and side effects reside inside `Notifier` or `AsyncNotifier` subclasses.
- **Isolate Offloading**: M3U parsing, XMLTV decompression, and fuzzy EPG matching execute in background worker isolates using `compute()` or `Isolate.run()`.
- **Granular Selectors**: UI components consume fine-grained `.select()` watchers to avoid unnecessary widget rebuilds.
- **Explicit Lifecycle & Cancellation**: Dio `CancelToken` and Riverpod `ref.onDispose()` ensure pending network requests are canceled when screens change.

---

## 5. Playback Architecture (`media_kit`)

Media playback is powered by `media_kit` (backed by `libmpv`), providing:
- Unified C/C++ native backend across Linux, Windows, macOS, Android, and iOS.
- Hardware decoding acceleration (VAAPI, VDPAU, NVDEC, D3D11VA, MediaCodec, VideoToolbox).
- Robust support for HLS (`.m3u8`), MPEG-TS (`.ts`), MP4, MKV, AVI, and live RTMP streams.
- Full control over audio tracks, subtitle tracks, aspect ratio stretching/zooming, volume normalization, and real-time buffer diagnostics.
- Detached player state controller allowing seamless transition between the **floating mini-player pill** and the **fullscreen playback view** without interrupting the stream.

---

## 6. Security & Credential Isolation

- Plaintext credentials are never written to the SQLite database.
- Xtream Codes passwords, Stalker tokens, and Parental Lock PIN hashes are securely stored in the platform's protected credential storage (`flutter_secure_storage` utilizing Linux Secret Service / KWallet, Windows Credential Manager, Android Keystore, iOS Keychain).
- Logging utilities scrub all URLs and query parameters containing user/password credentials before emission.
