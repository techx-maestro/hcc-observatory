# HCC Android

Native Kotlin/Compose phone + Wear OS app for HCC. v1 shipped 2026-04-15,
running on a Galaxy S24 and Galaxy Watch 7 Ultra.

**Repo:** https://github.com/xbc4000/hcc-android (private)
**Package:** `com.techxmaestro.hcc` (release) / `com.techxmaestro.hcc.debug` (debug)
**Stack:** Kotlin · Jetpack Compose · Hilt · OkHttp · Biometric auth · WearableListenerService

## What it does

Native mobile surface for the HCC ecosystem. Phone app mirrors the web
dashboard's core pages (Home, Pi-hole, Servers, Monitor, Control) and
adds a Serina Feed tile backed by a Gotify WebSocket foreground service.
Wear OS app is a glanceable companion with pager (NIGEL / FEED / STATUS),
Serina chat, and tile complications.

## Authentication

Biometric-gated on every cold launch when a session cookie exists.
BIOMETRIC_STRONG only — fingerprint + face only, no PIN/pattern
fallback. Password login is only required once to establish the session
cookie; every subsequent launch requires biometric auth.

![Login](screenshots/01-login.png)

## Phone screens

### HOME
![Home](screenshots/20-home.png)

Single-request architecture: one `OverviewRepository` polls
`/api/overview` every 10s, ref-counted subscribers share the stream
across HOME / PI-HOLE / SERVERS / MONITOR. Zero duplicate fetches.

### ROUTER
![Router](screenshots/21-router.png)

### NETWORK
![Network](screenshots/22-network.png)

### FIREWALL
![Firewall](screenshots/23-firewall.png)

### PI-HOLE
![Pi-hole](screenshots/24-pihole.png)

### AI
![AI](screenshots/26-ai.png)

### MONITOR
![Monitor](screenshots/27-monitor.png)

### CONTROL
![Control](screenshots/28-control.png)

Has its own `ControlViewModel` + `SpotifyRepository` (dashboard proxy)
+ `BridgeRepository` (direct to Spotify Bridge container at
`10.40.40.2:3081`). 5s poll.

### SERINA FEED
![Feed](screenshots/29-feed.png)

Gotify WebSocket foreground service — auto-starts on boot, wrist-raise
alerts on the `hcc_feed` channel, messages appear both on phone and
watch tile.

## Wear OS

- **HOME pager** — NIGEL / FEED / STATUS pages, swipe between
- **CHAT** — Serina conversational view
- **FEED tile** — glanceable complication showing last 3 Gotify messages,
  5-minute refresh, tap → FEED page
- **NIGEL tile** — glanceable Serina/Nigel status
- **Push notifications** — via `FeedService` foreground WebSocket,
  auto-starts on boot

## Architecture

- `OverviewRepository` (Singleton, Hilt) — single `/api/overview` poll,
  ref-counted subscribers
- `OverviewViewModel` (Hilt) — wraps subscribe/unsubscribe, exposes
  `StateFlow<OverviewState>`
- Data screens are pure `@Composable (onMenu) { ... }` using
  `hiltViewModel<OverviewViewModel>()`
- Navigation: `ModalNavigationDrawer` with 6 routes in `AppNavHost.kt`
- `NigelRepository` fetches Serina's companion name from `chat.home/api/nigel/name`
  → displayed as `SERINA // <name>` in the NigelCard header

## Network

- `DASHBOARD_BASE_URL = https://hcc.home`
- `GOTIFY_BASE_URL = https://gotify.home`
- `SPOTIFY_BRIDGE_URL = http://10.40.40.2:3081` (cleartext, allowlisted)
- HCC root CA bundled at `res/raw/hcc_root_ca.crt` for `*.home` TLS
- Cleartext allowlisted for specific homelab IPs only

## Design

Matches the HCC desktop visual language — cyan-dominant palette, mono
typography, dense information display. Sidebar particles and topology
elements are the phone-adapted version of the Pi-hole theme's sidebar.

## Sibling modules in the same repo

The `hcc-android` repo also hosts two WristCord modules — a Wear OS
Discord client and its phone companion. Separate `applicationId`s,
shared infrastructure (build tooling, palette, Compose theme).

| Folder | Target | applicationId |
|---|---|---|
| `wristcord/` | Wear OS (on the wrist) | `com.techxmaestro.hcc.wristcord` |
| `wristcord-phone/` | Android phone companion | `com.techxmaestro.hcc.wristcord.phone` |

Status: Phase 1 complete (REST + gateway connected; voice stubbed for
Phase 3). The Discord API only accepts Discord tokens — token
acquisition UX is the hard problem the phone companion solves
(paste-from-Equicord login on the phone, eventually pushed to the
watch via Wear Data Layer).

## Related

- [HCC Dashboard](../hcc-dashboard/) — web backend powering
  `/api/overview` that the phone polls
- [Pi-hole Theme](../pihole-theme/) — visual language DNA
