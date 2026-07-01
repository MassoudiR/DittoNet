import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../state/browser_state.dart';
import '../models/traffic_log.dart';
import 'models/local_rule.dart';
import 'network_client.dart';

class InterceptorCore {

  final BrowserState state;
  final Uuid uuid = const Uuid();
  Timer? _heartbeatTimer;
  IOClient? _client;
  static String? _cachedDittoGameHtml;

  bool _lastSslBypass = false;
  bool _lastProxyEnabled = false;
  String _lastProxyHost = '';
  String _lastProxyPort = '';

  IOClient get client {
    _client ??= NetworkClient.getSecureOrProxyClient(state);
    return _client!;
  }

  // Bypassed Extensions (JavaScript & JSON removed per requirements)
  final List<String> bypassedExtensions = [
    '.png', '.jpg', '.jpeg', '.gif', '.webp', '.svg',
    '.woff', '.woff2', '.ttf', '.otf', '.css',
    '.mp4', '.webm', '.ico'
  ];

  final List<String> bypassedDomains = [
    'recaptcha', 'gstatic.com', 'google.com', 'accounts.google.com'
  ];

  InterceptorCore(this.state) {
    // Initialize state trackers
    _lastSslBypass = state.isSslBypassEnabled;
    _lastProxyEnabled = state.isExternalProxyEnabled;
    _lastProxyHost = state.externalProxyHost;
    _lastProxyPort = state.externalProxyPort;

    _startHeartbeat();
    
    state.addListener(() {
      // ONLY destroy and recreate the IOClient if proxy or SSL settings ACTUALLY changed
      if (_lastSslBypass != state.isSslBypassEnabled ||
          _lastProxyEnabled != state.isExternalProxyEnabled ||
          _lastProxyHost != state.externalProxyHost ||
          _lastProxyPort != state.externalProxyPort) {
        
        // Update trackers
        _lastSslBypass = state.isSslBypassEnabled;
        _lastProxyEnabled = state.isExternalProxyEnabled;
        _lastProxyHost = state.externalProxyHost;
        _lastProxyPort = state.externalProxyPort;

        // Safely cycle the client
        _client?.close();
        _client = NetworkClient.getSecureOrProxyClient(state);
      }
    });
  }

  String get _baseUrl => 'http://${state.backendIp}:${state.backendPort}';

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(Duration(seconds: state.heartbeatIntervalSeconds), (_) {
      checkHealth();
    });
  }

  void forceHealthCheck() {
    checkHealth();
  }

  Future<void> checkHealth() async {
    if (state.isLocalMode) {
      state.updateConnectionStatus(ConnectionStatus.red, 0);
      return;
    }

    final stopwatch = Stopwatch()..start();
    try {
      final response = await client.get(Uri.parse('$_baseUrl/api/health')).timeout(const Duration(seconds: 2));
      stopwatch.stop();
      if (response.statusCode == 200) {
        // We could parse the latency from JSON if backend provides it, or just use stopwatch.
        state.updateConnectionStatus(ConnectionStatus.green, stopwatch.elapsedMilliseconds);
      } else {
        state.updateConnectionStatus(ConnectionStatus.yellow, stopwatch.elapsedMilliseconds);
      }
    } catch (e) {
      stopwatch.stop();
      state.updateConnectionStatus(ConnectionStatus.red, 0);
    }
  }

  bool _isTextContent(Map<String, String> headers) {
    final contentType = (headers['content-type'] ?? headers['Content-Type'] ?? '').toLowerCase();
    return contentType.contains('text') || 
           contentType.contains('json') || 
           contentType.contains('xml') || 
           contentType.contains('javascript') ||
           contentType.contains('urlencoded');
  }

  bool _shouldBypass(String urlStr) {
    if (state.isRecordingTraffic) return false;
    final url = Uri.tryParse(urlStr);
    if (url == null) return true; // Invalid URL, let webview handle it

    final path = url.path.toLowerCase();
    final host = url.host.toLowerCase();

    // Captcha & Domain Bypass (highest priority)
    for (var domain in bypassedDomains) {
      if (host.contains(domain)) {
        return true;
      }
    }

    // Check if it matches any user-defined rule first (Rules override bypass)
    // Here we do a basic check. The backend will do the real check, 
    // but if it matches a local rule, we MUST NOT bypass.
    for (var rule in state.localRules) {
      if (rule.isActive && urlStr.contains(rule.targetPattern)) {
        return false; // Matched a rule, do NOT bypass
      }
    }

    // Default bypass for heavy assets
    for (var ext in bypassedExtensions) {
      if (path.endsWith(ext)) {
        return true; // Explicitly execute return null fallback
      }
    }
    return false;
  }

  Future<http.Response> _executeAdaptiveBackendCall(Future<http.Response> requestFuture) async {
    final completer = Completer<http.Response>();
    Timer? initialTimer;
    Timer? periodicTimer;

    void cleanup() {
      initialTimer?.cancel();
      periodicTimer?.cancel();
    }

    requestFuture.then((response) {
      if (!completer.isCompleted) {
        cleanup();
        completer.complete(response);
      }
    }).catchError((error) {
      if (!completer.isCompleted) {
        cleanup();
        completer.completeError(error);
      }
    });

    initialTimer = Timer(const Duration(seconds: 5), () {
      if (completer.isCompleted) return;
      periodicTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
        if (completer.isCompleted) {
          cleanup();
          return;
        }
        await checkHealth();
        if (state.connectionStatus == ConnectionStatus.red) {
          cleanup();
          if (!completer.isCompleted) {
            completer.completeError(TimeoutException('Backend server dropped socket or became unreachable'));
          }
        }
      });
    });

    try {
      return await completer.future;
    } finally {
      cleanup();
    }
  }

  Future<WebResourceResponse?> interceptRequest(WebResourceRequest request) async {
    if (state.isLocalEngineEnabled || state.connectionStatus == ConnectionStatus.red) {
      return await executeLocalRulesEngine(request);
    }

    final urlStr = request.url.toString();

    
    // 1. Check bypass logic
    if (_shouldBypass(urlStr)) {
      return null; // Return null to let the WebView load the resource normally
    }

    final flowId = uuid.v4();
    final method = request.method ?? 'GET';
    final headers = request.headers?.cast<String, String>() ?? {};

    // Note: Android WebView's shouldInterceptRequest does not expose the request body.
    // The flutter_inappwebview WebResourceRequest object does not have a 'body' property.
    String requestBodyPayload = "";

    state.addTrafficLog(TrafficLog(
      flowId: flowId,
      url: urlStr,
      method: method,
      type: 'Intercepted (Req)',
      timestamp: DateTime.now(),
    ));

    // 2. Cookie Synchronization (WebView -> Dart HTTP)
    final cookieManager = CookieManager.instance();
    final cookies = await cookieManager.getCookies(url: WebUri(urlStr));
    if (cookies.isNotEmpty) {
      final cookieString = cookies.map((c) => '${c.name}=${c.value}').join('; ');
      headers['Cookie'] = cookieString;
    }

    // Add custom User-Agent if not already in headers or spoofed
    if (state.currentUserAgent.isNotEmpty && state.currentUserAgent != 'Default Android Chrome') {
        headers['User-Agent'] = state.currentUserAgent;
    }

    // 3. Send Request to Python Backend `/api/intercept/request`
    // CONTRACT: body must NEVER be null — always send empty string if no body.
    try {
      final reqInterceptRes = await _executeAdaptiveBackendCall(client.post(
        Uri.parse('$_baseUrl/api/intercept/request'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'flowId': flowId,
          'url': urlStr,
          'method': method,
          'headers': headers,
          'body': requestBodyPayload, // guaranteed to be "" if no body available
        }),
      ));

      if (reqInterceptRes.statusCode == 200) {
        final reqData = jsonDecode(reqInterceptRes.body);
        if (reqData['action'] == 'BLOCK') {
          state.addTrafficLog(TrafficLog(flowId: flowId, url: urlStr, method: method, type: 'Blocked', timestamp: DateTime.now()));
          return WebResourceResponse(statusCode: 403, reasonPhrase: 'Blocked by DittoNet Browser', data: Uint8List(0));
        }
        // CONTRACT: ALWAYS replace outgoing headers with result['headers'] — the server returns
        // the MERGED map (original + any injected keys like X-Magic-Role).
        if (reqData['headers'] != null) {
          headers.clear();
          (reqData['headers'] as Map).forEach((key, value) {
            headers[key.toString()] = value.toString();
          });
        }
        // CONTRACT: If server modified the body, use it for the outgoing request.
        if (reqData['body'] != null) {
          requestBodyPayload = reqData['body'].toString();
        }
      }
    } catch (e) {
      // Backend error, fallback to local request
      print("Request intercept error: $e");
    }

    // 4. Execute the actual HTTP request from Dart.
    // `headers` now contains the MERGED map from MagicServer (with any injected keys).
    // `requestBodyPayload` is the (possibly modified) body string from MagicServer.
    final startedDateTime = DateTime.now().toIso8601String();
    if (state.networkThrottleMs > 0) {
      await Future.delayed(Duration(milliseconds: state.networkThrottleMs));
    }
    final stopwatch = Stopwatch()..start();
    http.Response actualResponse;
    try {
      if (method.toUpperCase() == 'POST') {
         actualResponse = await client.post(Uri.parse(urlStr), headers: headers, body: requestBodyPayload.isNotEmpty ? requestBodyPayload : null);
      } else {
         actualResponse = await client.get(Uri.parse(urlStr), headers: headers);
      }
      stopwatch.stop();
      _recordHar(urlStr, method, headers, requestBodyPayload, actualResponse, startedDateTime, stopwatch.elapsedMilliseconds);
    } catch(e) {
      return await _handleFetchError(request, urlStr, e);
    }

    // 5. Send Response to Python Backend `/api/intercept/response`
    final resHeaders = Map<String, String>.from(actualResponse.headers);
    Uint8List responseBody = actualResponse.bodyBytes;
    
    String bodyPayload = "";
    bool isBase64 = false;

    if (responseBody.isNotEmpty) {
      if (_isTextContent(resHeaders)) {
        try {
          bodyPayload = utf8.decode(responseBody, allowMalformed: true);
        } catch (e) {
          bodyPayload = base64Encode(responseBody);
          isBase64 = true;
        }
      } else {
        bodyPayload = base64Encode(responseBody);
        isBase64 = true;
      }
    }

    try {
      final resInterceptRes = await _executeAdaptiveBackendCall(client.post(
        Uri.parse('$_baseUrl/api/intercept/response'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'flowId': flowId,
          'url': urlStr,
          'method': method,       // CONTRACT: always echo the original request method
          'statusCode': actualResponse.statusCode,
          'headers': resHeaders,
          'body': bodyPayload,    // CONTRACT: always a string, never null (empty string if no body)
          'isBase64': isBase64,
        }),
      ));

      if (resInterceptRes.statusCode == 200) {
        final resData = jsonDecode(resInterceptRes.body);
        if (resData['modified'] == true) {
           state.addTrafficLog(TrafficLog(flowId: flowId, url: urlStr, method: method, type: 'Modified (Res)', timestamp: DateTime.now()));

           // CONTRACT: ALWAYS serve result['body'] to the WebView — the server has already
           // applied MATCH_REPLACE. Do NOT fall back to the original fetched body.
           if (resData['body'] != null) {
               if (resData['isBase64'] == true) {
                   responseBody = base64Decode(resData['body']);
               } else {
                   responseBody = Uint8List.fromList(utf8.encode(resData['body'].toString()));
               }
           }
           if (resData['headers'] != null) {
              final injectedHeaders = Map<String, dynamic>.from(resData['headers']);
              injectedHeaders.forEach((key, value) {
                 resHeaders[key] = value.toString();
              });
           }
           
           // CRITICAL: Since we modified the body, the original Content-Length is no longer valid.
           // Strip it so the WebView doesn't truncate the payload based on the old, smaller byte count.
           resHeaders.remove('content-length');
           resHeaders.remove('Content-Length');
        }
      }
    } catch (e) {
       print("Response intercept error: $e");
    }

    // 6. Cookie Synchronization (Dart HTTP -> WebView)
    if (resHeaders.containsKey('set-cookie')) {
       // Note: http package collapses multiple Set-Cookie headers into one comma-separated string.
       // It requires careful parsing to handle correctly. For simplicity here, we assume single cookie or custom parsing.
       final cookieStr = resHeaders['set-cookie'];
       if (cookieStr != null) {
          // A robust implementation would parse the Set-Cookie string.
          // Using flutter_inappwebview CookieManager
          await cookieManager.setCookie(url: WebUri(urlStr), name: 'magic_cookie', value: cookieStr);
       }
    }

    // MIME Type Safety
    String contentType = "";
    String contentEncoding = "utf-8";
    final ctHeader = resHeaders['content-type'] ?? resHeaders['Content-Type'];
    if (ctHeader != null) {
        final parts = ctHeader.split(';');
        contentType = parts[0].trim();
        for (var part in parts) {
            if (part.trim().toLowerCase().startsWith('charset=')) {
                contentEncoding = part.split('=')[1].trim();
            }
        }
    }
    resHeaders.remove('content-security-policy');
    resHeaders.remove('Content-Security-Policy');
    resHeaders.remove('content-security-policy-report-only');
    resHeaders.remove('Content-Security-Policy-Report-Only');

    return WebResourceResponse(
      contentType: contentType,
      contentEncoding: contentEncoding,
      statusCode: actualResponse.statusCode,
      reasonPhrase: actualResponse.reasonPhrase ?? 'OK',
      headers: resHeaders,
      data: responseBody,
    );
  }

  // --- SMART PATTERN TO REGEX HELPER ---
  static String smartPatternToRegex(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return '.*';
    if (trimmed.startsWith('^') || trimmed.startsWith('.*') || trimmed.contains('\\.')) {
      return trimmed;
    }
    if (trimmed.contains('*')) {
      final parts = trimmed.split('*');
      final escapedParts = parts.map((p) => RegExp.escape(p)).toList();
      return escapedParts.join('.*');
    }
    return '.*${RegExp.escape(trimmed)}.*';
  }

  // --- LOCAL OFFLINE STANDALONE RULES ENGINE ---
  Future<WebResourceResponse?> executeLocalRulesEngine(WebResourceRequest request) async {
    final urlStr = request.url.toString();
    if (_shouldBypass(urlStr)) {
      return null;
    }
    final method = (request.method ?? 'GET').toUpperCase();

    // Check if any active local rules match this URL pattern (via smart regex) and HTTP Method.
    final List<LocalRule> matchedRules = state.localRules.where((r) {
      if (!r.isActive) return false;
      if (r.method != 'ALL' && r.method.toUpperCase() != method) return false;
      try {
        final regexStr = smartPatternToRegex(r.targetPattern);
        return RegExp(regexStr, caseSensitive: false).hasMatch(urlStr);
      } catch (_) {
        return false;
      }
    }).toList();

    final flowId = uuid.v4();
    final headers = request.headers?.cast<String, String>() ?? {};

    state.addTrafficLog(TrafficLog(
      flowId: flowId,
      url: urlStr,
      method: method,
      type: matchedRules.isNotEmpty ? 'Local MITM (Req)' : 'Intercepted (Req)',
      timestamp: DateTime.now(),
    ));

    // Cookie Synchronization (WebView -> Dart HTTP)
    final cookieManager = CookieManager.instance();
    final cookies = await cookieManager.getCookies(url: WebUri(urlStr));
    if (cookies.isNotEmpty) {
      headers['Cookie'] = cookies.map((c) => '${c.name}=${c.value}').join('; ');
    }

    // Spoof User-Agent if active
    if (state.currentUserAgent.isNotEmpty && state.currentUserAgent != 'Default Android Chrome') {
      headers['User-Agent'] = state.currentUserAgent;
    }

    String requestBodyPayload = "";

    // --- Phase 1: REQUEST Rules ---
    for (var rule in matchedRules) {
      if (rule.phase == 'Request' || rule.phase == 'Both') {
        if (rule.actionType == 'BLOCK') {
          state.addTrafficLog(TrafficLog(flowId: flowId, url: urlStr, method: method, type: 'Local Blocked', timestamp: DateTime.now()));
          return WebResourceResponse(
            contentType: 'text/plain',
            contentEncoding: 'utf-8',
            statusCode: 403,
            reasonPhrase: 'Blocked by DittoNet Local Engine',
            headers: {},
            data: Uint8List.fromList(utf8.encode('Access Blocked')),
          );
        } else if (rule.actionType == 'REDIRECT' && rule.replaceString != null && rule.replaceString!.isNotEmpty) {
          final redirectUrl = rule.replaceString!;
          // Smart infinite loop protection: if we are already fetching the destination target, skip redirecting!
          if (urlStr == redirectUrl || urlStr == '$redirectUrl/' || urlStr.startsWith(redirectUrl)) {
            continue;
          }
          state.addTrafficLog(TrafficLog(flowId: flowId, url: urlStr, method: method, type: 'Local Redirect', timestamp: DateTime.now()));
          return WebResourceResponse(
            contentType: 'text/html',
            contentEncoding: 'utf-8',
            statusCode: 200, // Safe 200 OK HTML redirect to prevent Chromium JNI/Crashpad minidump!
            reasonPhrase: 'OK',
            headers: {'Cache-Control': 'no-cache'},
            data: Uint8List.fromList(utf8.encode('<!DOCTYPE html><html><head><meta http-equiv="refresh" content="0;url=$redirectUrl"><script>window.location.replace("$redirectUrl");</script></head><body>Redirecting to target...</body></html>')),
          );
        } else if (rule.actionType == 'HEADER_INJECT' && rule.replaceString != null) {
          final parts = rule.replaceString!.split(':');
          if (parts.length >= 2) {
            headers[parts[0].trim()] = parts.sublist(1).join(':').trim();
          }
        } else if (rule.actionType == 'MATCH_REPLACE' && rule.matchString != null && rule.replaceString != null) {
          if (requestBodyPayload.isNotEmpty) {
            if (rule.isRegex) {
              requestBodyPayload = requestBodyPayload.replaceAll(RegExp(rule.matchString!, dotAll: true), rule.replaceString!);
            } else {
              requestBodyPayload = requestBodyPayload.replaceAll(rule.matchString!, rule.replaceString!);
            }
          }
        } else if (rule.actionType == 'BODY_REPLACE' && rule.replaceString != null) {
          requestBodyPayload = rule.replaceString!;
        }
      }
    }

    // --- Phase 2: DART HTTP EXECUTION (Local Man-in-the-Middle) ---
    final localStartedDateTime = DateTime.now().toIso8601String();
    if (state.networkThrottleMs > 0) {
      await Future.delayed(Duration(milliseconds: state.networkThrottleMs));
    }
    final localStopwatch = Stopwatch()..start();
    http.Response actualResponse;
    try {
      if (method == 'POST') {
        actualResponse = await client.post(Uri.parse(urlStr), headers: headers, body: requestBodyPayload.isNotEmpty ? requestBodyPayload : null);
      } else if (method == 'PUT') {
        actualResponse = await client.put(Uri.parse(urlStr), headers: headers, body: requestBodyPayload.isNotEmpty ? requestBodyPayload : null);
      } else if (method == 'PATCH') {
        actualResponse = await client.patch(Uri.parse(urlStr), headers: headers, body: requestBodyPayload.isNotEmpty ? requestBodyPayload : null);
      } else if (method == 'DELETE') {
        actualResponse = await client.delete(Uri.parse(urlStr), headers: headers, body: requestBodyPayload.isNotEmpty ? requestBodyPayload : null);
      } else {
        actualResponse = await client.get(Uri.parse(urlStr), headers: headers);
      }
      localStopwatch.stop();
    } catch (e) {
      return await _handleFetchError(request, urlStr, e);
    }

    final resHeaders = Map<String, String>.from(actualResponse.headers);
    Uint8List responseBodyBytes = actualResponse.bodyBytes;

    // --- Phase 3: RESPONSE Rules (Support JSON, XML, HTML, Text, All types) ---
    bool isModified = false;
    for (var rule in matchedRules) {
      if (rule.phase == 'Response' || rule.phase == 'Both') {
        if (rule.actionType == 'MATCH_REPLACE' && rule.matchString != null && rule.replaceString != null) {
          try {
            String decodedBody = utf8.decode(responseBodyBytes, allowMalformed: true);
            if (rule.isRegex) {
              decodedBody = decodedBody.replaceAll(RegExp(rule.matchString!, dotAll: true), rule.replaceString!);
            } else {
              decodedBody = decodedBody.replaceAll(rule.matchString!, rule.replaceString!);
            }
            responseBodyBytes = Uint8List.fromList(utf8.encode(decodedBody));
            isModified = true;
          } catch (_) {}
        } else if (rule.actionType == 'BODY_REPLACE' && rule.replaceString != null) {
          responseBodyBytes = Uint8List.fromList(utf8.encode(rule.replaceString!));
          isModified = true;
        } else if (rule.actionType == 'HEADER_INJECT' && rule.replaceString != null) {
          final parts = rule.replaceString!.split(':');
          if (parts.length >= 2) {
            resHeaders[parts[0].trim()] = parts.sublist(1).join(':').trim();
            isModified = true;
          }
        }
      }
    }

    if (isModified) {
      state.addTrafficLog(TrafficLog(flowId: flowId, url: urlStr, method: method, type: 'Local Modified', timestamp: DateTime.now()));
    }

    // Strip compression and length headers because Dart http Client decompresses bodyBytes automatically
    resHeaders.remove('content-encoding');
    resHeaders.remove('Content-Encoding');
    resHeaders.remove('transfer-encoding');
    resHeaders.remove('Transfer-Encoding');
    resHeaders.remove('content-length');
    resHeaders.remove('Content-Length');
    resHeaders.remove('content-security-policy');
    resHeaders.remove('Content-Security-Policy');
    resHeaders.remove('content-security-policy-report-only');
    resHeaders.remove('Content-Security-Policy-Report-Only');

    // Cookie Synchronization (Dart HTTP -> WebView)
    final setCookie = resHeaders['set-cookie'];
    if (setCookie != null) {
      await cookieManager.setCookie(url: WebUri(urlStr), name: 'magic_cookie', value: setCookie);
    }

    String contentType = "";
    String contentEncoding = "utf-8";
    final ctHeader = resHeaders['content-type'] ?? resHeaders['Content-Type'];
    if (ctHeader != null) {
      final parts = ctHeader.split(';');
      contentType = parts[0].trim();
      for (var p in parts) {
        if (p.trim().toLowerCase().startsWith('charset=')) {
          contentEncoding = p.split('=')[1].trim();
        }
      }
    }

    _recordHar(urlStr, method, headers, requestBodyPayload, actualResponse, localStartedDateTime, localStopwatch.elapsedMilliseconds);

    return WebResourceResponse(
      contentType: contentType,
      contentEncoding: contentEncoding,
      statusCode: actualResponse.statusCode,
      reasonPhrase: actualResponse.reasonPhrase ?? 'OK',
      headers: resHeaders,
      data: responseBodyBytes,
    );
  }




  void _recordHar(String url, String method, Map<String, String> reqHeaders, String reqBody, http.Response response, String startedDateTime, int elapsedMs) {
    if (!state.isRecordingTraffic) return;
    try {
      final reqHeadersList = reqHeaders.entries.map((e) => {'name': e.key, 'value': e.value}).toList();
      final resHeadersList = response.headers.entries.map((e) => {'name': e.key, 'value': e.value}).toList();

      String resBodyText = "";
      try {
        resBodyText = utf8.decode(response.bodyBytes, allowMalformed: true);
      } catch (_) {
        resBodyText = response.body;
      }

      final requestDict = <String, dynamic>{
        'method': method,
        'url': url,
        'httpVersion': 'HTTP/1.1',
        'cookies': [],
        'headers': reqHeadersList,
        'queryString': [],
        'headersSize': -1,
        'bodySize': reqBody.length,
      };

      if ((method.toUpperCase() == 'POST' || method.toUpperCase() == 'PUT') && reqBody.isNotEmpty) {
        requestDict['postData'] = {
          'mimeType': reqHeaders['content-type'] ?? reqHeaders['Content-Type'] ?? 'application/x-www-form-urlencoded',
          'text': reqBody,
        };
      }

      state.addHarEntry({
        'startedDateTime': startedDateTime,
        'time': elapsedMs,
        'request': requestDict,
        'response': {
          'status': response.statusCode,
          'statusText': response.reasonPhrase ?? '',
          'httpVersion': 'HTTP/1.1',
          'cookies': [],
          'headers': resHeadersList,
          'content': {
            'size': response.bodyBytes.length,
            'mimeType': response.headers['content-type'] ?? 'application/octet-stream',
            'text': resBodyText,
          },
          'redirectURL': response.headers['location'] ?? '',
          'headersSize': -1,
          'bodySize': response.bodyBytes.length,
        },
        'cache': {},
        'timings': {
          'send': 0,
          'wait': elapsedMs,
          'receive': 0,
        },
      });
    } catch (_) {}
  }

  Future<WebResourceResponse> _handleFetchError(WebResourceRequest request, String urlStr, Object e) async {
    final isMainFrame = (request.isForMainFrame ?? false) ||
        (request.headers != null && (request.headers!['Accept']?.contains('text/html') == true || request.headers!['sec-fetch-dest'] == 'document'));
    if (isMainFrame && !urlStr.contains('DittoGame.html') && !urlStr.contains('DittoNet.html')) {
      try {
        _cachedDittoGameHtml ??= await rootBundle.loadString('assets/DittoGame.html');
        final encodedUrl = Uri.encodeComponent(urlStr);
        String htmlContent = _cachedDittoGameHtml!;
        htmlContent = htmlContent.replaceFirst(
          '<head>',
          '<head><script>window.__failed_url = "$encodedUrl";</script>'
        );
        return WebResourceResponse(
          contentType: 'text/html',
          contentEncoding: 'utf-8',
          statusCode: 200,
          reasonPhrase: 'OK',
          headers: {'Content-Type': 'text/html; charset=utf-8'},
          data: Uint8List.fromList(utf8.encode(htmlContent)),
        );
      } catch (_) {}
    }
    return WebResourceResponse(
      contentType: 'text/plain',
      contentEncoding: 'utf-8',
      statusCode: 502,
      reasonPhrase: 'Bad Gateway',
      headers: {},
      data: Uint8List.fromList(utf8.encode('Local Proxy Error: $e')),
    );
  }

  void dispose() {
    _heartbeatTimer?.cancel();
  }
}

