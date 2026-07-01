import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class KeyValueEntry {
  TextEditingController keyController;
  TextEditingController valueController;
  bool isEnabled;

  KeyValueEntry({String key = '', String value = '', this.isEnabled = true})
      : keyController = TextEditingController(text: key),
        valueController = TextEditingController(text: value);

  void dispose() {
    keyController.dispose();
    valueController.dispose();
  }
}

class DittomanScreen extends StatefulWidget {
  const DittomanScreen({super.key});

  @override
  State<DittomanScreen> createState() => _DittomanScreenState();
}

class _DittomanScreenState extends State<DittomanScreen> with SingleTickerProviderStateMixin {
  String _selectedMethod = 'GET';
  final List<String> _methods = ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'];

  final TextEditingController _urlController = TextEditingController(text: 'https://jsonplaceholder.typicode.com/posts/1');
  final TextEditingController _bodyController = TextEditingController();

  late TabController _configTabController;
  int _responseTabIndex = 0; // 0 = Body, 1 = Headers

  final List<KeyValueEntry> _params = [KeyValueEntry()];
  final List<KeyValueEntry> _headers = [
    KeyValueEntry(key: 'Accept', value: '*/*'),
    KeyValueEntry(key: 'Content-Type', value: 'application/json'),
  ];

  bool _isLoading = false;
  http.Response? _response;
  String? _errorMessage;
  int _timeTakenMs = 0;
  String _formattedBody = '';

  @override
  void initState() {
    super.initState();
    _configTabController = TabController(length: 3, vsync: this);
    _loadSavedSession();
  }

  @override
  void dispose() {
    _saveSession();
    _urlController.dispose();
    _bodyController.dispose();
    _configTabController.dispose();
    for (var p in _params) {
      p.dispose();
    }
    for (var h in _headers) {
      h.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSavedSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('dittoman_session_data');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final data = jsonDecode(jsonStr);
        setState(() {
          if (data['method'] != null) _selectedMethod = data['method'];
          if (data['url'] != null) _urlController.text = data['url'];
          if (data['body'] != null) _bodyController.text = data['body'];

          if (data['params'] != null && data['params'] is List) {
            for (var p in _params) {
              p.dispose();
            }
            _params.clear();
            for (var item in (data['params'] as List)) {
              _params.add(KeyValueEntry(
                key: item['key'] ?? '',
                value: item['value'] ?? '',
                isEnabled: item['enabled'] ?? true,
              ));
            }
            if (_params.isEmpty) _params.add(KeyValueEntry());
          }

          if (data['headers'] != null && data['headers'] is List) {
            for (var h in _headers) {
              h.dispose();
            }
            _headers.clear();
            for (var item in (data['headers'] as List)) {
              _headers.add(KeyValueEntry(
                key: item['key'] ?? '',
                value: item['value'] ?? '',
                isEnabled: item['enabled'] ?? true,
              ));
            }
            if (_headers.isEmpty) _headers.add(KeyValueEntry());
          }

          if (data['response'] != null) {
            final resData = data['response'];
            final int code = resData['statusCode'] ?? 200;
            final String bodyStr = resData['body'] ?? '';
            final Map<String, String> hdrs = Map<String, String>.from(resData['headers'] ?? {});
            _response = http.Response(bodyStr, code, headers: hdrs);
            _formattedBody = bodyStr;
            _timeTakenMs = resData['timeTakenMs'] ?? 0;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading dittoman session: $e');
    }
  }

  Future<void> _saveSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      Map<String, dynamic> data = {
        'method': _selectedMethod,
        'url': _urlController.text,
        'body': _bodyController.text,
        'params': _params.map((p) => {
          'key': p.keyController.text,
          'value': p.valueController.text,
          'enabled': p.isEnabled,
        }).toList(),
        'headers': _headers.map((h) => {
          'key': h.keyController.text,
          'value': h.valueController.text,
          'enabled': h.isEnabled,
        }).toList(),
      };

      if (_response != null) {
        data['response'] = {
          'statusCode': _response!.statusCode,
          'body': _formattedBody,
          'headers': _response!.headers,
          'timeTakenMs': _timeTakenMs,
        };
      }

      await prefs.setString('dittoman_session_data', jsonEncode(data));
    } catch (e) {
      debugPrint('Error saving dittoman session: $e');
    }
  }

  Color _getMethodColor(String method) {
    switch (method) {
      case 'GET':
        return const Color(0xFF00E676);
      case 'POST':
        return const Color(0xFF2979FF);
      case 'PUT':
        return const Color(0xFFFF9100);
      case 'DELETE':
        return const Color(0xFFFF5252);
      case 'PATCH':
        return const Color(0xFFE040FB);
      default:
        return Colors.white;
    }
  }

  String _buildUrlWithParams() {
    String baseUrl = _urlController.text.trim();
    if (baseUrl.isEmpty) return '';

    if (!baseUrl.startsWith('http://') && !baseUrl.startsWith('https://')) {
      baseUrl = 'https://$baseUrl';
    }

    Uri? uri = Uri.tryParse(baseUrl);
    if (uri == null) return baseUrl;

    Map<String, String> queryParams = Map.from(uri.queryParameters);
    for (var p in _params) {
      if (p.isEnabled && p.keyController.text.trim().isNotEmpty) {
        queryParams[p.keyController.text.trim()] = p.valueController.text;
      }
    }

    if (queryParams.isEmpty) return baseUrl;

    return uri.replace(queryParameters: queryParams).toString();
  }

  void _copyCurlCommand() {
    String targetUrl = _buildUrlWithParams();
    if (targetUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid URL first.')));
      return;
    }

    StringBuffer curl = StringBuffer();
    curl.write("curl -X $_selectedMethod \"$targetUrl\"");

    for (var h in _headers) {
      if (h.isEnabled && h.keyController.text.trim().isNotEmpty) {
        String key = h.keyController.text.trim();
        String val = h.valueController.text.replaceAll('"', '\\"');
        curl.write(" -H \"$key: $val\"");
      }
    }

    if ((_selectedMethod == 'POST' || _selectedMethod == 'PUT' || _selectedMethod == 'PATCH') && _bodyController.text.isNotEmpty) {
      String escapedBody = _bodyController.text.replaceAll('\'', '\'\\\'\'');
      curl.write(" -d '$escapedBody'");
    }

    Clipboard.setData(ClipboardData(text: curl.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.terminal, color: Color(0xFF00E5FF)),
            SizedBox(width: 12),
            Text('cURL command copied to clipboard!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Color(0xFF1E1E2C),
        duration: Duration(seconds: 2),
      )
    );
  }

  void _formatBodyJson() {
    String input = _bodyController.text.trim();
    if (input.isEmpty) return;
    try {
      final decoded = jsonDecode(input);
      final formatted = const JsonEncoder.withIndent('  ').convert(decoded);
      setState(() {
        _bodyController.text = formatted;
      });
      _saveSession();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('JSON formatted successfully!'), backgroundColor: Colors.teal, duration: Duration(seconds: 1)),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid JSON syntax. Cannot format.'), backgroundColor: Colors.redAccent, duration: Duration(seconds: 2)),
      );
    }
  }

  void _copyResponseToClipboard() {
    if (_formattedBody.isEmpty) return;
    Clipboard.setData(ClipboardData(text: _formattedBody));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.copy, color: Color(0xFF00E676)),
            SizedBox(width: 12),
            Text('Response copied to clipboard!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Color(0xFF1E1E2C),
        duration: Duration(seconds: 2),
      )
    );
  }

  void _showPresetsModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF161622).withValues(alpha: 0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: const Color(0xFFE040FB).withValues(alpha: 0.5), width: 2)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome_motion, color: Color(0xFFE040FB), size: 24),
                      SizedBox(width: 12),
                      Text('API Request Presets', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('Select a template to instantly load request parameters:', style: TextStyle(color: Colors.white54, fontSize: 13)),
                  const SizedBox(height: 16),
                  _buildPresetTile('GET', 'JSONPlaceholder Post', 'https://jsonplaceholder.typicode.com/posts/1', '', [KeyValueEntry(key: 'Accept', value: 'application/json')]),
                  _buildPresetTile('POST', 'ReqRes Create User', 'https://reqres.in/api/users', '{\n  "name": "Morpheus",\n  "job": "Leader"\n}', [KeyValueEntry(key: 'Content-Type', value: 'application/json')]),
                  _buildPresetTile('GET', 'Public IP Info (IP-API)', 'http://ip-api.com/json', '', [KeyValueEntry(key: 'Accept', value: '*/*')]),
                  _buildPresetTile('GET', 'HTTPBin Headers Echo', 'https://httpbin.org/headers', '', [KeyValueEntry(key: 'Custom-Header', value: 'dittoman-Test')]),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPresetTile(String method, String title, String url, String body, List<KeyValueEntry> headers) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 50,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 4),
        decoration: BoxDecoration(
          color: _getMethodColor(method).withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _getMethodColor(method)),
        ),
        child: Text(method, style: TextStyle(color: _getMethodColor(method), fontWeight: FontWeight.bold, fontSize: 11)),
      ),
      title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(url, style: const TextStyle(color: Colors.white38, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
      onTap: () {
        setState(() {
          _selectedMethod = method;
          _urlController.text = url;
          _bodyController.text = body;
          for (var h in _headers) {
            h.dispose();
          }
          _headers.clear();
          _headers.addAll(headers);
          _response = null;
          _errorMessage = null;
        });
        _saveSession();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Loaded Preset: $title'), backgroundColor: Colors.teal, duration: const Duration(seconds: 1)),
        );
      },
    );
  }

  Future<void> _sendRequest() async {
    FocusManager.instance.primaryFocus?.unfocus();
    String targetUrl = _buildUrlWithParams();
    if (targetUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid URL.')));
      return;
    }

    setState(() {
      _isLoading = true;
      _response = null;
      _errorMessage = null;
      _formattedBody = '';
    });
    _saveSession();

    Map<String, String> requestHeaders = {};
    for (var h in _headers) {
      if (h.isEnabled && h.keyController.text.trim().isNotEmpty) {
        requestHeaders[h.keyController.text.trim()] = h.valueController.text;
      }
    }

    Uri? uri = Uri.tryParse(targetUrl);
    if (uri == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid URL syntax: $targetUrl';
      });
      return;
    }

    Stopwatch stopwatch = Stopwatch()..start();
    try {
      http.Response res;
      switch (_selectedMethod) {
        case 'GET':
          res = await http.get(uri, headers: requestHeaders);
          break;
        case 'POST':
          res = await http.post(uri, headers: requestHeaders, body: _bodyController.text);
          break;
        case 'PUT':
          res = await http.put(uri, headers: requestHeaders, body: _bodyController.text);
          break;
        case 'DELETE':
          res = await http.delete(uri, headers: requestHeaders, body: _bodyController.text);
          break;
        case 'PATCH':
          res = await http.patch(uri, headers: requestHeaders, body: _bodyController.text);
          break;
        default:
          res = await http.get(uri, headers: requestHeaders);
      }
      stopwatch.stop();

      String rawBody = utf8.decode(res.bodyBytes, allowMalformed: true);
      String pretty = rawBody;
      try {
        final decoded = jsonDecode(rawBody);
        pretty = const JsonEncoder.withIndent('  ').convert(decoded);
      } catch (_) {
        // Not JSON, keep raw
      }

      if (mounted) {
        setState(() {
          _isLoading = false;
          _response = res;
          _timeTakenMs = stopwatch.elapsedMilliseconds;
          _formattedBody = pretty;
        });
        _saveSession();
      }
    } catch (e) {
      stopwatch.stop();
      if (mounted) {
        setState(() {
          _isLoading = false;
          _timeTakenMs = stopwatch.elapsedMilliseconds;
          _errorMessage = e.toString();
        });
        _saveSession();
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    bool isBodyEnabled = _selectedMethod == 'POST' || _selectedMethod == 'PUT' || _selectedMethod == 'PATCH';

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D15),
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            left: -100,
            child: RepaintBoundary(
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFF00E5FF).withValues(alpha: 0.12), blurRadius: 100, spreadRadius: 50),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -100,
            child: RepaintBoundary(
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE040FB).withValues(alpha: 0.12),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFE040FB).withValues(alpha: 0.12), blurRadius: 100, spreadRadius: 50),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                _buildRequestBar(),
                isKeyboardOpen
                    ? Expanded(child: _buildConfigTabs(isBodyEnabled, isKeyboardOpen))
                    : _buildConfigTabs(isBodyEnabled, isKeyboardOpen),
                if (!isKeyboardOpen) Expanded(child: _buildResponsePanel()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
      child: Row(
        children: [
          IconButton(
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 20),
            onPressed: () {
              _saveSession();
              Navigator.of(context).pop();
            },
          ),
          const Icon(Icons.bolt, color: Color(0xFF00E5FF), size: 24),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              'dittoman',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Presets Button
          GestureDetector(
            onTap: _showPresetsModal,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFE040FB).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE040FB).withValues(alpha: 0.5)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_motion, color: Color(0xFFE040FB), size: 13),
                  SizedBox(width: 4),
                  Text('Presets', style: TextStyle(color: Color(0xFFE040FB), fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Copy cURL Button
          GestureDetector(
            onTap: _copyCurlCommand,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.5)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.terminal, color: Color(0xFF00E5FF), size: 13),
                  SizedBox(width: 4),
                  Text('cURL', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: _getMethodColor(_selectedMethod).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _getMethodColor(_selectedMethod).withValues(alpha: 0.5)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedMethod,
                      dropdownColor: const Color(0xFF1E1E2C),
                      icon: Icon(Icons.arrow_drop_down, color: _getMethodColor(_selectedMethod)),
                      style: TextStyle(color: _getMethodColor(_selectedMethod), fontWeight: FontWeight.bold, fontSize: 14),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() => _selectedMethod = val);
                          _saveSession();
                        }
                      },
                      items: _methods.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    onChanged: (_) => _saveSession(),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Enter request URL...',
                      hintStyle: TextStyle(color: Colors.white38),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _isLoading ? null : _sendRequest,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF2979FF)]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF00E5FF).withValues(alpha: 0.4), blurRadius: 10, spreadRadius: 1),
                      ],
                    ),
                    child: _isLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                        : const Text('SEND', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1.2)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildConfigTabs(bool isBodyEnabled, bool isKeyboardOpen) {
    return Column(
      children: [
        TabBar(
          controller: _configTabController,
          indicatorColor: const Color(0xFF00E5FF),
          labelColor: const Color(0xFF00E5FF),
          unselectedLabelColor: Colors.white54,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: [
            Tab(text: 'Params (${_params.where((p) => p.keyController.text.isNotEmpty).length})'),
            Tab(text: 'Headers (${_headers.where((h) => h.keyController.text.isNotEmpty).length})'),
            Tab(text: isBodyEnabled ? 'Body (JSON/Raw)' : 'Body (Disabled)'),
          ],
        ),
        isKeyboardOpen
            ? Expanded(
                child: TabBarView(
                  controller: _configTabController,
                  children: [
                    _buildKeyValueList(_params),
                    _buildKeyValueList(_headers),
                    _buildBodyInput(isBodyEnabled),
                  ],
                ),
              )
            : SizedBox(
                height: 180,
                child: TabBarView(
                  controller: _configTabController,
                  children: [
                    _buildKeyValueList(_params),
                    _buildKeyValueList(_headers),
                    _buildBodyInput(isBodyEnabled),
                  ],
                ),
              ),
      ],
    );
  }

  Widget _buildKeyValueList(List<KeyValueEntry> list) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, index) {
                final entry = list[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Checkbox(
                        value: entry.isEnabled,
                        activeColor: const Color(0xFF00E5FF),
                        checkColor: Colors.black,
                        onChanged: (val) {
                          setState(() => entry.isEnabled = val ?? true);
                          _saveSession();
                        },
                      ),
                      Expanded(
                        flex: 2,
                        child: _buildInputBox(entry.keyController, 'Key', onChanged: (_) => _saveSession()),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 3,
                        child: _buildInputBox(entry.valueController, 'Value', onChanged: (_) => _saveSession()),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 20),
                        onPressed: () {
                          setState(() {
                            entry.dispose();
                            list.removeAt(index);
                          });
                          _saveSession();
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () {
                setState(() => list.add(KeyValueEntry()));
                _saveSession();
              },
              icon: const Icon(Icons.add, color: Color(0xFF00E5FF), size: 18),
              label: const Text('Add Row', style: TextStyle(color: Color(0xFF00E5FF))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBox(TextEditingController controller, String hint, {Function(String)? onChanged}) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }

  Widget _buildBodyInput(bool isBodyEnabled) {
    if (!isBodyEnabled) {
      return const Center(
        child: Text('Request Body is not applicable for GET/DELETE requests.', style: TextStyle(color: Colors.white38, fontStyle: FontStyle.italic)),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: _formatBodyJson,
                icon: const Icon(Icons.data_object, color: Colors.tealAccent, size: 16),
                label: const Text('Format JSON', style: TextStyle(color: Colors.tealAccent, fontSize: 12)),
              ),
            ],
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: TextField(
                controller: _bodyController,
                onChanged: (_) => _saveSession(),
                maxLines: null,
                style: const TextStyle(color: Colors.tealAccent, fontFamily: 'monospace', fontSize: 13),
                decoration: const InputDecoration(
                  hintText: '{\n  "key": "value"\n}',
                  hintStyle: TextStyle(color: Colors.white24, fontFamily: 'monospace'),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsePanel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF161622).withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
                  ),
                  child: Row(
                    children: [
                      const Text('RESPONSE', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800, letterSpacing: 1.5, fontSize: 12)),
                      const Spacer(),
                      if (_response != null) ...[
                        _buildBadge(
                          '${_response!.statusCode} ${_response!.statusCode >= 200 && _response!.statusCode < 300 ? 'OK' : 'ERR'}',
                          _response!.statusCode >= 200 && _response!.statusCode < 300 ? const Color(0xFF00E676) : const Color(0xFFFF5252),
                        ),
                        const SizedBox(width: 8),
                        _buildBadge('$_timeTakenMs ms', const Color(0xFF00E5FF)),
                        const SizedBox(width: 8),
                        _buildBadge(_formatBytes(_response!.bodyBytes.length), const Color(0xFFFFD600)),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _copyResponseToClipboard,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.copy, size: 16, color: Colors.white70),
                          ),
                        ),
                      ] else if (_errorMessage != null) ...[
                        _buildBadge('ERROR', const Color(0xFFFF5252)),
                      ],
                    ],
                  ),
                ),
                if (_response != null) ...[
                  Row(
                    children: [
                      _buildSubTabButton('Body', 0),
                      _buildSubTabButton('Headers (${_response!.headers.length})', 1),
                    ],
                  ),
                  const Divider(height: 1, color: Colors.white12),
                ],
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
                      : _errorMessage != null
                          ? Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: SingleChildScrollView(
                                child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFFF5252), fontFamily: 'monospace', fontSize: 13)),
                              ),
                            )
                          : _response == null
                              ? const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.api, size: 48, color: Colors.white24),
                                      SizedBox(height: 12),
                                      Text('Enter a URL and click SEND to fire a raw REST request.', style: TextStyle(color: Colors.white38, fontSize: 13)),
                                    ],
                                  ),
                                )
                              : _responseTabIndex == 0
                                  ? SingleChildScrollView(
                                      padding: const EdgeInsets.all(16),
                                      child: SelectableText(
                                        _formattedBody,
                                        style: const TextStyle(color: Color(0xFFE0F7FA), fontFamily: 'monospace', fontSize: 13, height: 1.4),
                                      ),
                                    )
                                  : ListView.builder(
                                      padding: const EdgeInsets.all(12),
                                      itemCount: _response!.headers.length,
                                      itemBuilder: (context, index) {
                                        final key = _response!.headers.keys.elementAt(index);
                                        final val = _response!.headers[key]!;
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 6),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('$key: ', style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontFamily: 'monospace', fontSize: 13)),
                                              Expanded(child: SelectableText(val, style: const TextStyle(color: Colors.white70, fontFamily: 'monospace', fontSize: 13))),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }

  Widget _buildSubTabButton(String label, int index) {
    bool isSelected = _responseTabIndex == index;
    return InkWell(
      onTap: () => setState(() => _responseTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: isSelected ? const Color(0xFF00E5FF) : Colors.transparent, width: 2)),
        ),
        child: Text(
          label,
          style: TextStyle(color: isSelected ? const Color(0xFF00E5FF) : Colors.white54, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13),
        ),
      ),
    );
  }
}
