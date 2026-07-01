import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;

/// Helper manager to load web developer tools (Eruda / vConsole)
/// directly from bundled application assets so they work 100% offline and instantly.
class DevToolsManager {
  static String? _cachedEruda;
  static String? _cachedVConsole;
  static final Map<String, Uint8List> erudaFonts = {};

  /// Loads the script from local asset bundle and caches it in memory.
  static Future<String> getDevToolsScript(String engineName) async {
    if (engineName == 'eruda') {
      if (_cachedEruda != null) return _cachedEruda!;
      _cachedEruda = await rootBundle.loadString('assets/eruda.min.js');
      final matches = RegExp(r"@font-face\{font-family:([a-zA-Z0-9_-]+);src:url\('data:application\/x-font-woff;charset=utf-8;base64,([^')]+)'\)").allMatches(_cachedEruda!);
      for (var m in matches) {
        final fontName = m.group(1);
        final b64 = m.group(2);
        if (fontName != null && b64 != null) {
          try {
            erudaFonts[fontName] = base64Decode(b64);
          } catch (_) {}
        }
      }
      return _cachedEruda!;
    } else {
      if (_cachedVConsole != null) return _cachedVConsole!;
      _cachedVConsole = await rootBundle.loadString('assets/vconsole.min.js');
      return _cachedVConsole!;
    }
  }
}
