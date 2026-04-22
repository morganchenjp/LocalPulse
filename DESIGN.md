# LocalPulse — Design & Architecture Document

## 1. Overview

LocalPulse is a cross-platform Flutter **desktop** application for LAN-based peer-to-peer communication. It enables three core features without requiring any central server or internet connectivity:

- **Instant Messaging** — peer-to-peer text chat over LAN
- **File Transfer** — chunked P2P file sharing with progress tracking and checksum verification
- **Clipboard Sync** — automatic clipboard synchronization between paired devices

**Target platforms:** Linux, Windows, macOS (desktop MVP).

---

## 2. Design Goals

| Goal | Rationale |
|------|-----------|
| **Zero-configuration** | Users should not need to enter IP addresses or ports. Discovery must be fully automatic. |
| **Serverless LAN** | No cloud relay, no central broker. All communication stays on the local network. |
| **Resilient discovery** | mDNS alone can be flaky on some desktop networks. A fallback mechanism ensures peers are found quickly. |
| **Desktop-native UX** | Window management, keyboard shortcuts (Enter-to-send), context menus, and responsive multi-pane layout. |
| **Offline persistence** | Messages and transfer history are stored locally so the user can review past conversations even when peers are offline. |

---

## 3. High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Presentation Layer                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │  PeerPanel  │  │  ChatPanel  │  │     SidePanel       │  │
│  └─────────────┘  └─────────────┘  └─────────────────────┘  │
│                      Riverpod 2.x (code-gen)                 │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                        Domain Layer                          │
│              Enums: MessageType, PeerStatus,                 │
│              TransferStatus                                  │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                         Data Layer                           │
│  ┌──────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │   Database   │  │  Discovery  │  │   Network Stack     │ │
│  │  (Drift/SQL) │  │  (mDNS+UDP) │  │ (shelf + Dio + ...) │ │
│  └──────────────┘  └─────────────┘  └─────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                         Core Layer                           │
│   Constants, theme, errors, platform/network utilities,      │
│   settings service                                           │
└─────────────────────────────────────────────────────────────┘
```

---

## 4. Project Structure

```
lib/
├── main.dart                    # Entry point, window setup
├── app.dart                     # MaterialApp with theming
├── core/
│   ├── constants/               # AppConstants, ProtocolConstants
│   ├── errors/                  # Failure types
│   ├── services/                # SettingsService (SharedPreferences)
│   ├── theme/                   # AppTheme (Material 3 + flex_color_scheme)
│   └── utils/                   # file_utils, network_utils, platform_utils
├── data/
│   ├── database/                # Drift + SQLite (tables, DAOs, generated .g.dart)
│   └── services/
│       ├── client/              # PeerApiClient (Dio)
│       ├── discovery/           # NsdDiscoveryService, UdpBroadcastService, HybridDiscoveryService
│       ├── server/              # LanHttpServer (shelf) + handlers
│       ├── transfer/            # FileSendService (chunked uploads)
│       └── clipboard/           # ClipboardSyncService
├── domain/
│   └── enums/                   # MessageType, PeerStatus, TransferStatus
└── presentation/
    ├── providers/               # Riverpod providers (app_providers.dart)
    ├── screens/                 # HomeScreen, SettingsScreen, ChatPanel, PeerPanel, SidePanel
    └── widgets/                 # AppTopBar, message bubbles, transfer items
```

---

## 5. State Management

**Framework:** Riverpod 2.x with code generation (`riverpod_annotation`, `riverpod_generator`).

**Key provider categories:**

| Provider | Type | Purpose |
|----------|------|---------|
| `settingsServiceProvider` | `FutureProvider` | Async initialization of SharedPreferences wrapper |
| `deviceIdProvider` | `Provider` | Immutable UUIDv4 generated at runtime |
| `databaseProvider` | `Provider` | Singleton `AppDatabase` instance |
| `apiClientProvider` | `Provider` | Singleton `PeerApiClient`; disposed on ref disposal |
| `httpServerProvider` | `FutureProvider` | Async shelf server startup; handlers wired to DB + streams |
| `discoveryServiceProvider` | `FutureProvider` | Waits for `httpServerProvider`, then starts hybrid discovery |
| `discoveredPeersProvider` | `StreamProvider` | Live map of online peers from discovery |
| `messagesForPeerProvider` | `StreamProvider.family` | Live message list per peer |
| `activeTransfersProvider` | `StreamProvider` | Live file transfer list |
| `serverStatusProvider` | `Provider` | Derived UI string from server + IP + port async states |

**Design decision:** Server and discovery are modeled as `FutureProvider`s rather than `StateNotifier`s because their lifecycle is inherently async (bind port, get IP, start advertising). The UI consumes them via `AsyncValue` to handle loading/error states declaratively.

---

## 6. Networking & Protocol

### 6.1 Transport
- **Server:** `shelf` + `shelf_router` running on a dynamically bound TCP port within `53100–53200`.
- **Client:** `Dio` with timeouts: 5s connect, 30s send/receive.
- **No TLS** for the MVP — all HTTP is plaintext over the LAN.

### 6.2 REST API

All endpoints are prefixed with `/api/v1`.

| Method | Path | Description |
|--------|------|-------------|
| `GET` | `/api/v1/info` | Return device identity (deviceId, name, os, version) |
| `POST` | `/api/v1/message` | Receive a text message |
| `POST` | `/api/v1/file/prepare` | Receiver allocates a transferId and temp file |
| `POST` | `/api/v1/file/upload/:transferId` | Upload a binary chunk for an active transfer |
| `DELETE` | `/api/v1/file/transfer/:transferId` | Cancel an in-progress transfer |
| `POST` | `/api/v1/clipboard` | Receive clipboard content from a peer |

### 6.3 Message Format
Messages are JSON with these required fields:
- `id` — UUID
- `senderId` — sender device UUID
- `type` — `text`, `file`, or `clipboard`
- `content` — message body or file name
- `timestamp` — epoch milliseconds

---

## 7. Device Discovery

### 7.1 Hybrid Strategy
Discovery uses **two independent mechanisms** whose results are merged into a single peer map. This compensates for the fact that mDNS can be slow or unreliable on some desktop networks.

#### mDNS (Bonsoir)
- **Library:** `bonsoir`
- **Service type:** `_lanshare._tcp`
- **Advertising:** Publishes device name, deviceId, OS, and protocol version as TXT records.
- **Discovery:** Listens for `_lanshare._tcp` services, resolves them to get host IP, then exposes `DiscoveredPeer` objects.

#### UDP Broadcast
- **Port:** `53199`
- **Address:** `255.255.255.255`,
    * the broadcast is confined to the local physical network or subnet of the sender.
    *  Router Behavior: Routers act as a barrier and drop packets destined for 255.255.255.255, ensuring they do not propagate beyond the local segment.
    *  Recipients: All active hosts on that same local network segment that are listening on the specified UDP port will receive the message.
- **Interval:** Every 2 seconds
- **Payload:** Pipe-delimited string: `deviceId|deviceName|os|port|version`
- **Listening:** Binds a `RawDatagramSocket` to `53199` and parses incoming broadcasts.

### 7.2 Merge Logic (`HybridDiscoveryService`)
Both services emit `Stream<Map<String, DiscoveredPeer>>`. The hybrid layer:
1. Subscribes to both streams.
2. Maintains a single `_allPeers` map keyed by `deviceId`.
3. Adds new peers immediately; updates existing peers only if IP or port changed.
4. Emits a new map only when the combined state actually changes.

**Design decision:** UDP is used as a fast-path supplement, not a replacement. mDNS provides the canonical resolution; UDP provides rapid initial detection.

---

## 8. Database Design

**Technology:** Drift (formerly Moor) with `sqlite3_flutter_libs`.

### Schema

#### `peers`
| Column | Type | Notes |
|--------|------|-------|
| `id` | TEXT | PK — device UUID |
| `deviceName` | TEXT | Human-readable name |
| `os` | TEXT | `windows`, `macos`, `linux`, `android` |
| `ipAddress` | TEXT? | Last known IP |
| `port` | INT? | Last known port |
| `isOnline` | BOOL | Default `false` |
| `lastSeenAt` | INT? | Epoch ms |
| `createdAt` | INT | Epoch ms |

#### `messages`
| Column | Type | Notes |
|--------|------|-------|
| `id` | TEXT | PK — message UUID |
| `peerId` | TEXT | FK to peers |
| `type` | TEXT | `text`, `file`, `clipboard` |
| `content` | TEXT? | Body or file name |
| `isOutgoing` | BOOL | Direction |
| `status` | TEXT | `sent`, `delivered`, `failed` |
| `metadata` | TEXT? | JSON or pipe-delimited extra data |
| `createdAt` | INT | Epoch ms |

#### `file_transfers`
| Column | Type | Notes |
|--------|------|-------|
| `id` | TEXT | PK — transfer UUID |
| `messageId` | TEXT? | Links to message row |
| `peerId` | TEXT | Target/source peer |
| `fileName` | TEXT | Original file name |
| `filePath` | TEXT? | Local path (sender) or download path (receiver) |
| `fileSize` | INT | Total bytes |
| `bytesTransferred` | INT | Default `0` |
| `status` | TEXT | `pending`, `transferring`, `completed`, `failed`, `cancelled` |
| `checksum` | TEXT? | SHA-256 hex |
| `isOutgoing` | BOOL | Direction |
| `createdAt` | INT | Epoch ms |
| `completedAt` | INT? | Epoch ms |

**Design decision:** Messages and transfers are stored separately so the chat UI can show a lightweight message row immediately, while the transfer table tracks heavy binary progress independently.

---

## 9. File Transfer Design

### 9.1 Sender Flow (`FileSendService`)
1. Compute SHA-256 checksum of the entire file.
2. `POST /api/v1/file/prepare` with metadata (name, size, checksum, senderId).
3. Receiver responds with a unique `transferId`.
4. Open file as `RandomAccessFile`; read 4MB chunks.
5. For each chunk, `POST /api/v1/file/upload/:transferId` as `application/octet-stream`.
6. Update `bytesTransferred` in DB after each chunk.
7. On final chunk, receiver renames `.lanshare_tmp` to final file name.

### 9.2 Receiver Flow (`FileHandler`)
1. `handlePrepare` generates a `transferId`, determines download directory, and opens a `.lanshare_tmp` file.
2. `handleUpload` appends incoming bytes to the temp file.
3. When `bytesReceived >= expectedSize`, rename temp to final path.
4. `handleCancel` deletes the temp file and updates DB status.

### 9.3 Progress Tracking
- Sender progress: reported via `onSendProgress` from Dio + accumulated offset.
- Receiver progress: tracked in `FileHandler._activeReceives` and persisted to `file_transfers.bytesTransferred`.
- UI: `activeTransfersProvider` streams DB changes, so progress is reactive.

**Design decision:** 4MB chunks balance memory usage (no entire file in RAM) against HTTP overhead. Checksums are computed once up front rather than per-chunk to reduce CPU load.

---

## 10. Clipboard Sync Design

### 10.1 Detection
- Polls system clipboard every **2 seconds** via `Clipboard.getData(Clipboard.kTextPlain)`.
- Computes MD5 hash of the text content.
- If hash differs from `_lastClipboardHash`, treat as new content.

### 10.2 Echo Prevention
- When receiving clipboard data from a peer, store its hash in `_recentlyReceived`.
- Skip broadcasting if the current clipboard hash is in `_recentlyReceived`.
- Entries expire after **10 seconds** to allow future legitimate syncs.

### 10.3 Broadcast
- On change, send `POST /api/v1/clipboard` to every peer in `_syncTargets`.
- Payload includes `senderId`, `content`, `hash`, and `timestamp`.

**Design decision:** Polling is used instead of native clipboard watchers because Flutter's built-in clipboard API does not expose change events on desktop. The 2-second interval is a pragmatic trade-off between responsiveness and CPU usage.

---

## 11. UI Layout

### 11.1 HomeScreen
```
┌─────────────────────────────────────────────────────────────┐
│                      AppTopBar                                │
├──────────┬──────────────────────────────┬───────────────────┤
│          │                              │                   │
│ PeerPanel│         ChatPanel            │    SidePanel      │
│ (260px)  │        (expandable)          │   (280px, opt)    │
│          │                              │                   │
├──────────┴──────────────────────────────┴───────────────────┤
│                      StatusBar                                │
└─────────────────────────────────────────────────────────────┘
```

- **PeerPanel:** Shows online peers (green dot) and offline persisted peers (grey dot). Sorted by online status, then name. OS icons give visual platform identification.
- **ChatPanel:** Message list with auto-scroll, text input with Enter-to-send, file attachment button. Supports text, file, and clipboard message bubbles.
- **SidePanel:** Collapsible on screens < 1200px; accessible via FAB + bottom sheet on narrow layouts.
- **StatusBar:** Server bind address + online peer count.

### 11.2 Theming
- `flex_color_scheme` with `FlexScheme.blueM3`.
- Surface-mode leveling for subtle depth hierarchy.
- Rounded corners on inputs (12px), cards (12px), dialogs (16px), chips (8px).

---

## 12. Settings & Configuration

**Storage:** `SharedPreferences` via `SettingsService`.

| Setting | Key | Default |
|---------|-----|---------|
| Device nickname | `device_nickname` | `Platform.localHostname` |
| Download directory | `download_directory` | `$HOME/LocalPulse` or `%USERPROFILE%\LocalPulse` |

- Nickname is advertised in discovery TXT records / UDP broadcasts.
- Download directory is used by `FileHandler` to determine where received files are saved.

---

## 13. Error Handling & Edge Cases

| Scenario | Handling |
|----------|----------|
| Port range exhausted | Fallback to OS-assigned ephemeral port (`0`) |
| Clipboard access denied | Silent catch; skip the poll cycle |
| Peer offline during send | Message/transfer status set to `failed` in DB |
| Chunk upload fails mid-transfer | `raf.close()`, status set to `failed` |
| Duplicate message ID | Drift PK constraint prevents insertion; handler still returns `200 OK` to avoid sender retry loops |
| Self-discovery | Filtered by `deviceId` comparison in both mDNS and UDP layers |
| Protocol version mismatch | UDP broadcasts are ignored; mDNS has no version gate (future enhancement) |

---

## 14. Security Considerations (MVP)

- **No encryption:** All HTTP and UDP traffic is plaintext. This is acceptable for trusted LANs in the MVP but should be addressed before handling sensitive data.
- **No authentication:** Any peer on the LAN can send messages or files. Future versions could add a pairing/trust mechanism.
- **Checksum verification:** SHA-256 is computed on the sender and stored on the receiver, but the receiver does not currently validate the final file against it. This is a known gap.
- **Temp file safety:** Incoming chunks are written to `.lanshare_tmp` in the download directory and renamed only on completion, preventing partial file exposure.

---

## 15. Build & Code Generation

```bash
# Install dependencies
flutter pub get

# Run in debug mode
flutter run

# Regenerate Drift, Riverpod, Freezed code
dart run build_runner build --delete-conflicting-outputs
```

**Generated files to ignore in code review:**
- `*.g.dart` — Drift DAOs, database schema, Riverpod providers

---

## 16. Future Extension Points

1. **End-to-end encryption** — Add NaCl/libsodium encryption layer over the HTTP API.
2. **Pairing / trust model** — Require manual approval before accepting messages/files from new peers.
3. **Checksum validation** — Verify SHA-256 on the receiver after transfer completion.
4. **Resume interrupted transfers** — Support `Range` headers or chunk offsets for partial re-upload.
5. **Group chat** — Extend message routing to multiple peers simultaneously.
6. **Mobile support** — The architecture is already cross-platform (`kIsWeb` guards desktop-only code), but UI panes need responsive refinement for phone form factors.
