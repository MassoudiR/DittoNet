import 'dart:ui';
import 'dart:async';
import 'dart:convert';
import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import '../state/browser_state.dart';
import '../core/interceptor_core.dart';
import '../core/devtools_manager.dart';
import 'components/developer_hub.dart';
import 'components/connection_dialog.dart';
import 'components/home_dashboard.dart';
import 'components/bookmarks_sheet.dart';
import 'components/history_sheet.dart';
import 'components/site_security_sheet.dart';
import 'components/tab_switcher_sheet.dart';
import '../core/har_manager.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/services/update_service.dart';
import 'components/update_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'components/support_sheet.dart';

class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  final GlobalKey webViewKey = GlobalKey();
  InAppWebViewController? get webViewController => context.read<BrowserState>().currentTab?.controller;
  final TextEditingController urlController = TextEditingController();
  final FocusNode _urlFocusNode = FocusNode();
  String? _lastMasterScript;

  final ValueNotifier<double> _backSwipeNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<double> _forwardSwipeNotifier = ValueNotifier<double>(0.0);

  bool _isNavbarVisible = true;
  Timer? _navbarHideTimer;
  Timer? _supportPromptTimer;
  Offset? _iconOffset;
  bool _isDragging = false;
  Offset? _dragStartOffset;
  Offset? _dragStartIconOffset;


  Future<void> _openTabSwitcher() async {
    final state = context.read<BrowserState>();
    final activeTab = state.currentTab;
    if (activeTab?.controller != null) {
      try {
        final screenshot = await activeTab!.controller!.takeScreenshot();
        if (screenshot != null) {
          state.updateTabState(state.currentTabIndex, screenshot: screenshot);
        }
      } catch (_) {}
    }
    if (mounted) {
      showTabSwitcherSheet(context, onTabSwitched: () {
        final newTab = context.read<BrowserState>().currentTab;
        urlController.text = newTab?.url ?? '';
      });
    }
  }

  Widget _buildTabCounterButton(BrowserState state) {
    return GestureDetector(
      onTap: _openTabSwitcher,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFF2C2C38),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white38, width: 1.5),
        ),
        alignment: Alignment.center,
        child: Text(
          '${state.tabs.length}',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
    );
  }

  void _keepNavbarVisible() {
    if (!mounted) return;
    if (!_isNavbarVisible) return;
    _navbarHideTimer?.cancel();
    _navbarHideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        final state = context.read<BrowserState>();
        final isHome = state.currentUrl.isEmpty || state.currentUrl == 'about:blank';
        if (!isHome) {
          setState(() => _isNavbarVisible = false);
        }
      }
    });
  }

  void _showNavbarManually() {
    if (mounted) {
      setState(() => _isNavbarVisible = true);
      _navbarHideTimer?.cancel();
      _navbarHideTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) {
          final state = context.read<BrowserState>();
          final isHome = state.currentUrl.isEmpty || state.currentUrl == 'about:blank';
          if (!isHome) {
            setState(() => _isNavbarVisible = false);
          }
        }
      });
    }
  }

  static const String _postPayloadInterceptorScript = """
(function() {
  if (window.__ditto_post_hooked) return;
  window.__ditto_post_hooked = true;

  try {
    if (Object.defineProperty) {
      Object.defineProperty(navigator, 'webdriver', { get: () => false });
    }
  } catch(_) {}

  function isCaptchaDomain(u) {
    if (!u) return false;
    let lower = String(u).toLowerCase();
    return lower.includes('recaptcha') || 
           lower.includes('gstatic.com') || 
           lower.includes('google.com/recaptcha') || 
           lower.includes('hcaptcha.com') || 
           lower.includes('challenges.cloudflare.com') || 
           lower.includes('turnstile') || 
           lower.includes('arkoselabs.com');
  }

  if (isCaptchaDomain(window.location.href)) return;

  async function helperBodyToString(body) {
    if (!body) return "";
    if (typeof body === 'string') return body;
    if (body instanceof URLSearchParams) return body.toString();
    if (body instanceof FormData) {
      const params = new URLSearchParams();
      body.forEach((val, key) => params.append(key, val));
      return params.toString();
    }
    if (body instanceof Blob) {
      return new Promise(resolve => {
        const reader = new FileReader();
        reader.onload = () => resolve(reader.result);
        reader.readAsText(body);
      });
    }
    try {
      return JSON.stringify(body);
    } catch(e) {
      return String(body);
    }
  }

  // 1. Hook window.fetch
  const origFetch = window.fetch;
  window.fetch = async function(input, init) {
    let url = typeof input === 'string' ? input : (input && input.url ? input.url : '');
    let method = (init && init.method) ? init.method.toUpperCase() : (input && input.method ? input.method.toUpperCase() : 'GET');
    
    if (method === 'POST' || method === 'PUT' || method === 'PATCH') {
      let fullUrl = new URL(url, window.location.href).href;
      if (isCaptchaDomain(fullUrl)) {
        return origFetch.apply(this, arguments);
      }

      let headers = {};
      if (init && init.headers) {
        if (init.headers instanceof Headers) {
          init.headers.forEach((val, key) => headers[key] = val);
        } else if (Array.isArray(init.headers)) {
          init.headers.forEach(pair => headers[pair[0]] = pair[1]);
        } else {
          headers = Object.assign({}, init.headers);
        }
      } else if (input && input.headers instanceof Headers) {
        input.headers.forEach((val, key) => headers[key] = val);
      }
      
      let bodyData = (init && init.body !== undefined) ? init.body : (input && input.body ? input.body : null);
      let bodyStr = await helperBodyToString(bodyData);
      
      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        const res = await window.flutter_inappwebview.callHandler('interceptPostPayload', {
          url: fullUrl,
          method: method,
          headers: headers,
          body: bodyStr
        });
        if (res) {
          let resHeaders = new Headers(res.headers || {});
          return new Response(res.body || "", {
            status: res.statusCode || 200,
            statusText: res.reasonPhrase || "OK",
            headers: resHeaders
          });
        }
      }
    }
    return origFetch.apply(this, arguments);
  };

  // 2. Hook XMLHttpRequest
  const origXhrOpen = XMLHttpRequest.prototype.open;
  const origXhrSend = XMLHttpRequest.prototype.send;
  const origXhrSetHeader = XMLHttpRequest.prototype.setRequestHeader;

  XMLHttpRequest.prototype.open = function(method, url) {
    this._dittoMethod = (method || 'GET').toUpperCase();
    try {
      this._dittoUrl = new URL(url, window.location.href).href;
    } catch(_) {
      this._dittoUrl = url;
    }
    this._dittoHeaders = {};
    return origXhrOpen.apply(this, arguments);
  };

  XMLHttpRequest.prototype.setRequestHeader = function(header, value) {
    if (this._dittoHeaders) {
      this._dittoHeaders[header] = value;
    }
    return origXhrSetHeader.apply(this, arguments);
  };

  XMLHttpRequest.prototype.send = function(bodyData) {
    if (this._dittoMethod === 'POST' || this._dittoMethod === 'PUT' || this._dittoMethod === 'PATCH') {
      if (isCaptchaDomain(this._dittoUrl)) {
        return origXhrSend.apply(this, arguments);
      }
      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        helperBodyToString(bodyData).then(bodyStr => {
          window.flutter_inappwebview.callHandler('interceptPostPayload', {
            url: this._dittoUrl,
            method: this._dittoMethod,
            headers: this._dittoHeaders || {},
            body: bodyStr
          }).then(res => {
            if (res) {
              Object.defineProperty(this, 'status', { writable: true, value: res.statusCode || 200 });
              Object.defineProperty(this, 'statusText', { writable: true, value: res.reasonPhrase || "OK" });
              Object.defineProperty(this, 'readyState', { writable: true, value: 4 });
              Object.defineProperty(this, 'responseText', { writable: true, value: res.body || "" });
              Object.defineProperty(this, 'response', { writable: true, value: res.body || "" });
              
              let headerStr = "";
              if (res.headers) {
                for (let k in res.headers) {
                  headerStr += k + ": " + res.headers[k] + "\\r\\n";
                }
              }
              this.getAllResponseHeaders = function() { return headerStr; };
              this.getResponseHeader = function(h) {
                if (!res.headers) return null;
                for (let k in res.headers) {
                  if (k.toLowerCase() === h.toLowerCase()) return res.headers[k];
                }
                return null;
              };
              
              if (typeof this.onreadystatechange === 'function') this.onreadystatechange();
              if (typeof this.onload === 'function') this.onload();
              this.dispatchEvent(new Event('readystatechange'));
              this.dispatchEvent(new Event('load'));
            }
          });
        });
        return;
      }
    }
    return origXhrSend.apply(this, arguments);
  };

  // 3. Hook HTML Form Submissions
  async function handleFormSubmit(form) {
    const method = (form.method || 'GET').toUpperCase();
    if (method === 'POST' || method === 'PUT' || method === 'PATCH') {
      let actionUrl = form.action ? new URL(form.action, window.location.href).href : window.location.href;
      if (isCaptchaDomain(actionUrl)) return false;

      const formData = new FormData(form);
      const urlParams = new URLSearchParams();
      formData.forEach((val, key) => urlParams.append(key, val));
      const bodyStr = urlParams.toString();
      let enctype = form.enctype || 'application/x-www-form-urlencoded';
      
      if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
        const res = await window.flutter_inappwebview.callHandler('interceptPostPayload', {
          url: actionUrl,
          method: method,
          headers: { 'Content-Type': enctype },
          body: bodyStr,
          isFormSubmit: true
        });
        if (res) {
          if (res.redirectUrl) {
            window.location.href = res.redirectUrl;
          } else if (res.body) {
            document.open();
            document.write(res.body);
            document.close();
          }
          return true;
        }
      }
    }
    return false;
  }

  document.addEventListener('submit', async function(e) {
    const form = e.target;
    if (form && form.tagName === 'FORM' && (form.method || '').toUpperCase() === 'POST') {
      let actionUrl = form.action ? new URL(form.action, window.location.href).href : window.location.href;
      if (isCaptchaDomain(actionUrl)) return;
      e.preventDefault();
      await handleFormSubmit(form);
    }
  }, true);

  const origFormSubmit = HTMLFormElement.prototype.submit;
  HTMLFormElement.prototype.submit = function() {
    let actionUrl = this.action ? new URL(this.action, window.location.href).href : window.location.href;
    if ((this.method || '').toUpperCase() === 'POST' && !isCaptchaDomain(actionUrl)) {
      handleFormSubmit(this);
    } else {
      origFormSubmit.apply(this, arguments);
    }
  };
})();
""";

  String _generateMasterHookScript(BrowserState state) {
    final buffer = StringBuffer();
    buffer.writeln(_postPayloadInterceptorScript);

    final activeScripts = state.hookScripts.where((s) => s.isActive).toList();
    for (final s in activeScripts) {
      final smartRegex = InterceptorCore.smartPatternToRegex(s.targetPattern);
      final escapedPattern = jsonEncode(smartRegex);
      buffer.writeln("""
(function() {
  try {
    var regex = new RegExp($escapedPattern, 'i');
    if (regex.test(window.location.href)) {
      ${s.code}
    }
  } catch(e) { console.error("Hook error (${s.name}):", e); }
})();
""");
    }
    return buffer.toString();
  }

  Future<void> _syncHookScripts(InAppWebViewController controller, BrowserState state) async {
    try {
      await controller.removeAllUserScripts();
      final masterScript = _generateMasterHookScript(state);
      if (masterScript.isNotEmpty) {
        await controller.addUserScript(
          userScript: UserScript(
            source: masterScript,
            injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
          ),
        );
      }
    } catch (e) {
      print("Error syncing hook scripts: $e");
    }
  }

  @override
  void dispose() {
    try {
      context.read<BrowserState>().clearAllTabsAndKeys();
    } catch (_) {}
    _backSwipeNotifier.dispose();
    _forwardSwipeNotifier.dispose();
    _navbarHideTimer?.cancel();
    _supportPromptTimer?.cancel();
    _urlFocusNode.dispose();
    urlController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    final state = context.read<BrowserState>();
    urlController.text = state.currentUrl;
    _urlFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _showNavbarManually();
    _applyProxyOverride(state);
    state.addListener(() {
      _applyProxyOverride(state);
    });
    _checkForAppUpdates();
    _scheduleSupportPrompt();
  }

  void _scheduleSupportPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    final bool doNotDisturb = prefs.getBool('supportPromptDoNotDisturb') ?? false;
    if (doNotDisturb) return;

    final int lastShownTime = prefs.getInt('lastShownSupportPromptTime') ?? 0;
    final int currentTime = DateTime.now().millisecondsSinceEpoch;
    const int twoDaysInMillis = 48 * 60 * 60 * 1000;

    if (lastShownTime == 0 || (currentTime - lastShownTime) >= twoDaysInMillis) {
      _supportPromptTimer = Timer(const Duration(seconds: 120), () {
        if (mounted) {
          _showSupportPopup();
          prefs.setInt('lastShownSupportPromptTime', DateTime.now().millisecondsSinceEpoch);
        }
      });
    }
  }

  void _showSupportPopup() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xE616182C),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF00E5FF), width: 1.5),
              boxShadow: const [
                BoxShadow(color: Color(0x3300E5FF), blurRadius: 20, spreadRadius: 2),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0x2600E5FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.volunteer_activism, color: Color(0xFF00E5FF), size: 32),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Enjoying DittoNet?',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text(
                  'DittoNet Browser is proudly open source & built for mobile privacy. Consider starring us on GitHub or supporting continuous development!',
                  style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 6,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const SupportSheet(),
                      );
                    },
                    icon: const Icon(Icons.favorite, color: Colors.black),
                    label: const Text('Info & Update', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Maybe Later', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('supportPromptDoNotDisturb', true);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Do Not Disturb enabled. You won\'t be prompted again.'),
                              backgroundColor: Colors.grey,
                              duration: Duration(seconds: 3),
                            ),
                          );
                        }
                      },
                      child: const Text('Do Not Disturb', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _checkForAppUpdates() async {
    final update = await GitHubUpdater.instance.checkForUpdates();
    if (update != null && mounted) {
      showDialog(
        context: context,
        builder: (context) => UpdateDialog(updateModel: update),
      );
    }
  }

  Future<void> _applyProxyOverride(BrowserState state) async {
    try {
      final proxyController = ProxyController.instance();
      if (state.isExternalProxyEnabled && state.externalProxyHost.isNotEmpty) {
        await proxyController.setProxyOverride(
          settings: ProxySettings(
            proxyRules: [
              ProxyRule(url: "${state.externalProxyHost}:${state.externalProxyPort}")
            ],
          ),
        );
      } else {
        await proxyController.clearProxyOverride();
      }
    } catch (e) {
      // Note: If ProxyController override fails on older Android WebView versions, Chromium native traffic falls back to system proxy while intercepted Dart HTTP traffic uses chained proxy.
    }
  }

  void _loadUrl(String url) {
    if (url.isEmpty) return;
    var validUrl = url.trim();
    if (validUrl.startsWith("file://") || validUrl.startsWith("asset://") || validUrl.startsWith("about:") || validUrl.startsWith("data:")) {
      // Keep exact validUrl
    } else if (!validUrl.contains(' ') && validUrl.contains('.')) {
      if (!validUrl.startsWith("http://") && !validUrl.startsWith("https://")) {
        validUrl = "https://$validUrl";
      }
    } else {
      final encodedQuery = Uri.encodeComponent(validUrl);
      validUrl = "https://www.google.com/search?q=$encodedQuery";
    }
    
    final state = context.read<BrowserState>();
    final wasHome = state.currentUrl.isEmpty || state.currentUrl == 'about:blank';
    
    // Show navbar when starting navigation
    _showNavbarManually();
    
    // Update state to trigger WebView rendering if it was on Home Dashboard
    state.updateBrowserState(url: validUrl);
    
    // Only call loadUrl explicitly if the WebView was already mounted.
    // If it was on the Home Dashboard, the WebView was disposed.
    // The state update above will build a NEW WebView, which loads validUrl via initialUrlRequest.
    if (!wasHome) {
      webViewController?.loadUrl(urlRequest: URLRequest(url: WebUri(validUrl)));
    }
    urlController.text = validUrl;
  }

  void _showConnectionDialog() {
    showDialog(
      context: context,
      builder: (context) => const ConnectionDialog(),
    );
  }

  Future<void> _updateNavigationState(InAppWebViewController controller) async {
    final back = await controller.canGoBack();
    final forward = await controller.canGoForward();
    if (mounted) {
      context.read<BrowserState>().updateBrowserState(back: back, forward: forward);
    }
  }

  void _openLogsWindow() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const LogsWindow(),
    );
  }

  void _openSettingsWindow() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const SettingsWindow(),
    );
  }

  void _openBookmarksSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BookmarksSheet(onNavigate: _loadUrl),
    );
  }

  void _openHistorySheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => HistorySheet(onNavigate: _loadUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BrowserState>();
    final interceptor = context.read<InterceptorCore>();
    
    final currentMasterScript = _generateMasterHookScript(state);
    if (_lastMasterScript != null && _lastMasterScript != currentMasterScript && webViewController != null) {
      _lastMasterScript = currentMasterScript;
      _syncHookScripts(webViewController!, state);
    } else if (_lastMasterScript == null) {
      _lastMasterScript = currentMasterScript;
    }

    final isHome = state.currentUrl.isEmpty || state.currentUrl == 'about:blank';
    final showFullNavbar = isHome || _isNavbarVisible;


    return WillPopScope(
      onWillPop: () async {
        final state = context.read<BrowserState>();
        if (state.tabs.isEmpty) return true;

        final currentTab = state.currentTab;
        if (currentTab == null) return true;

        final isHome = currentTab.url.isEmpty || currentTab.url == 'about:blank';
        if (!isHome && currentTab.controller != null) {
          final canGoBack = await currentTab.controller!.canGoBack();
          if (canGoBack) {
            await currentTab.controller!.goBack();
            return false;
          }
        }

        if (state.tabs.length > 1) {
          state.closeTab(state.currentTabIndex);
          return false;
        } else {
          state.closeTab(state.currentTabIndex);
          return true;
        }
      },
      child: GestureDetector(
        onTap: () {
          _urlFocusNode.unfocus();
          FocusManager.instance.primaryFocus?.unfocus();
        },
        child: Scaffold(
        body: SafeArea(
          top: false, // App bar handles top safe area
          child: Column(
            children: [
              _buildCustomAppBar(context, state),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final parentWidth = constraints.maxWidth;
                    final parentHeight = constraints.maxHeight;
                    
                    if (_iconOffset == null) {
                      _iconOffset = Offset(parentWidth - 44 - 16, parentHeight - 80 - 16);
                    } else {
                      final x = _iconOffset!.dx.clamp(8.0, parentWidth - 44 - 8.0);
                      final y = _iconOffset!.dy.clamp(8.0, parentHeight - 44 - 8.0);
                      _iconOffset = Offset(x, y);
                    }
  
                    return Stack(
                      children: [
                        // Multi-Tab IndexedStack
                        IndexedStack(
                          index: state.currentTabIndex.clamp(0, state.tabs.isNotEmpty ? state.tabs.length - 1 : 0),
                          children: state.tabs.asMap().entries.map((entry) {
                            final tabIndex = entry.key;
                            final tab = entry.value;
                            final isTabHome = tab.url.isEmpty || tab.url == 'about:blank';

                            if (isTabHome) {
                              return KeyedSubtree(
                                key: tab.windowKey,
                                child: HomeDashboardWidget(onNavigate: _loadUrl),
                              );
                            }

                            return KeyedSubtree(
                              key: tab.windowKey,
                              child: Listener(
                                onPointerDown: (_) {
                                  if (_urlFocusNode.hasFocus) {
                                    _urlFocusNode.unfocus();
                                    FocusManager.instance.primaryFocus?.unfocus();
                                  }
                                },
                                child: InAppWebView(
                                  windowId: tab.windowId,
                                  pullToRefreshController: tab.pullToRefreshController ??= PullToRefreshController(
                                    settings: PullToRefreshSettings(
                                      color: const Color(0xFF00E5FF),
                                      backgroundColor: const Color(0xFF1E1E2C),
                                    ),
                                    onRefresh: () async {
                                      if (defaultTargetPlatform == TargetPlatform.android) {
                                        tab.controller?.reload();
                                      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
                                        tab.controller?.loadUrl(urlRequest: URLRequest(url: await tab.controller?.getUrl()));
                                      }
                                    },
                                  ),
                                  initialUrlRequest: URLRequest(url: WebUri(tab.url.isEmpty ? 'about:blank' : tab.url)),
                                  initialSettings: InAppWebViewSettings(
                                    thirdPartyCookiesEnabled: true,
                                    domStorageEnabled: true,
                                    databaseEnabled: true,
                                    javaScriptEnabled: true,
                                    mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                                    userAgent: state.currentUserAgent == 'Default Android Chrome'
                                        ? state.sanitizedNativeUserAgent
                                        : state.currentUserAgent,
                                    supportMultipleWindows: true,
                                    javaScriptCanOpenWindowsAutomatically: true,
                                    disableContextMenu: false,
                                    supportZoom: true,
                                  ),
                                  onLongPressHitTestResult: (controller, hitTestResult) async {
                                    final type = hitTestResult.type;
                                    final url = hitTestResult.extra;
                                    final isAnchorType = type == InAppWebViewHitTestResultType.SRC_ANCHOR_TYPE ||
                                        type == InAppWebViewHitTestResultType.SRC_IMAGE_ANCHOR_TYPE;
                                    final isUrl = url != null && (url.startsWith('http://') || url.startsWith('https://') || url.startsWith('www.'));
                                    if ((isAnchorType || isUrl) && url != null && url.isNotEmpty) {
                                        if (!context.mounted) return;
                                        showModalBottomSheet(
                                          context: context,
                                          backgroundColor: Colors.transparent,
                                          builder: (sheetContext) => Container(
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1E1E2C).withValues(alpha: 0.95),
                                              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                              border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.3), width: 1),
                                            ),
                                            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 40,
                                                  height: 4,
                                                  decoration: BoxDecoration(
                                                    color: Colors.white24,
                                                    borderRadius: BorderRadius.circular(2),
                                                  ),
                                                ),
                                                const SizedBox(height: 16),
                                                Text(
                                                  url,
                                                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                                                  maxLines: 2,
                                                  overflow: TextOverflow.ellipsis,
                                                  textAlign: TextAlign.center,
                                                ),
                                                const SizedBox(height: 16),
                                                const Divider(color: Colors.white10),
                                                ListTile(
                                                  leading: const Icon(Icons.add_to_photos, color: Color(0xFF00E5FF)),
                                                  title: const Text('Open in New Tab', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                                  onTap: () {
                                                    Navigator.pop(sheetContext);
                                                    state.addNewTab(url: url);
                                                  },
                                                ),
                                                ListTile(
                                                  leading: const Icon(Icons.copy, color: Color(0xFFE040FB)),
                                                  title: const Text('Copy Link Address', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                                  onTap: () {
                                                    Navigator.pop(sheetContext);
                                                    Clipboard.setData(ClipboardData(text: url));
                                                    if (context.mounted) {
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(
                                                          content: const Text('Link copied'),
                                                          backgroundColor: const Color(0xFF1E1E2C),
                                                          behavior: SnackBarBehavior.floating,
                                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                                        ),
                                                      );
                                                    }
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    initialUserScripts: UnmodifiableListView<UserScript>([
                                    UserScript(
                                      source: _generateMasterHookScript(state),
                                      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                                    ),
                                  ]),
                                  onWebViewCreated: (controller) {
                                    state.updateTabState(tabIndex, controller: controller);
                                    controller.addJavaScriptHandler(handlerName: 'getHighScore', callback: (args) async {
                                      final prefs = await SharedPreferences.getInstance();
                                      return prefs.getInt('ditto_game_high_score') ?? 0;
                                    });
                                    controller.addJavaScriptHandler(handlerName: 'saveHighScore', callback: (args) async {
                                      if (args.isNotEmpty) {
                                        final val = int.tryParse(args[0].toString()) ?? 0;
                                        final prefs = await SharedPreferences.getInstance();
                                        await prefs.setInt('ditto_game_high_score', val);
                                      }
                                    });
                                    controller.addJavaScriptHandler(handlerName: 'reloadSite', callback: (args) async {
                                      String? targetUrl;
                                      if (args.isNotEmpty && args[0] != null && args[0].toString().isNotEmpty) {
                                        targetUrl = args[0].toString();
                                      }
                                      if (targetUrl != null && !targetUrl.contains('DittoGame.html') && !targetUrl.contains('DittoNet.html')) {
                                        await controller.loadUrl(urlRequest: URLRequest(url: WebUri(targetUrl)));
                                      } else if (await controller.canGoBack()) {
                                        await controller.goBack();
                                      } else {
                                        await controller.loadUrl(urlRequest: URLRequest(url: WebUri('https://google.com')));
                                      }
                                    });
                                    controller.addJavaScriptHandler(handlerName: 'interceptPostPayload', callback: (args) async {
                                      if (args.isEmpty || args[0] == null) return null;
                                      final data = args[0] as Map<dynamic, dynamic>;
                                      final urlStr = data['url']?.toString() ?? '';
                                      final method = data['method']?.toString().toUpperCase() ?? 'POST';
                                      final rawHeaders = data['headers'] as Map<dynamic, dynamic>? ?? {};
                                      final headers = rawHeaders.map((k, v) => MapEntry(k.toString(), v.toString()));
                                      final bodyStr = data['body']?.toString() ?? '';
                                      final isFormSubmit = data['isFormSubmit'] == true;

                                      final interceptor = context.read<InterceptorCore>();
                                      final res = await interceptor.interceptPostPayload(
                                        urlStr: urlStr,
                                        method: method,
                                        headers: headers,
                                        bodyPayload: bodyStr,
                                        isMainFrame: isFormSubmit,
                                      );

                                      if (res == null) return null;

                                      String decodedBody = '';
                                      if (res.data != null) {
                                        try {
                                          decodedBody = utf8.decode(res.data!, allowMalformed: true);
                                        } catch (_) {}
                                      }

                                      return {
                                        'statusCode': res.statusCode ?? 200,
                                        'reasonPhrase': (res.reasonPhrase == null || res.reasonPhrase!.trim().isEmpty) ? 'OK' : res.reasonPhrase!,
                                        'headers': res.headers ?? {},
                                        'body': decodedBody,
                                        'redirectUrl': (res.statusCode == 301 || res.statusCode == 302 || res.statusCode == 303 || res.statusCode == 307 || res.statusCode == 308)
                                            ? (res.headers?['location'] ?? res.headers?['Location'])
                                            : null,
                                      };
                                    });
                                  },
                                  onCreateWindow: (controller, createWindowAction) async {
                                    state.addNewTab(url: 'Loading...', windowId: createWindowAction.windowId);
                                    return true;
                                  },
                                  onCloseWindow: (controller) {
                                    state.closeTab(tabIndex);
                                  },
                                  onReceivedServerTrustAuthRequest: (controller, challenge) async {
                                    if (context.read<BrowserState>().isSslBypassEnabled) {
                                      return ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.PROCEED);
                                    }
                                    return ServerTrustAuthResponse(action: ServerTrustAuthResponseAction.CANCEL);
                                  },
                                  onLoadStart: (controller, url) async {
                                    _keepNavbarVisible();
                                    if (url != null) {
                                      if (tabIndex == state.currentTabIndex) {
                                        urlController.text = url.toString();
                                      }
                                      context.read<BrowserState>().updateBrowserState(url: url.toString());
                                    }
                                    await _updateNavigationState(controller);
                                  },
                                  onScrollChanged: (controller, x, y) {
                                    _keepNavbarVisible();
                                    if (_urlFocusNode.hasFocus) {
                                      _urlFocusNode.unfocus();
                                      FocusManager.instance.primaryFocus?.unfocus();
                                    }
                                  },
                                  onProgressChanged: (controller, progress) {
                                    if (progress == 100) tab.pullToRefreshController?.endRefreshing();
                                    if (tabIndex == state.currentTabIndex) {
                                      context.read<BrowserState>().updateBrowserState(progress: progress / 100.0);
                                    }
                                  },
                                  onUpdateVisitedHistory: (controller, url, isReload) async {
                                    if (url != null) {
                                      String title = await controller.getTitle() ?? url.toString();
                                      state.updateTabState(tabIndex, url: url.toString(), title: title);
                                      if (context.mounted) {
                                        context.read<BrowserState>().addHistoryItem(url.toString(), title);
                                      }
                                    }
                                    await _updateNavigationState(controller);
                                  },
                                  onTitleChanged: (controller, title) {
                                    if (title != null && title.isNotEmpty) {
                                      state.updateTabState(tabIndex, title: title);
                                    }
                                  },
                                  onLoadStop: (controller, url) async {
                                    tab.pullToRefreshController?.endRefreshing();
                                    await controller.evaluateJavascript(source: "document.body.style.paddingBottom = '85px';");
                                    final browserState = context.read<BrowserState>();
                                    if (browserState.isDevToolsEnabled) {
                                      try {
                                        final engine = browserState.devToolsEngine;
                                        final checkVar = engine == 'eruda' ? 'window.eruda' : 'window.VConsole';
                                        final isLoaded = await controller.evaluateJavascript(source: "typeof $checkVar !== 'undefined';");
                                        if (isLoaded != true) {
                                          final scriptContent = await DevToolsManager.getDevToolsScript(engine);
                                          await controller.evaluateJavascript(source: scriptContent);
                                        }
                                          final initCall = engine == 'eruda'
                                              ? '''
                                                if (window.eruda && !window.__eruda_inited) {
                                                  eruda.init();
                                                  window.__eruda_inited = true;
                                                }
                                                setTimeout(function() {
                                                  try {
                                                    var el = document.querySelector('#eruda');
                                                    var root = el && (el.shadowRoot || el._shadowRoot);
                                                    if (root && !window.__eruda_fonts_fixed) {
                                                      window.__eruda_fonts_fixed = true;
                                                      var cssRules = `
                                                        @font-face { font-family: "eruda-icon"; src: url("/__dittonet_devtools_font__/eruda-icon.woff") format("woff"); }
                                                        @font-face { font-family: "luna-tab-icon"; src: url("/__dittonet_devtools_font__/luna-tab-icon.woff") format("woff"); }
                                                        @font-face { font-family: "luna-console-icon"; src: url("/__dittonet_devtools_font__/luna-console-icon.woff") format("woff"); }
                                                        @font-face { font-family: "luna-object-viewer-icon"; src: url("/__dittonet_devtools_font__/luna-object-viewer-icon.woff") format("woff"); }
                                                        @font-face { font-family: "luna-dom-viewer-icon"; src: url("/__dittonet_devtools_font__/luna-dom-viewer-icon.woff") format("woff"); }
                                                        @font-face { font-family: "luna-data-grid-icon"; src: url("/__dittonet_devtools_font__/luna-data-grid-icon.woff") format("woff"); }
                                                        @font-face { font-family: "luna-modal-icon"; src: url("/__dittonet_devtools_font__/luna-modal-icon.woff") format("woff"); }
                                                        @font-face { font-family: "luna-notification-icon"; src: url("/__dittonet_devtools_font__/luna-notification-icon.woff") format("woff"); }
                                                        @font-face { font-family: "luna-text-viewer-icon"; src: url("/__dittonet_devtools_font__/luna-text-viewer-icon.woff") format("woff"); }

                                                        [class*="eruda-icon"] { font-family: "eruda-icon" !important; display: inline-block !important; font-style: normal !important; -webkit-font-smoothing: antialiased !important; }
                                                        [class*="luna-tab-icon"] { font-family: "luna-tab-icon" !important; display: inline-block !important; font-style: normal !important; -webkit-font-smoothing: antialiased !important; }
                                                        [class*="luna-console-icon"] { font-family: "luna-console-icon" !important; display: inline-block !important; font-style: normal !important; -webkit-font-smoothing: antialiased !important; }
                                                        [class*="luna-object-viewer-icon"] { font-family: "luna-object-viewer-icon" !important; display: inline-block !important; font-style: normal !important; -webkit-font-smoothing: antialiased !important; }
                                                        [class*="luna-dom-viewer-icon"] { font-family: "luna-dom-viewer-icon" !important; display: inline-block !important; font-style: normal !important; -webkit-font-smoothing: antialiased !important; }
                                                        [class*="luna-data-grid-icon"] { font-family: "luna-data-grid-icon" !important; display: inline-block !important; font-style: normal !important; -webkit-font-smoothing: antialiased !important; }
                                                        [class*="luna-modal-icon"] { font-family: "luna-modal-icon" !important; display: inline-block !important; font-style: normal !important; -webkit-font-smoothing: antialiased !important; }
                                                        [class*="luna-notification-icon"] { font-family: "luna-notification-icon" !important; display: inline-block !important; font-style: normal !important; -webkit-font-smoothing: antialiased !important; }
                                                        [class*="luna-text-viewer-icon"] { font-family: "luna-text-viewer-icon" !important; display: inline-block !important; font-style: normal !important; -webkit-font-smoothing: antialiased !important; }
                                                      `;
                                                      var docStyle = document.createElement('style');
                                                      docStyle.textContent = cssRules;
                                                      (document.head || document.documentElement).appendChild(docStyle);
                                                      var rootStyle = document.createElement('style');
                                                      rootStyle.textContent = cssRules;
                                                      root.appendChild(rootStyle);
                                                    }
                                                  } catch(e) {}
                                                }, 200);
                                              '''
                                              : 'if (window.VConsole && !window.__vconsole_inited) { window.__vconsole_inited = new VConsole(); }';
                                          await controller.evaluateJavascript(source: initCall);
                                        } catch (e) {
                                          print("Failed to inject DevTools: $e");
                                        }
                                      }
                                      await _updateNavigationState(controller);
                                    },
                                  onReceivedError: (controller, request, error) async {
                                    if (request.isForMainFrame ?? true) {
                                      final failedUrl = request.url.toString();
                                      if (!failedUrl.contains('DittoGame.html') && !failedUrl.contains('DittoNet.html')) {
                                        final encodedUrl = Uri.encodeComponent(failedUrl);
                                        await controller.loadUrl(
                                          urlRequest: URLRequest(url: WebUri('file:///android_asset/flutter_assets/assets/DittoGame.html?failed_url=$encodedUrl'))
                                        );
                                      }
                                    }
                                  },
                                  shouldInterceptRequest: (controller, request) async {
                                    try {
                                      final urlStr = request.url.toString();

                                      if (urlStr.contains('/__dittonet_devtools_font__/')) {
                                        try {
                                          final fontName = urlStr.split('/__dittonet_devtools_font__/')[1].split('.woff')[0];
                                          final fontBytes = DevToolsManager.erudaFonts[fontName];
                                          if (fontBytes != null) {
                                            return WebResourceResponse(
                                              contentType: 'application/x-font-woff',
                                              contentEncoding: '',
                                              statusCode: 200,
                                              reasonPhrase: 'OK',
                                              headers: {'Access-Control-Allow-Origin': '*'},
                                              data: fontBytes,
                                            );
                                          }
                                        } catch (_) {}
                                      }
                                      return await interceptor.interceptRequest(request);
                                    } catch (e) {
                                      print("Fatal intercept error: $e");
                                      return null;
                                    }
                                  },
                                  onPermissionRequest: (controller, request) async {
                                    final browserState = context.read<BrowserState>();
                                    String host = "";
                                    try {
                                      host = request.origin.host;
                                    } catch (_) {}
                                    if (host.isEmpty) {
                                      host = browserState.getHostFromUrl(browserState.currentUrl);
                                    }
                                    final sitePerm = browserState.getPermissionsForHost(host);
                                    if (!sitePerm.allowCameraMic) {
                                      return PermissionResponse(resources: request.resources, action: PermissionResponseAction.DENY);
                                    }
                                    bool osGranted = true;
                                    if (request.resources.contains(PermissionResourceType.CAMERA) || request.resources.contains(PermissionResourceType.CAMERA_AND_MICROPHONE)) {
                                      final s = await Permission.camera.request();
                                      if (!s.isGranted) osGranted = false;
                                    }
                                    if (request.resources.contains(PermissionResourceType.MICROPHONE) || request.resources.contains(PermissionResourceType.CAMERA_AND_MICROPHONE)) {
                                      final s = await Permission.microphone.request();
                                      if (!s.isGranted) osGranted = false;
                                    }
                                    if (osGranted) {
                                      return PermissionResponse(resources: request.resources, action: PermissionResponseAction.GRANT);
                                    }
                                    return PermissionResponse(resources: request.resources, action: PermissionResponseAction.DENY);
                                  },
                                  onGeolocationPermissionsShowPrompt: (controller, origin) async {
                                    final browserState = context.read<BrowserState>();
                                    final host = browserState.getHostFromUrl(origin);
                                    final sitePerm = browserState.getPermissionsForHost(host);
                                    if (!sitePerm.allowLocation) {
                                      return GeolocationPermissionShowPromptResponse(origin: origin, allow: false, retain: true);
                                    }
                                    final status = await Permission.location.request();
                                    return GeolocationPermissionShowPromptResponse(origin: origin, allow: status.isGranted, retain: true);
                                  },
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        if (!isHome) ...[
                        // Sleek Low-Glare Frosted Back Swipe Indicator
                        ValueListenableBuilder<double>(
                          valueListenable: _backSwipeNotifier,
                          builder: (context, val, _) {
                            if (val <= 0) return const SizedBox.shrink();
                            return Positioned(
                              left: 12,
                              top: parentHeight / 2 - 24,
                              child: Container(
                                width: (val * 0.9).clamp(36.0, 56.0),
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF181824).withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4)),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                                ),
                              ),
                            );
                          },
                        ),
                        // Sleek Low-Glare Frosted Forward Swipe Indicator
                        ValueListenableBuilder<double>(
                          valueListenable: _forwardSwipeNotifier,
                          builder: (context, val, _) {
                            if (val <= 0) return const SizedBox.shrink();
                            return Positioned(
                              right: 12,
                              top: parentHeight / 2 - 24,
                              child: Container(
                                width: (val * 0.9).clamp(36.0, 56.0),
                                height: 48,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF181824).withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4)),
                                  ],
                                ),
                                child: const Center(
                                  child: Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 20),
                                ),
                              ),
                            );
                          },
                        ),
                        // Zero-Lag Left Edge Swipe Touch Zone
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 100,
                          width: 20,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onHorizontalDragStart: (_) => _backSwipeNotifier.value = 10.0,
                            onHorizontalDragUpdate: (details) {
                              final next = _backSwipeNotifier.value + details.delta.dx;
                              _backSwipeNotifier.value = next.clamp(0.0, 80.0);
                            },
                            onHorizontalDragEnd: (details) {
                              if (_backSwipeNotifier.value > 45 || details.primaryVelocity! > 250) {
                                webViewController?.goBack();
                              }
                              _backSwipeNotifier.value = 0.0;
                            },
                            onHorizontalDragCancel: () => _backSwipeNotifier.value = 0.0,
                          ),
                        ),
                        // Zero-Lag Right Edge Swipe Touch Zone
                        Positioned(
                          right: 0,
                          top: 0,
                          bottom: 100,
                          width: 20,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onHorizontalDragStart: (_) => _forwardSwipeNotifier.value = 10.0,
                            onHorizontalDragUpdate: (details) {
                              final next = _forwardSwipeNotifier.value - details.delta.dx;
                              _forwardSwipeNotifier.value = next.clamp(0.0, 80.0);
                            },
                            onHorizontalDragEnd: (details) {
                              if (_forwardSwipeNotifier.value > 45 || details.primaryVelocity! < -250) {
                                webViewController?.goForward();
                              }
                              _forwardSwipeNotifier.value = 0.0;
                            },
                            onHorizontalDragCancel: () => _forwardSwipeNotifier.value = 0.0,
                          ),
                        ),
                      ],
                        
                        // Glassmorphic Floating Bottom Navbar

                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: AnimatedScale(
                            scale: showFullNavbar ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutBack,
                            child: AnimatedOpacity(
                              opacity: showFullNavbar ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              child: IgnorePointer(
                                ignoring: !showFullNavbar,
                                child: _buildFloatingGlassNavbar(context, state),
                              ),
                            ),
                          ),
                        ),
  
                        // Draggable Shrunk Icon
                        Positioned(
                          left: _iconOffset!.dx,
                          top: _iconOffset!.dy,
                          child: AnimatedScale(
                            scale: showFullNavbar ? 0.0 : 1.0,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOutBack,
                            child: AnimatedOpacity(
                              opacity: showFullNavbar ? 0.0 : 1.0,
                              duration: const Duration(milliseconds: 200),
                              child: IgnorePointer(
                                ignoring: showFullNavbar,
                                child: _buildDraggableIcon(context, state),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                ),
              ),
            ],
          ),
        ),
      ),
    ));
  }

  Widget _buildCustomAppBar(BuildContext context, BrowserState state) {
    return Container(
      color: const Color(0xFF1E1E1E),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: Row(
                children: [
                  if (!_urlFocusNode.hasFocus) ...[
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                      color: state.canGoBack ? Colors.white70 : Colors.white24,
                      onPressed: state.canGoBack ? () => webViewController?.goBack() : null,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: RawAutocomplete<String>(
                      textEditingController: urlController,
                      focusNode: _urlFocusNode,
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (!_urlFocusNode.hasFocus || textEditingValue.text.isEmpty) {
                          return const Iterable<String>.empty();
                        }
                        final query = textEditingValue.text.toLowerCase();
                        final List<String> options = [];
                        
                        options.add('Search Google for: ${textEditingValue.text}');
                        
                        for (var b in state.bookmarks) {
                          if (b.title.toLowerCase().contains(query) || b.url.toLowerCase().contains(query)) {
                            options.add('BM|${b.title}|${b.url}');
                          }
                        }
                        
                        for (var h in state.visitedHistory) {
                          if (h.title.toLowerCase().contains(query) || h.url.toLowerCase().contains(query)) {
                            if (!options.any((o) => o.endsWith(h.url))) {
                              options.add('HI|${h.title}|${h.url}');
                            }
                          }
                        }
                        
                        return options.take(8);
                      },
                      onSelected: (String selection) {
                        _urlFocusNode.unfocus();
                        FocusManager.instance.primaryFocus?.unfocus();
                        if (selection.startsWith('Search Google for:')) {
                          final query = selection.replaceFirst('Search Google for: ', '');
                          _loadUrl('https://www.google.com/search?q=${Uri.encodeComponent(query)}');
                        } else {
                          final parts = selection.split('|');
                          if (parts.length >= 3) {
                            _loadUrl(parts.sublist(2).join('|'));
                          }
                        }
                      },
                      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          height: 40,
                          decoration: BoxDecoration(
                            color: _urlFocusNode.hasFocus ? const Color(0xFF2A2A38) : Colors.black26,
                            borderRadius: BorderRadius.circular(20),
                            border: _urlFocusNode.hasFocus ? Border.all(color: const Color(0xFF00E5FF), width: 1.5) : null,
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: () => showSiteSecuritySheet(context, webViewController, state.currentUrl),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                                  child: Icon(Icons.lock, size: 16, color: state.currentUrl.startsWith('https') ? Colors.green : Colors.grey),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: TextField(
                                  controller: controller,
                                  focusNode: focusNode,
                                  style: const TextStyle(fontSize: 14),
                                  decoration: const InputDecoration(
                                    hintText: 'Search or enter URL',
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                                  ),
                                  onSubmitted: (value) {
                                    onFieldSubmitted();
                                    _urlFocusNode.unfocus();
                                    FocusManager.instance.primaryFocus?.unfocus();
                                    _loadUrl(value);
                                  },
                                ),
                              ),
                              if (_urlFocusNode.hasFocus) ...[
                                if (controller.text.isNotEmpty)
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    icon: const Icon(Icons.clear, size: 18, color: Colors.white70),
                                    onPressed: () {
                                      controller.clear();
                                    },
                                  ),
                              ] else ...[
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                                  padding: EdgeInsets.zero,
                                  icon: Icon(
                                    state.isBookmarked(state.currentUrl) ? Icons.star : Icons.star_border,
                                    color: state.isBookmarked(state.currentUrl) ? Colors.amber : Colors.grey,
                                    size: 18
                                  ),
                                  onPressed: () async {
                                    if (state.currentUrl.isNotEmpty && state.currentUrl != 'about:blank') {
                                      String title = "Saved Page";
                                      if (!state.isBookmarked(state.currentUrl)) {
                                         title = await webViewController?.getTitle() ?? state.currentUrl;
                                      }
                                      if (context.mounted) {
                                         state.toggleBookmark(state.currentUrl, title);
                                         ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                           content: Text(state.isBookmarked(state.currentUrl) ? 'Added to Bookmarks' : 'Removed from Bookmarks'),
                                           duration: const Duration(seconds: 1),
                                           backgroundColor: Colors.teal,
                                         ));
                                      }
                                    }
                                  },
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.refresh, size: 18),
                                  onPressed: () {
                                    if (state.currentUrl.isEmpty || state.currentUrl == 'about:blank') return;
                                    webViewController?.reload();
                                  },
                                ),
                              ],
                              const SizedBox(width: 4),
                            ],
                          ),
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6.0),
                            child: Material(
                              elevation: 12,
                              color: const Color(0xFF2C2C2C),
                              borderRadius: BorderRadius.circular(16),
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width - 64,
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(maxHeight: 320),
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  shrinkWrap: true,
                                  itemCount: options.length,
                                  itemBuilder: (context, index) {
                                    final option = options.elementAt(index);
                                    IconData icon = Icons.search;
                                    Color iconColor = Colors.grey;
                                    String title = option;
                                    String? subtitle;
                                    
                                    if (option.startsWith('BM|')) {
                                      icon = Icons.star;
                                      iconColor = Colors.amber;
                                      final parts = option.split('|');
                                      title = parts[1];
                                      subtitle = parts.sublist(2).join('|');
                                    } else if (option.startsWith('HI|')) {
                                      icon = Icons.history;
                                      final parts = option.split('|');
                                      title = parts[1];
                                      subtitle = parts.sublist(2).join('|');
                                    }
                                    
                                    return ListTile(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                      visualDensity: VisualDensity.compact,
                                      leading: Icon(icon, color: iconColor, size: 20),
                                      title: Text(
                                        title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 14, color: Colors.white),
                                      ),
                                      subtitle: subtitle != null
                                          ? Text(
                                              subtitle,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 11, color: Colors.white54),
                                            )
                                          : null,
                                      onTap: () {
                                        _urlFocusNode.unfocus();
                                        FocusManager.instance.primaryFocus?.unfocus();
                                        onSelected(option);
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ));
                      },
                    ),
                  ),
                  if (!_urlFocusNode.hasFocus) ...[
                    const SizedBox(width: 4),
                    _buildTabCounterButton(state),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                      padding: EdgeInsets.zero,
                      icon: state.isRecordingTraffic
                          ? Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.redAccent.withValues(alpha: 0.6), blurRadius: 8, spreadRadius: 2)],
                              ),
                              child: const Icon(Icons.radio_button_checked, color: Colors.redAccent, size: 20),
                            )
                          : const Icon(Icons.radio_button_checked, color: Colors.grey, size: 20),
                      tooltip: state.isRecordingTraffic ? 'Recording Traffic (Tap to Stop & Export HAR)' : 'Record Traffic (HAR)',
                      onPressed: () {
                        bool wasRecording = state.isRecordingTraffic;
                        state.toggleRecording(); // Flips the state boolean

                        if (wasRecording) {
                          if (state.recordedHarEntries.isNotEmpty) {
                            HarManager.showExportModal(context, state);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No traffic recorded in this session.')));
                          }
                        } else {
                          state.clearHarEntries();
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recording network traffic...')));
                        }
                      },
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.arrow_forward_ios, size: 18),
                      color: state.canGoForward ? Colors.white70 : Colors.white24,
                      onPressed: state.canGoForward ? () => webViewController?.goForward() : null,
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
                      padding: EdgeInsets.zero,
                      icon: _buildGlowingDot(state.connectionStatus),
                      onPressed: _showConnectionDialog,
                    ),
                  ] else ...[
                    const SizedBox(width: 6),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        _urlFocusNode.unfocus();
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                      child: const Text('Cancel', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ],
              ),
            ),
            // Micro Progress Indicator
            AnimatedOpacity(
              opacity: (state.loadingProgress > 0.0 && state.loadingProgress < 1.0) ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 300),
              child: LinearProgressIndicator(
                value: state.loadingProgress,
                minHeight: 2,
                backgroundColor: Colors.transparent,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.tealAccent),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildGlowingDot(ConnectionStatus status) {
    Color color;
    switch (status) {
      case ConnectionStatus.green: color = Colors.greenAccent; break;
      case ConnectionStatus.yellow: color = Colors.amberAccent; break;
      case ConnectionStatus.red: color = Colors.redAccent; break;
    }

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.6),
            blurRadius: 8,
            spreadRadius: 2,
          )
        ]
      ),
    );
  }

  Widget _buildFloatingGlassNavbar(BuildContext context, BrowserState state) {
    return SafeArea(
      top: false,
      bottom: true,
      child: Padding(
        padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
        child: Listener(
          onPointerDown: (_) => _keepNavbarVisible(),
          child: _buildFullNavbar(context, state),
        ),
      ),
    );
  }

  Widget _buildFullNavbar(BuildContext context, BrowserState state) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
              height: 65,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.bookmarks_outlined, size: 24),
                    color: Colors.white70,
                    onPressed: _openBookmarksSheet,
                  ),
                  IconButton(
                    icon: const Icon(Icons.history_rounded, size: 24),
                    color: Colors.white70,
                    onPressed: _openHistorySheet,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: FloatingActionButton(
                      mini: false,
                      elevation: 8,
                      backgroundColor: Colors.tealAccent,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      onPressed: () {
                         final state = context.read<BrowserState>();
                         state.updateBrowserState(url: '');
                         state.updateTabState(state.currentTabIndex, url: '', controller: null);
                         urlController.clear();
                         _showNavbarManually();
                      },
                      child: const Icon(Icons.home_rounded, size: 28),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.list_alt_rounded, size: 24),
                    color: Colors.white70,
                    onPressed: _openLogsWindow,
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings_outlined, size: 24),
                    color: Colors.white70,
                    onPressed: _openSettingsWindow,
                  ),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildDraggableIcon(BuildContext context, BrowserState state) {
    return GestureDetector(
      onLongPressStart: (details) {
        _dragStartOffset = details.globalPosition;
        _dragStartIconOffset = _iconOffset;
        setState(() {
          _isDragging = true;
        });
      },
      onLongPressMoveUpdate: (details) {
        if (_dragStartOffset != null && _dragStartIconOffset != null) {
          final delta = details.globalPosition - _dragStartOffset!;
          setState(() {
            final newOffset = _dragStartIconOffset! + delta;
            final RenderBox? stackRenderBox = context.findAncestorRenderObjectOfType<RenderBox>();
            if (stackRenderBox != null) {
              final parentSize = stackRenderBox.size;
              final x = newOffset.dx.clamp(8.0, parentSize.width - 44 - 8.0);
              final y = newOffset.dy.clamp(8.0, parentSize.height - 44 - 8.0);
              _iconOffset = Offset(x, y);
            } else {
              _iconOffset = newOffset;
            }
          });
        }
      },
      onLongPressEnd: (details) {
        _dragStartOffset = null;
        _dragStartIconOffset = null;
        setState(() {
          _isDragging = false;
        });
      },
      onTap: _showNavbarManually,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 44,
        transform: Matrix4.diagonal3Values(_isDragging ? 1.15 : 1.0, _isDragging ? 1.15 : 1.0, 1.0),
        transformAlignment: Alignment.center,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: _isDragging 
                    ? Colors.tealAccent.withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: 0.35),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _isDragging 
                      ? Colors.tealAccent.withValues(alpha: 0.6) 
                      : Colors.white.withValues(alpha: 0.15),
                  width: _isDragging ? 1.5 : 1.0,
                ),
                boxShadow: _isDragging ? [
                  BoxShadow(
                    color: Colors.tealAccent.withValues(alpha: 0.3),
                    blurRadius: 12,
                    spreadRadius: 2,
                  )
                ] : null,
              ),
              child: Icon(
                Icons.menu,
                color: _isDragging ? Colors.tealAccent : Colors.white70,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
