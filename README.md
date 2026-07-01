<p align="center">
  <img src="./assets/Ditto%20logo%20transparent.png" alt="DittoNet Logo" width="380">
</p>

<h1 align="center">⚡ DittoNet Core Infrastructure ⚡</h1>

<p align="center">
  <strong>A High-Throughput Transparent Proxy Bridge, Programmable Reverse Engineering Engine, & W3C HAR Telemetry Pipeline</strong><br>
  <em>Engineered in Flutter & Python for deterministic traffic interception, AST-aware payload mutation, runtime DOM hooking, and WebSocket command orchestration.</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Architecture-Dual__MITM__Engine-00E5FF?style=for-the-badge" alt="Architecture">
  <img src="https://img.shields.io/badge/Protocol-W3C__HAR__1.2-8A2BE2?style=for-the-badge" alt="HAR 1.2">
  <img src="https://img.shields.io/badge/Engine-Python__3.10%2B__%7C__Dart__3.1%2B-00C853?style=for-the-badge" alt="Engines">
  <img src="https://img.shields.io/badge/Telemetry-Real--Time__Socket.IO-FF6D00?style=for-the-badge" alt="Telemetry">
</p>

<p align="center">
  <a href="https://github.com/MassoudiR/DittoNet/releases/latest">
    <img src="https://img.shields.io/github/v/release/MassoudiR/DittoNet?style=for-the-badge&label=Download%20APK&logo=android&color=00C853" alt="Download APK">
  </a>
  <a href="https://github.com/MassoudiR/DittoNet/releases">
    <img src="https://img.shields.io/github/downloads/MassoudiR/DittoNet/total?style=for-the-badge&label=Total%20Downloads&color=00E5FF" alt="Total Downloads">
  </a>
  <a href="https://github.com/MassoudiR/DittoNet/stargazers">
    <img src="https://img.shields.io/github/stars/MassoudiR/DittoNet?style=for-the-badge&color=FFD700" alt="Stars">
  </a>
</p>

<p align="center">
  <img src="./assets/mockup.png" alt="DittoNet System Mockup" width="880">
</p>

---

## 🏛️ Executive Engineering Overview

Modern Android application security research is fundamentally constrained by network isolation layers, strict SSL/TLS certificate pinning, and OS-level routing restrictions. Traditional desktop proxy suites (such as Burp Suite, OWASP ZAP, or Charles Proxy) require rooted physical devices, intrusive system certificates, or fragile `iptables` forwarding rules that modern applications actively evade.

**DittoNet** solves this bottleneck at the architectural level. By embedding a high-performance transparent interceptor bridge directly into a runtime rendering environment, DittoNet captures network transactions at the boundary between native Android `WebResourceRequest` calls and the upstream network execution layer.

Operating as a unified system between a **Mobile Interceptor Client (`Ditto Mobile`)** and a **Python Command Server (`Ditto Server`)**, DittoNet provides security engineers, reverse engineers, and backend developers with complete programmatic control over HTTP/HTTPS request and response lifecycles, real-time rule evaluation, and runtime DOM environments.

---

## ⚙️ Architectural Blueprint & Execution Lifecycle

DittoNet executes traffic interception through a dual-phase hybrid pipeline. Outbound requests and inbound responses are evaluated either locally on the device with zero network overhead, or forwarded via HTTP POST to the desktop server for remote rule processing. The server then streams live telemetry events to the dashboard over Socket.IO.

```mermaid
graph TB
    subgraph Mobile Client [📱 Ditto Mobile Runtime Engine]
        REQ[Outbound HTTP/HTTPS Request] --> IR[WebResourceRequest Intercept]
        IR --> MODE{Execution Mode}
        
        MODE -->|Local Standalone Mode| LRE[Embedded Dart Rules Engine]
        LRE -->|BLOCK / REDIRECT / MATCH_REPLACE| OUT_LOCAL[Modified Payload Delivery]
        
        MODE -->|Synchronous Remote Bridge| HTTP_CLIENT[Secure Dart HTTP Client]
    end

    subgraph Desktop Command Center [🖥️ Ditto Server - Python / Flask / Socket.IO]
        HTTP_CLIENT -- POST /api/intercept/request --> FLASK[Gateway Ingestion Layer]
        FLASK --> ENGINE[InterceptEngine Rule Processor]
        ENGINE <--> SQLITE[(SQLite Persistent Rules Storage)]
        ENGINE <--> PLUGINS[Python Programmatic Plugins]
        ENGINE -- Modified Instructions --> HTTP_CLIENT
        ENGINE -- Live WebSocket Streaming --> DASH[Real-Time Command Dashboard]
    end

    HTTP_CLIENT --> UPSTREAM[Upstream Target API / Server]
    UPSTREAM -- Server Response --> HTTP_CLIENT
    HTTP_CLIENT -- POST /api/intercept/response --> FLASK
```

---

## ⚙️ Core Capabilities & Engineering Features

### 1. 🛡️ Deterministic Dual-Mode Interception Pipeline
DittoNet is engineered to operate seamlessly across two distinct network topologies:
* **Synchronous Remote Bridge**: Forwards full HTTP request headers, query parameters, and raw binary payloads to the dedicated desktop server (`/api/intercept/request`). Upstream server responses are intercepted prior to DOM rendering (`/api/intercept/response`), allowing real-time Python manipulation.
* **Standalone Zero-Latency Local Engine**: When operating offline or in high-speed environments, DittoNet evaluates persistent rules directly inside Dart memory without incurring network serialization latency.

### 2. ⚡ AST-Aware Traffic Mutation & Precedence Engine
The core interception engine applies strict, deterministic execution hierarchy across all traffic rules:
1. `BLOCK`: Immediately drops network dispatch, returning sanitized HTTP 403 responses.
2. `REDIRECT`: Instructs the mobile client to reroute a matched request to a specified alternate URL, returned as a `redirectUrl` field in the engine response.
3. `MATCH_REPLACE`: Executes surgical string and regular expression replacements inside live request and response bodies.
4. `BODY_REPLACE`: Overrides complete payloads. Automatically detects `application/json` MIME types and parses strings into structured AST dictionaries to guarantee valid JSON formatting.
5. `HEADER_INJECT`: Appends custom key-value header pairs to outbound requests or inbound responses by parsing the `matchStr` field using a `Key: Value` colon-delimited format.

### 3. 📡 W3C HAR 1.2 Session Telemetry & Serialization
Capture production-grade network telemetry without external network sniffers:
* **Full W3C Specification Compliance**: Records complete HTTP transaction records including microsecond DNS/TCP timing durations, request/response headers, query strings, cookies, status codes, and bodies.
* **Native Pipeline Export**: Serialize multi-megabyte traffic captures directly to local storage or export standardized `.har` session files into Burp Suite, OWASP ZAP, or Postman.

### 4. 💉 Runtime DOM Hooking & Sandboxed Execution
Control runtime JavaScript execution environments with surgical timing precision:
* **Lifecycle Script Injection**: Schedule custom JavaScript hooking snippets to execute at `DOCUMENT_START`—guaranteeing payload injection before the target webpage constructs its DOM tree or executes anti-tampering scripts.
* **Granular Origin Sandboxing**: Enforce strict, domain-specific security policies controlling hardware access (Camera, Microphone, Geolocation) and JavaScript execution permissions per origin.

### 5. 🛠️ Embedded DevTools Asset Server
Execute complex DOM debugging inside air-gapped or network-restricted corporate networks:
* Bundles minified industry-standard developer consoles (**Eruda** and **vConsole**) directly within application memory.
* **100% Offline Resilience**: Intercepts internal browser asset requests and serves developer suites directly from local RAM, eliminating external dependency failures during offline auditing.

### 6. 🐍 Programmable Python Backend & Rolling Memory Cache
* **Bounded Rolling Log Architecture**: Built upon an in-memory `OrderedDict` bounded by a customizable `max_logs` threshold (default `1000`). Automatically evicting the oldest network transactions prevents RAM exhaustion during high-concurrency automated API fuzzing.
* **Declarative Python Decorators**: Extend server capabilities in seconds using clean decorator syntax:

```python
from ditto_interceptor import DittoServer

server = DittoServer(port=5000, db_path="rules.db")

@server.inspector("*api/v2/auth*")
def inspect_auth_flow(flow_id, phase, headers, body):
    print(f"[{phase}] Intercepted authentication transaction: {flow_id}")

@server.plugin("PrivilegeEscalationHook")
def elevate_privileges(flow_id, phase, headers, body):
    if phase == "Response" and isinstance(body, dict) and "role" in body:
        body["role"] = "super_admin"
        return headers, body
    return headers, body

if __name__ == "__main__":
    server.run()
```

---

## 📡 API JSON Schema Specification

When operating in **Synchronous Remote Mode**, mobile clients communicate with the Python backend via standardized JSON payloads:

### `POST /api/intercept/request`
Ingested prior to upstream network dispatch.
```json
{
  "flowId": "8f9d2a10-4b3c-11ee-be56-0242ac120002",
  "url": "https://api.targetdomain.com/v1/user/profile",
  "method": "POST",
  "headers": {
    "User-Agent": "Mozilla/5.0 (Linux; Android 14)...",
    "Authorization": "Bearer eyJhbGciOi..."
  },
  "body": "{\"user_id\": 84920}"
}
```

### `POST /api/intercept/response`
Ingested upon receiving upstream server response bytes.
```json
{
  "flowId": "8f9d2a10-4b3c-11ee-be56-0242ac120002",
  "url": "https://api.targetdomain.com/v1/user/profile",
  "statusCode": 200,
  "headers": {
    "Content-Type": "application/json; charset=utf-8"
  },
  "body": "{\"status\": \"success\", \"account_tier\": \"standard\"}"
}
```

---

## 🚀 Quickstart & Deployment Infrastructure

### 1. Deploying the Python Command Center (`Ditto Server`)
```bash
cd "Ditto Server"
python -m venv .venv
# Windows: .venv\Scripts\activate | macOS/Linux: source .venv/bin/activate
pip install -r requirements.txt
python test_implementation.py
```
*Access the live WebSocket streaming dashboard at `http://localhost:5000`.*

### 2. Compiling the Runtime Client (`Ditto Mobile`)
```bash
cd "Ditto Mobile"
flutter pub get
flutter analyze --no-fatal-infos
flutter build apk --release
```
*Deploy the production release package generated at `build/app/outputs/flutter-apk/app-release.apk` to your target Android device.*

---

## ⭐ Support & Infrastructure Contribution

If DittoNet accelerates your reverse engineering pipelines or penetration testing infrastructure, consider supporting ongoing development:

| Bitcoin (BTC) Contribution | USDT (Tron TRC20) Contribution |
| :---: | :---: |
| <img src="./assets/BTC-QR.png" width="160" alt="Bitcoin QR"> | <img src="./assets/USDT-QR.png" width="160" alt="USDT QR"> |
| `16xTx25nuwDQ9gKwumJgjJCfRXVgag27vP` | `TNhAhjhvw1c1CyayxreLNxhD8u8UViLiY5` |

<p align="center">
  <br>
  <strong>DittoNet Infrastructure</strong> • <em>Deterministic Mobile Traffic Interception & Analysis</em>
</p>
