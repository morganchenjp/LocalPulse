# LocalPulse

A cross-platform Flutter desktop application for LAN-based instant messaging, file transfer, and clipboard synchronization.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Windows Firewall Configuration

LocalPulse uses TCP and UDP ports in the range 53100-53200 for peer discovery and communication. **Windows Defender Firewall may block these connections**, causing peers to fail to detect each other or messages to not be received.

### Check Your Network Profile

Windows categorizes networks as **Public** (blocks most inbound connections) or **Private** (allows local network discovery). Run this in PowerShell to check:

```powershell
Get-NetConnectionProfile
```

If your LAN shows `NetworkCategory : Public` and you want to use Private, change it:

```powershell
Set-NetConnectionProfile -InterfaceAlias "Wi-Fi" -NetworkCategory Private
```
(Replace "Wi-Fi" with your actual network adapter name from `Get-NetAdapter`)

### Required Firewall Rules

**Important:** If your network is categorized as **Public**, you must allow LocalPulse on **Public** networks, or change the network category to **Private**.

**Option 1: Allow through Windows Security**
1. Open Windows Security → Firewall & network protection
2. Click "Allow an app through the firewall"
3. Find and enable your LocalPulse executable
4. Enable for **both Private and Public** networks to work regardless of network type

**Option 2: Create inbound rule via PowerShell (Administrator)**
```powershell
# TCP ports (required for HTTP server and file transfers)
New-NetFirewallRule -DisplayName "LocalPulse TCP" -Direction Inbound -Protocol TCP -LocalPort 53100-53200 -Action Allow

# UDP ports (required for peer discovery)
New-NetFirewallRule -DisplayName "LocalPulse UDP" -Direction Inbound -Protocol UDP -LocalPort 53100-53200 -Action Allow
```

**Option 3: Disable Firewall (not recommended for production)**
```powershell
netsh advfirewall set allprofiles state off
```

After adding firewall rules, restart LocalPulse for changes to take effect.
