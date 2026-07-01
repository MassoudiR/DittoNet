import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/traffic_log.dart';
import '../models/bookmark.dart';
import '../models/history_item.dart';
import '../core/models/hook_script.dart';
import '../core/models/local_rule.dart';
import '../core/models/site_permission.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import '../core/models/browser_tab.dart';



enum ConnectionStatus { green, yellow, red }

class BrowserState extends ChangeNotifier {
  final SharedPreferences prefs;

  // --- Connection Configuration ---
  late String backendIp;
  late int backendPort;
  late bool isLocalMode;
  late int heartbeatIntervalSeconds;

  // --- Connection Status ---
  ConnectionStatus connectionStatus = ConnectionStatus.red;
  int currentLatencyMs = 0;

  // --- Browser State ---
  String currentUrl = ''; // Start empty to show Home Dashboard
  double loadingProgress = 0.0;
  bool canGoBack = false;
  bool canGoForward = false;
  late String currentUserAgent;
  late bool isDevToolsEnabled;
  late String devToolsEngine;
  
  // --- Quick Links & Bookmarks ---
  List<BookmarkItem> bookmarks = [];

  // --- History ---
  List<HistoryItem> visitedHistory = [];

  // --- Logs ---
  List<TrafficLog> trafficLogs = [];

  // --- JS Hooking Scripts ---
  List<HookScript> _hookScripts = [];
  List<HookScript> get hookScripts => _hookScripts;

  // --- Local Standalone Rule Engine ---
  bool get isLocalEngineEnabled => isLocalMode;
  List<LocalRule> _localRules = [];
  List<LocalRule> get localRules => _localRules;
  // --- Proxy Chaining & SSL Bypass ---
  bool _isExternalProxyEnabled = false;
  bool get isExternalProxyEnabled => _isExternalProxyEnabled;
  String _externalProxyHost = '192.168.1.100';
  String get externalProxyHost => _externalProxyHost;
  String _externalProxyPort = '8080';
  String get externalProxyPort => _externalProxyPort;
  bool _isSslBypassEnabled = false;
  bool get isSslBypassEnabled => _isSslBypassEnabled;

  // --- Workspace Sync ---
  String? _lastSyncedTimestamp;
  String? get lastSyncedTimestamp => _lastSyncedTimestamp;
  String get magicServerUrl => 'http://$backendIp:$backendPort';

  // --- HAR Recording & Throttling ---
  bool _isRecordingTraffic = false;
  bool get isRecordingTraffic => _isRecordingTraffic;

  final List<Map<String, dynamic>> _recordedHarEntries = [];
  List<Map<String, dynamic>> get recordedHarEntries => List.unmodifiable(_recordedHarEntries);

  int _networkThrottleMs = 0;
  int get networkThrottleMs => _networkThrottleMs;

  // --- Site Permissions (Per-Origin) ---
  Map<String, SitePermission> _sitePermissions = {};

  // --- Multi-Tab State ---
  final _uuid = const Uuid();
  final List<BrowserTab> _tabs = [];
  int _currentTabIndex = 0;

  List<BrowserTab> get tabs => _tabs;
  int get currentTabIndex => _currentTabIndex;
  BrowserTab? get currentTab => _tabs.isNotEmpty && _currentTabIndex < _tabs.length ? _tabs[_currentTabIndex] : null;

  void _saveTabsToPrefs() {
    try {
      final tabsList = _tabs.map((t) => jsonEncode(t.toJson())).toList();
      prefs.setStringList('saved_browser_tabs', tabsList);
      prefs.setInt('saved_current_tab_index', _currentTabIndex);
    } catch (_) {}
  }

  void _initTabs() {
    final savedTabs = prefs.getStringList('saved_browser_tabs');
    final savedIndex = prefs.getInt('saved_current_tab_index') ?? 0;
    if (savedTabs != null && savedTabs.isNotEmpty) {
      try {
        _tabs.clear();
        for (final tabStr in savedTabs) {
          final decoded = jsonDecode(tabStr) as Map<String, dynamic>;
          _tabs.add(BrowserTab.fromJson(decoded));
        }
        if (_tabs.isNotEmpty) {
          _currentTabIndex = savedIndex.clamp(0, _tabs.length - 1);
          currentUrl = _tabs[_currentTabIndex].url;
          return;
        }
      } catch (_) {}
    }
    _initDefaultTab();
  }

  void _initDefaultTab() {
    if (_tabs.isEmpty) {
      _tabs.add(BrowserTab(id: _uuid.v4(), url: '', title: 'Home Dashboard'));
      _currentTabIndex = 0;
      currentUrl = '';
      _saveTabsToPrefs();
    }
  }

  BrowserState(this.prefs) {
    _loadState();
    _initTabs();
  }

  void _loadState() {
    backendIp = prefs.getString('backendIp') ?? '';
    backendPort = prefs.getInt('backendPort') ?? 5000;
    isLocalMode = prefs.getBool('isLocalMode') ?? false;
    heartbeatIntervalSeconds = 3;
    currentUserAgent = prefs.getString('currentUserAgent') ?? 'Default Android Chrome';
    isDevToolsEnabled = prefs.getBool('isDevToolsEnabled') ?? false;
    devToolsEngine = prefs.getString('devToolsEngine') ?? 'eruda';
    _isExternalProxyEnabled = prefs.getBool('isExternalProxyEnabled') ?? false;
    _externalProxyHost = prefs.getString('externalProxyHost') ?? '192.168.1.100';
    _externalProxyPort = prefs.getString('externalProxyPort') ?? '8080';
    _isSslBypassEnabled = prefs.getBool('isSslBypassEnabled') ?? false;
    _lastSyncedTimestamp = prefs.getString('lastSyncedTimestamp');
    _networkThrottleMs = prefs.getInt('networkThrottleMs') ?? 0;
    final sitePermsStr = prefs.getString('sitePermissionsJson');
    if (sitePermsStr != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(sitePermsStr);
        _sitePermissions = decoded.map((k, v) => MapEntry(k, SitePermission.fromJson(v)));
      } catch (_) {}
    }
    
    final bookmarksJson = prefs.getString('bookmarks') ?? prefs.getString('quickLinks');
    if (bookmarksJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(bookmarksJson);
        bookmarks = decoded.map((e) => BookmarkItem.fromJson(e)).toList();
        if (bookmarks.isNotEmpty && bookmarks.first.title == 'Google') {
          bookmarks[0] = BookmarkItem(title: 'DittoNet doc', url: 'file:///android_asset/flutter_assets/assets/DittoNet.html');
          _saveBookmarks();
        }
      } catch (e) {
        _setDefaultBookmarks();
      }
    } else {
      _setDefaultBookmarks();
    }

    final historyJson = prefs.getString('visitedHistory');
    if (historyJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(historyJson);
        visitedHistory = decoded.map((e) => HistoryItem.fromJson(e)).toList();
      } catch (e) {
        visitedHistory = [];
      }
    }

    final hookScriptsJson = prefs.getString('hook_scripts');
    if (hookScriptsJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(hookScriptsJson);
        _hookScripts = decoded.map((e) => HookScript.fromJson(e)).toList();
      } catch (e) {
        _setDefaultHookScripts();
      }
    } else {
      _setDefaultHookScripts();
    }
    if (_hookScripts.isEmpty) {
      _setDefaultHookScripts();
    }

    final localRulesJson = prefs.getString('local_rules_list');

    if (localRulesJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(localRulesJson);
        _localRules = decoded.map((e) => LocalRule.fromJson(e)).toList();
      } catch (e) {
        _setDefaultLocalRules();
      }
    } else {
      _setDefaultLocalRules();
    }
  }



  void _setDefaultBookmarks() {
    bookmarks = [
      BookmarkItem(title: 'DittoNet doc', url: 'file:///android_asset/flutter_assets/assets/DittoNet.html'),
      BookmarkItem(title: 'GitHub', url: 'https://github.com'),
      BookmarkItem(title: 'HackerNews', url: 'https://news.ycombinator.com'),
    ];
  }

  // --- Actions ---

  void updateConnectionConfig(String ip, int port, bool localMode) {
    backendIp = ip;
    backendPort = port;
    isLocalMode = localMode;
    prefs.setString('backendIp', ip);
    prefs.setInt('backendPort', port);
    prefs.setBool('isLocalMode', localMode);
    notifyListeners();
  }

  void toggleSslBypass(bool value) {
    _isSslBypassEnabled = value;
    prefs.setBool('isSslBypassEnabled', value);
    notifyListeners();
  }

  void saveProxySettings(bool enabled, String host, String port) {
    _isExternalProxyEnabled = enabled;
    _externalProxyHost = host;
    _externalProxyPort = port;
    prefs.setBool('isExternalProxyEnabled', enabled);
    prefs.setString('externalProxyHost', host);
    prefs.setString('externalProxyPort', port);
    notifyListeners();
  }

  void updateHeartbeatInterval(int seconds) {
    heartbeatIntervalSeconds = seconds;
    prefs.setInt('heartbeatIntervalSeconds', seconds);
    notifyListeners();
  }

  void updateConnectionStatus(ConnectionStatus status, int latency) {
    connectionStatus = status;
    currentLatencyMs = latency;
    notifyListeners();
  }

  void addNewTab({String url = '', String title = 'New Tab', int? windowId}) {
    currentTab?.controller?.pause();
    final newTab = BrowserTab(
      id: _uuid.v4(),
      url: url,
      title: title,
      windowId: windowId,
    );
    _tabs.add(newTab);
    _currentTabIndex = _tabs.length - 1;
    currentUrl = url;
    _saveTabsToPrefs();
    notifyListeners();
  }

  void switchTab(int index) {
    if (index < 0 || index >= _tabs.length || index == _currentTabIndex) return;
    _tabs[_currentTabIndex].controller?.pause();
    _currentTabIndex = index;
    _tabs[_currentTabIndex].controller?.resume();
    currentUrl = _tabs[_currentTabIndex].url;
    _tabs[_currentTabIndex].controller?.canGoBack().then((v) => canGoBack = v).catchError((_) => false);
    _tabs[_currentTabIndex].controller?.canGoForward().then((v) => canGoForward = v).catchError((_) => false);
    _saveTabsToPrefs();
    notifyListeners();
  }

  void closeTab(int index) {
    if (index < 0 || index >= _tabs.length) return;
    final tab = _tabs[index];
    tab.controller?.pause();
    _tabs.removeAt(index);
    if (_tabs.isEmpty) {
      _initDefaultTab();
    } else if (_currentTabIndex >= _tabs.length) {
      _currentTabIndex = _tabs.length - 1;
    } else if (index < _currentTabIndex) {
      _currentTabIndex--;
    }
    _tabs[_currentTabIndex].controller?.resume();
    currentUrl = _tabs[_currentTabIndex].url;
    _tabs[_currentTabIndex].controller?.canGoBack().then((v) => canGoBack = v).catchError((_) => false);
    _tabs[_currentTabIndex].controller?.canGoForward().then((v) => canGoForward = v).catchError((_) => false);
    _saveTabsToPrefs();
    notifyListeners();
  }

  void updateTabState(int index, {String? url, String? title, InAppWebViewController? controller, Uint8List? screenshot}) {
    if (index < 0 || index >= _tabs.length) return;
    final tab = _tabs[index];
    if (url != null) tab.url = url;
    if (title != null) tab.title = title;
    if (controller != null) tab.controller = controller;
    if (screenshot != null) tab.screenshot = screenshot;

    if (index == _currentTabIndex && url != null) {
      currentUrl = url;
    }
    if (url != null || title != null) {
      _saveTabsToPrefs();
    }
    notifyListeners();
  }

  void clearAllTabsAndKeys() {
    for (final tab in _tabs) {
      try {
        tab.pullToRefreshController?.dispose();
      } catch (_) {}
    }
    _tabs.clear();
    _currentTabIndex = 0;
  }

  void updateBrowserState({
    String? url,
    double? progress,
    bool? back,
    bool? forward,
  }) {
    if (url != null) {
      currentUrl = url;
      if (currentTab != null) currentTab!.url = url;
    }
    if (progress != null) loadingProgress = progress;
    if (back != null) canGoBack = back;
    if (forward != null) canGoForward = forward;
    notifyListeners();
  }

  void updateUserAgent(String ua) {
    currentUserAgent = ua;
    prefs.setString('currentUserAgent', ua);
    notifyListeners();
  }

  void toggleDevTools(bool enabled) {
    isDevToolsEnabled = enabled;
    prefs.setBool('isDevToolsEnabled', enabled);
    notifyListeners();
  }

  void updateDevToolsEngine(String engine) {
    devToolsEngine = engine;
    prefs.setString('devToolsEngine', engine);
    notifyListeners();
  }

  // --- Bookmarks Management ---
  bool isBookmarked(String url) {
    return bookmarks.any((b) => b.url == url);
  }

  void toggleBookmark(String url, String title) {
    if (isBookmarked(url)) {
      bookmarks.removeWhere((b) => b.url == url);
    } else {
      bookmarks.add(BookmarkItem(title: title, url: url));
    }
    _saveBookmarks();
    notifyListeners();
  }

  void addBookmark(BookmarkItem bookmark) {
    bookmarks.add(bookmark);
    _saveBookmarks();
    notifyListeners();
  }

  void updateBookmark(int index, BookmarkItem bookmark) {
    if (index >= 0 && index < bookmarks.length) {
      bookmarks[index] = bookmark;
      _saveBookmarks();
      notifyListeners();
    }
  }

  void removeBookmark(int index) {
    if (index >= 0 && index < bookmarks.length) {
      bookmarks.removeAt(index);
      _saveBookmarks();
      notifyListeners();
    }
  }

  void _saveBookmarks() {
    prefs.setString('bookmarks', jsonEncode(bookmarks.map((e) => e.toJson()).toList()));
  }

  // --- History Management ---
  void addHistoryItem(String url, String title) {
    // Avoid spamming history with rapid same-page updates or blanks
    if (url.isEmpty || url == 'about:blank') return;
    
    // Check if the most recent item is the exact same URL to prevent duplicates from rapid reloads
    if (visitedHistory.isNotEmpty && visitedHistory.first.url == url) {
      // Just update timestamp
      visitedHistory.first.timestamp = DateTime.now();
      _saveHistory();
      return;
    }

    visitedHistory.insert(0, HistoryItem(title: title, url: url, timestamp: DateTime.now()));
    
    // Enforce 500 item limit
    if (visitedHistory.length > 500) {
      visitedHistory = visitedHistory.sublist(0, 500);
    }
    
    _saveHistory();
    notifyListeners();
  }

  void removeHistoryItem(int index) {
    if (index >= 0 && index < visitedHistory.length) {
      visitedHistory.removeAt(index);
      _saveHistory();
      notifyListeners();
    }
  }

  void clearVisitedHistory() {
    visitedHistory.clear();
    _saveHistory();
    notifyListeners();
  }

  void _saveHistory() {
    prefs.setString('visitedHistory', jsonEncode(visitedHistory.map((e) => e.toJson()).toList()));
  }

  void addTrafficLog(TrafficLog log) {
    if (trafficLogs.length > 1000) {
      trafficLogs.removeAt(0);
    }
    trafficLogs.add(log);
    notifyListeners(); 
  }

  void clearLogs() {
    trafficLogs.clear();
    notifyListeners();
  }

  void _setDefaultHookScripts() {
    _hookScripts = [
      HookScript(
        id: 'default_1',
        name: 'Demo: Hello World Alert',
        targetPattern: '.*',
        code: 'alert("Hello from DittoNet Browser Monkey Patch!");',
        isActive: false,
        isDeletable: false,
      ),
    ];
    _saveHookScripts();
  }

  // --- JS Hooking Actions ---
  void addHookScript(HookScript script) {
    _hookScripts.add(script);
    _saveHookScripts();
    notifyListeners();
  }

  void updateHookScript(int index, HookScript script) {
    if (index >= 0 && index < _hookScripts.length) {
      _hookScripts[index] = script;
      _saveHookScripts();
      notifyListeners();
    }
  }

  void removeHookScript(int index) {
    if (index >= 0 && index < _hookScripts.length) {
      if (!_hookScripts[index].isDeletable) return;
      _hookScripts.removeAt(index);
      _saveHookScripts();
      notifyListeners();
    }
  }

  void toggleHookScript(int index, bool isActive) {
    if (index >= 0 && index < _hookScripts.length) {
      _hookScripts[index].isActive = isActive;
      _saveHookScripts();
      notifyListeners();
    }
  }

  void _saveHookScripts() {
    prefs.setString('hook_scripts', jsonEncode(_hookScripts.map((e) => e.toJson()).toList()));
  }

  // --- Local Rule Engine Actions ---
  void _setDefaultLocalRules() {
    _localRules = [
      LocalRule(
        id: 'preset_block_ads',
        name: 'Block Ads & Trackers',
        targetPattern: '*doubleclick.net*',
        phase: 'Request',
        actionType: 'BLOCK',
        method: 'ALL',
        isActive: false,
      ),
      LocalRule(
        id: 'preset_smart_redirect',
        name: 'Redirect Site',
        targetPattern: 'example.com',
        phase: 'Request',
        actionType: 'REDIRECT',
        replaceString: 'https://duckduckgo.com',
        method: 'GET',
        isActive: false,
      ),
      LocalRule(
        id: 'preset_header_auth',
        name: 'Inject Auth Header',
        targetPattern: '*api*',
        phase: 'Request',
        actionType: 'HEADER_INJECT',
        replaceString: 'Authorization: Bearer SampleToken_123',
        method: 'ALL',
        isActive: false,
      ),
      LocalRule(
        id: 'preset_json_mock',
        name: 'Mock API Response',
        targetPattern: 'httpbin.org/get',
        phase: 'Response',
        actionType: 'BODY_REPLACE',
        replaceString: '{\n  "status": "success",\n  "code": 200,\n  "message": "Mocked by DittoNet Local Engine"\n}',
        method: 'GET',
        isActive: false,
      ),
    ];
    _saveLocalRules();
  }


  void setLocalEngineEnabled(bool enabled) {
    updateConnectionConfig(backendIp, backendPort, enabled);
  }


  void addLocalRule(LocalRule rule) {
    _localRules.add(rule);
    _saveLocalRules();
    notifyListeners();
  }

  void updateLocalRule(int index, LocalRule rule) {
    if (index >= 0 && index < _localRules.length) {
      _localRules[index] = rule;
      _saveLocalRules();
      notifyListeners();
    }
  }

  void removeLocalRule(int index) {
    if (index >= 0 && index < _localRules.length) {
      _localRules.removeAt(index);
      _saveLocalRules();
      notifyListeners();
    }
  }

  void toggleLocalRule(int index, bool isActive) {
    if (index >= 0 && index < _localRules.length) {
      _localRules[index] = _localRules[index].copyWith(isActive: isActive);
      _saveLocalRules();
      notifyListeners();
    }
  }

  void _saveLocalRules() {
    prefs.setString('local_rules_list', jsonEncode(_localRules.map((e) => e.toJson()).toList()));
  }

  void updateLastSynced(String timestamp) {
    _lastSyncedTimestamp = timestamp;
    prefs.setString('lastSyncedTimestamp', timestamp);
    notifyListeners();
  }

  void importWorkspace(List<LocalRule> rules, List<HookScript> hooks) {
    _localRules = rules;
    _hookScripts = hooks;
    _saveLocalRules();
    _saveHookScripts();
    notifyListeners();
  }

  void toggleRecording() {
    _isRecordingTraffic = !_isRecordingTraffic;
    notifyListeners();
  }

  void updateThrottleMs(int ms) {
    _networkThrottleMs = ms;
    prefs.setInt('networkThrottleMs', ms);
    notifyListeners();
  }

  void addHarEntry(Map<String, dynamic> entry) {
    if (_isRecordingTraffic) {
      _recordedHarEntries.add(entry);
    }
  }

  void clearHarEntries() {
    _recordedHarEntries.clear();
  }

  String getHostFromUrl(String url) {
    try {
      return Uri.parse(url).host;
    } catch (_) {
      return url;
    }
  }

  SitePermission getPermissionsForHost(String host) {
    if (host.isEmpty) return SitePermission(host: host);
    return _sitePermissions[host] ?? SitePermission(host: host);
  }

  void _saveSitePermissions() {
    final Map<String, dynamic> encoded = _sitePermissions.map((k, v) => MapEntry(k, v.toJson()));
    prefs.setString('sitePermissionsJson', jsonEncode(encoded));
  }

  void updatePermissionForHost(String host, SitePermission newPerm) {
    if (host.isEmpty) return;
    _sitePermissions[host] = newPerm;
    _saveSitePermissions();
    notifyListeners();
  }

  bool get allowMediaPermissions => getPermissionsForHost(getHostFromUrl(currentUrl)).allowCameraMic;
  bool get allowLocation => getPermissionsForHost(getHostFromUrl(currentUrl)).allowLocation;
  bool get javaScriptEnabled => getPermissionsForHost(getHostFromUrl(currentUrl)).allowJavascript;

  void toggleMediaPermissions(bool val) {
    final host = getHostFromUrl(currentUrl);
    final perm = getPermissionsForHost(host).copyWith(allowCameraMic: val);
    updatePermissionForHost(host, perm);
  }

  void toggleLocation(bool val) {
    final host = getHostFromUrl(currentUrl);
    final perm = getPermissionsForHost(host).copyWith(allowLocation: val);
    updatePermissionForHost(host, perm);
  }

  void toggleJavaScript(bool val) {
    final host = getHostFromUrl(currentUrl);
    final perm = getPermissionsForHost(host).copyWith(allowJavascript: val);
    updatePermissionForHost(host, perm);
  }
}


