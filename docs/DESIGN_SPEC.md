# LANShare Design Specification

## 1. Overview

LANShare is a cross-platform LAN tool providing three core features:
- **Instant Messaging** -- peer-to-peer text chat
- **File Transfer** -- chunked P2P file sharing with progress tracking
- **Clipboard Sync** -- automatic clipboard content synchronization between devices

Target platforms: Linux, Windows, macOS (desktop MVP), Android (future).

## 2. Architecture

```
┌──────────────────────────────────────────────────┐
│ Presentation Layer (Flutter UI + Riverpod)       │
├──────────────────────────────────────────────────┤
│ Data Layer (Services + Repositories)             │
│  ┌──────────┐ ┌──────────┐ ┌──────────────────┐ │
│  │ Discovery │ │ HTTP Srv │ │ ClipboardSync    │ │
│  │ (Bonsoir) │ │ (shelf)  │ │ Service          │ │
│  └──────────┘ └──────────┘ └──────────────────┘ │
│  ┌──────────┐ ┌──────────┐ ┌──────────────────┐ │
│  │ API Client│ │ FileSend │ │ Settings Service │ │
│  │ (Dio)    │ │ Service  │ │ (SharedPrefs)    │ │
│  └──────────┘ └──────────┘ └──────────────────┘ │
├──────────────────────────────────────────────────┤
│ Domain Layer (Entities + Enums)                  │
├──────────────────────────────────────────────────┤
│ Database (Drift + SQLite)                        │
│  Tables: Peers | Messages | FileTransfers        │
└──────────────────────────────────────────────────┘
```

## 3. UI Layout

Three-panel layout:

```
┌─────────────────────────────────────────────────────┐
│ TopBar: App Name + Version + Settings Button        │
├────────┬──────────────────────┬─────────────────────┤
│ Left   │ Center               │ Right (collapsible) │
│ 260px  │ Expanded             │ 280px (>=1200px)    │
│        │                      │                     │
│ Peer   │ Chat Panel           │ Transfers Section   │
│ List   │ - Message bubbles    │ - Active transfers  │
│        │ - File bubbles       │ - Progress bars     │
│        │ - Clipboard chips    │                     │
│        │                      │ Clipboard Section   │
│        │ ──────────────────── │ - Sync ON/OFF       │
│        │ Input: [text] [send] │ - Status indicator  │
├────────┴──────────────────────┴─────────────────────┤
│ StatusBar: Server status | Peer count               │
└─────────────────────────────────────────────────────┘
```

## 4. Device Discovery

- **Protocol**: mDNS / DNS-SD via `bonsoir` package
- **Service Type**: `_lanshare._tcp`
- **TXT Records**: `deviceId`, `deviceName` (nickname or hostname), `os`, `version`
- **Self-filtering**: Compares `deviceId` to skip own service
- **Display name**: Uses user-configured nickname if set; falls back to system hostname

## 5. REST API Protocol

All communication is HTTP over LAN (no TLS for MVP).

| Endpoint                          | Method | Purpose                  |
|-----------------------------------|--------|--------------------------|
| `/api/v1/info`                    | GET    | Device metadata          |
| `/api/v1/message`                 | POST   | Send text message        |
| `/api/v1/file/prepare`            | POST   | Initiate file transfer   |
| `/api/v1/file/upload/:transferId` | POST   | Upload file chunk        |
| `/api/v1/file/transfer/:transferId`| DELETE | Cancel file transfer    |
| `/api/v1/clipboard`               | POST   | Send clipboard content   |

## 6. Messaging

- Messages are persisted to SQLite via Drift (table: `Messages`)
- Each message has: `id`, `peerId`, `type` (text/file/clipboard), `content`, `isOutgoing`, `status`, `metadata`, `createdAt`
- Status lifecycle: `sent` -> `delivered` / `failed`
- Input: Enter sends, Shift+Enter inserts newline (handled via `FocusNode.onKeyEvent` returning `KeyEventResult.handled`)

## 7. File Transfer

### Send Flow
1. User picks file via `file_picker`
2. Client calls `POST /api/v1/file/prepare` with `{senderId, fileName, fileSize, checksum}`
3. Receiver returns `{transferId}`
4. Client uploads in 4MB chunks via `POST /api/v1/file/upload/:transferId`
5. Each chunk response includes `{bytesReceived}`
6. Final chunk response: `{status: "complete"}`

### Receive Flow
1. Server generates `transferId`, creates temp file `<path>.lanshare_tmp`
2. Appends each chunk, tracks `bytesReceived`
3. On completion: renames temp file to final path in download directory

### Integrity
- SHA-256 checksum computed by sender before transfer
- Stored in transfer record for verification

### UI Interactions (received files)
- **Double-click**: Opens file with system default application (`url_launcher` / `xdg-open`)
- **Right-click context menu**:
  - **Open** -- system default application
  - **Show in Folder** -- opens parent directory (Linux: `xdg-open`, macOS: `open -R`, Windows: `explorer /select,`)
  - **Save As...** -- `file_picker` save dialog, copies file to chosen location

## 8. Clipboard Sync

### Overview
Automatic synchronization of text clipboard content between paired devices. Controlled by an ON/OFF toggle in the right side panel.

### Switch Behavior

**ON** (`ClipboardSyncService.start()`):
- Starts a polling timer (2-second interval)
- Each tick: reads system clipboard, computes MD5 hash
- If hash differs from last known hash AND content was not recently received from a peer, broadcasts to all discovered peers via `POST /api/v1/clipboard`

**OFF** (`ClipboardSyncService.stop()`):
- Cancels the polling timer
- No outgoing clipboard broadcasts
- **Note**: Passive receiving still works -- if a remote peer sends clipboard data, the local HTTP server's `ClipboardHandler` still processes it and writes to the local clipboard. The switch only controls the **active sending direction**.

### Loop Prevention

When clipboard content is received from a peer:
1. The content's MD5 hash is added to `_recentlyReceived` set
2. `_lastClipboardHash` is updated to match
3. Content is written to local clipboard via `Clipboard.setData`
4. After 10 seconds, the hash is removed from `_recentlyReceived`

This prevents the echo loop: received content -> written to clipboard -> detected as "new" by polling -> re-sent back to sender.

### Sync Targets
When the switch is turned ON, sync targets are populated from all currently discovered peers. The target map (`deviceId -> (ip, port)`) is updated at toggle time.

### Data Format
```json
{
  "senderId": "uuid",
  "content": "clipboard text",
  "hash": "md5-hex-string",
  "timestamp": 1234567890
}
```

## 9. User Settings

Persisted via `SharedPreferences`.

| Setting          | Key                  | Default                | Description                              |
|------------------|----------------------|------------------------|------------------------------------------|
| Device Nickname  | `device_nickname`    | System hostname        | Displayed in peer discovery TXT records  |
| Download Folder  | `download_directory` | `~/LANShare/`          | Where received files are saved           |

- Nickname change takes effect on next app restart (mDNS re-advertise)
- Download folder change takes effect immediately

## 10. Database Schema

### Peers
| Column      | Type    | Notes                    |
|-------------|---------|--------------------------|
| id          | TEXT PK | deviceId from discovery   |
| deviceName  | TEXT    |                          |
| os          | TEXT    |                          |
| ipAddress   | TEXT    |                          |
| port        | INTEGER |                          |
| isOnline    | BOOLEAN |                          |
| lastSeenAt  | INTEGER | epoch ms                 |
| createdAt   | INTEGER | epoch ms                 |

### Messages
| Column      | Type    | Notes                            |
|-------------|---------|----------------------------------|
| id          | TEXT PK | UUID                             |
| peerId      | TEXT    | FK to Peers                      |
| type        | TEXT    | text / file / clipboard          |
| content     | TEXT    | message text or filename         |
| metadata    | TEXT    | e.g. "transferId\|fileSize"      |
| isOutgoing  | BOOLEAN |                                  |
| status      | TEXT    | sent / delivered / failed        |
| createdAt   | INTEGER | epoch ms                         |

### FileTransfers
| Column           | Type    | Notes                        |
|------------------|---------|------------------------------|
| id               | TEXT PK | transferId                   |
| peerId           | TEXT    |                              |
| fileName         | TEXT    |                              |
| filePath         | TEXT    | local path                   |
| fileSize         | INTEGER | bytes                        |
| bytesTransferred | INTEGER |                              |
| status           | TEXT    | pending/transferring/completed/failed/cancelled |
| checksum         | TEXT    | SHA-256                      |
| isOutgoing       | BOOLEAN |                              |
| createdAt        | INTEGER | epoch ms                     |
| completedAt      | INTEGER | epoch ms                     |

## 11. Build & Distribution

### Linux
```bash
./build_linux.sh
# Output: dist/LANShare-<version>-linux-x64.tar.gz
# Run: tar xzf ... && cd LANShare && ./lan_share
```

### Windows
```cmd
build_windows.bat
REM Output: dist\LANShare-<version>-windows-x64.zip
REM Run: Extract, double-click lan_share.exe
```

### CI (GitHub Actions)
- Trigger: push tag `v*` or manual `workflow_dispatch`
- Jobs: `build-linux` (ubuntu-latest) + `build-windows` (windows-latest)
- Release: auto-creates GitHub Release with both platform archives

## 12. Tech Stack

| Component        | Technology                |
|------------------|---------------------------|
| Framework        | Flutter 3.x               |
| State Management | Riverpod 2.x              |
| Database         | Drift + sqlite3           |
| HTTP Server      | shelf + shelf_router       |
| HTTP Client      | Dio                       |
| Discovery        | Bonsoir (mDNS/DNS-SD)     |
| Theme            | Material 3 + flex_color_scheme |
| Settings         | SharedPreferences         |
| File Picking     | file_picker               |
| File Opening     | url_launcher + Process.run |
