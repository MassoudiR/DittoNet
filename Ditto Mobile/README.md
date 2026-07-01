# DittoNet Browser V1.0.0

<p align="center">
  <strong>A Production-Grade Android Penetration Testing & Reverse Engineering Browser</strong><br>
  <em>Engineered in Flutter for advanced traffic interception, DOM manipulation, JS hooking, and live telemetry.</em>
</p>

---

## 🌟 Overview

**DittoNet Browser V1.0.0** is an elite mobile security assessment platform disguised and functioning as a high-performance Android Google Chrome browser. Built upon a custom Transparent Proxy Bridge architecture, DittoNet gives security researchers, developers, and penetration testers absolute programmatic control over mobile web traffic, SSL handshakes, DOM lifecycles, and network telemetry without requiring root access or external system proxies.

---

## 🔥 Key Application Functions

### 1. 🖥️ Server Integration & PC Backend Bridge
DittoNet operates in dual modes: a standalone Local Engine or a Synchronous Remote Bridge connected to a dedicated PC/Python backend.
- **Synchronous Payload Interception**: All outgoing HTTP/HTTPS requests and incoming server responses can be forwarded in real-time to your desktop workstation (`/api/intercept/request` and `/api/intercept/response`).
- **Live Ruleset Synchronization**: Instantly syncs interception policies (`/api/rules/sync`) between mobile devices and desktop command centers.
- **Health Telemetry**: Maintains a real-time connection heartbeat (`/api/health`) with latency monitoring and status indicators.

### 2. 📡 Network Tracking & HAR 1.2 Recording
Capture, analyze, and export comprehensive network telemetry directly from your mobile device.
- **W3C HAR 1.2 Export**: Record full HTTP session logs—including headers, query strings, cookies, request bodies, status codes, and timing durations—and export them as standard `.har` files compatible with Burp Suite, Postman, and Chrome DevTools.
- **Flexible Export Methods**: Save session logs directly to the device's public `Documents` folder or trigger native Android share modals to send traffic captures via Slack, Email, or cloud storage.
- **Live Traffic Logging**: Inspect real-time request flows and status codes inside the interactive Developer Hub.

### 3. 🛡️ Deep Interception & Local Rules Engine
When operating in Local Mode, DittoNet utilizes an embedded, high-performance rules engine capable of executing complex traffic modifications with zero latency.
- **Regex & Smart Pattern Matching**: Target specific domains, file extensions, or API routes using intelligent wildcard and regular expression matching (`smartPatternToRegex`).
- **Granular Action Types**:
  - `BLOCK`: Drop requests instantly before they exit the device.
  - `REDIRECT`: Reroute traffic to alternate upstream servers or endpoints.
  - `HEADER_ADD` / `HEADER_REMOVE`: Inject authentication tokens or strip security headers on the fly.
  - `BODY_REPLACE`: Override entire API request payloads or response payloads.
  - `MATCH_REPLACE`: Perform surgical string or regex replacements inside live HTTP response bodies.
  - `STATUS_OVERRIDE`: Force specific HTTP response status codes (e.g., simulating 403 Forbidden or 500 Internal Server Error).

### 4. 💉 JS Hooking & Script Injection Manager
Manipulate runtime DOM environments and execute custom JavaScript scripts directly inside target web applications.
- **Lifecycle Hooking**: Configure scripts to execute precisely at `DOCUMENT_START` (before DOM construction) or `DOCUMENT_END` (after page load).
- **Persistent Script Storage**: Built-in Script Manager allows researchers to create, edit, disable, and persist custom hooking payloads across browser sessions.

### 5. 🛠️ Integrated DevTools & Console Simulation
Debug mobile web applications seamlessly with embedded, offline-capable mobile developer suites.
- **Eruda & vConsole Integration**: One-tap injection of industry-standard mobile debugging consoles directly into any active webpage.
- **Offline Font & Asset Interception**: Automatically intercepts requests for internal DevTools fonts (`/__dittonet_devtools_font__/`) and serves them locally from memory, guaranteeing that developer consoles render flawlessly even in isolated or network-restricted environments.

### 6. 🔗 Proxy Routing & SSL Security Configuration
Configure enterprise-grade network security and traffic routing parameters on the fly via the Security Sheet.
- **Chained Upstream Proxy**: Route internal HTTP requests and native WebView traffic through external inspection proxies such as Burp Suite, OWASP ZAP, or Charles Proxy (`IP:Port`).
- **SSL Certificate Verification Bypass**: Toggle SSL pinning and verification bypass (`_lastSslBypass`) to seamlessly inspect encrypted traffic across self-signed, invalid, or expired SSL certificates.
- **Network Throttling Simulation**: Simulate poor network conditions by artificially injecting latency (e.g., 2G/3G delays) into the HTTP interception pipeline.

### 7. 📑 Smart Multi-Tab Engine & OAuth Popup Support
Experience desktop-grade multi-tab navigation designed for modern web authentication workflows.
- **Persistent Session Restore**: Automatically serializes active tab workspaces and scroll states into local storage, restoring your exact multi-tab session upon application restart.
- **Visual Grid Tab Switcher**: Switch between tabs using a sleek glassmorphic grid powered by real-time visual screenshot captures (`Uint8List`).
- **OAuth Popup Wiring**: Built with full native multiple-window support (`supportMultipleWindows: true`). Intercepts `window.open` requests (`onCreateWindow` / `onCloseWindow`) to seamlessly spawn and bind child tabs for complex OAuth flows (e.g., Google Sign-In, GitHub Authentication).
- **Smart Expandable Omnibox**: Address bar dynamically expands during text focus while hiding peripheral tools, backed by intelligent hardware back-button interception that prevents application lifecycle crashes.

### 8. ⚡ Magicman Standalone REST Client (Easter Egg)
An embedded, fully functional REST API client hidden inside the application header.
- **Cyberpunk Activation**: Long-press the main "MAGIC BROWSER" title to trigger an elastic neon transformation accompanied by heavy haptic feedback and a cyberpunk toast message.
- **Complete Request Builder**: Craft custom `GET`, `POST`, `PUT`, `PATCH`, and `DELETE` requests with editable headers, query parameters, and body payloads.
- **API Presets & JSON Formatter**: Access pre-configured test presets (JSONPlaceholder, ReqRes, HTTPBin) and format raw JSON bodies with standard 2-space indentation.
- **Copy cURL Generator**: Instantly generate and copy executable bash `curl` commands representing your active request parameters directly to the system clipboard.

---

## 🏛️ Architecture & Technical Specifications

DittoNet Browser leverages a clean **Provider** and **ChangeNotifier** state architecture (`BrowserState`) coupled with a low-level transparent network interceptor (`InterceptorCore`).

```
+-----------------------------------------------------------------+
|                       DittoNet UI Layer                         |
|  (Smart Omnibox, Multi-Tab Grid, Developer Hub, Magicman Suite) |
+-----------------------------------------------------------------+
                                 |
                                 v
+-----------------------------------------------------------------+
|                    InAppWebView Engine                          |
|    (User-Agent Spoofing, DOM Storage, JS Hooking, DevTools)     |
+-----------------------------------------------------------------+
                                 |  shouldInterceptRequest
                                 v
+-----------------------------------------------------------------+
|                       InterceptorCore                           |
|       +-------------------------------------------------+       |
|       | Phase 1: Remote PC Backend Bridge (Sync / Async)|       |
|       +-------------------------------------------------+       |
|       | Phase 2: Standalone Local Rules Engine          |       |
|       +-------------------------------------------------+       |
|       | Phase 3: Response Modification & Cookie Sync    |       |
|       +-------------------------------------------------+       |
+-----------------------------------------------------------------+
                                 |
                                 v
+-----------------------------------------------------------------+
|                Dart HTTP / Upstream Chained Proxy               |
+-----------------------------------------------------------------+
```

### Cookie & Header Synchronization
DittoNet manages the intricate lifecycle of HTTP cookies bridging the native C++/Java Chromium WebView and the Dart HTTP client. Upstream `Set-Cookie` headers are dynamically parsed and synchronized into the WebView cookie jar in real-time.

---

## 📡 API JSON Schema Contract

When running in **Remote Server Mode**, DittoNet communicates with your desktop backend using the following standardized JSON specifications:

### `GET /api/health`
Periodic connection and latency check.
```json
{
  "status": "ok",
  "latency": "12ms"
}
```

### `POST /api/rules/sync`
Synchronizes active interception rulesets.
```json
{
  "rules": [
    {
      "targetPattern": "api.targetdomain.com",
      "phase": "Both",
      "actionType": "MATCH_REPLACE",
      "matchString": "\"is_admin\":false",
      "replaceString": "\"is_admin\":true",
      "isEnabled": true
    }
  ]
}
```

### `POST /api/intercept/request`
Dispatched prior to upstream network execution.
```json
{
  "flowId": "550e8400-e29b-41d4-a716-446655440000",
  "url": "https://api.targetdomain.com/v1/user/profile",
  "method": "GET",
  "headers": {
    "User-Agent": "Mozilla/5.0 (Linux; Android 14)...",
    "Authorization": "Bearer eyJhbGciOi..."
  }
}
```

### `POST /api/intercept/response`
Dispatched upon receiving upstream server response.
```json
{
  "flowId": "550e8400-e29b-41d4-a716-446655440000",
  "url": "https://api.targetdomain.com/v1/user/profile",
  "statusCode": 200,
  "headers": {
    "Content-Type": "application/json"
  },
  "body": "base64_encoded_payload_string"
}
```

---

## 🛠️ Build & Deployment Instructions

### Prerequisites
- Flutter SDK (v3.16+)
- Android Studio / Android SDK (API 24+)

### Compilation
1. Clone the repository and navigate to the project directory:
   ```bash
   git clone https://github.com/dittonet/dittonet-browser.git
   cd "Magic Browser APP"
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run static analysis to verify codebase integrity:
   ```bash
   flutter analyze --no-fatal-infos
   ```
4. Build the production release APK:
   ```bash
   flutter build apk --release
   ```
   *The compiled release package will be generated at:* `build/app/outputs/flutter-apk/app-release.apk`.

---

<p align="center">
  <strong>DittoNet Browser V1.0.0</strong> • <em>Empowering Mobile Security Research</em>
</p>
