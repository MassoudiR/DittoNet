import 'dart:convert';
import 'models/local_rule.dart';
import 'models/hook_script.dart';
import '../state/browser_state.dart';
import 'network_client.dart';

class WorkspaceSyncException implements Exception {
  final String message;
  WorkspaceSyncException(this.message);
  @override
  String toString() => message;
}

class WorkspaceSyncManager {
  /// Export mobile client local rules and JS hook scripts to Python MagicServer
  static Future<void> pushWorkspace(BrowserState state) async {
    final client = NetworkClient.getSecureOrProxyClient(state);
    final url = '${state.magicServerUrl}/api/sync/workspace';
    final payload = {
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'local_rules': state.localRules.map((e) => e.toJson()).toList(),
      'js_hooks': state.hookScripts.map((e) => e.toJson()).toList(),
    };

    try {
      final response = await client.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw WorkspaceSyncException('Server returned HTTP ${response.statusCode}: ${response.body}');
      }

      final nowStr = DateTime.now().toString().split('.').first;
      state.updateLastSynced(nowStr);
    } catch (e) {
      if (e is WorkspaceSyncException) rethrow;
      throw WorkspaceSyncException('Connection failed: $e');
    } finally {
      client.close();
    }
  }

  /// Import upstream workspace from Python MagicServer to overwrite mobile client definitions
  static Future<void> pullWorkspace(BrowserState state) async {
    final client = NetworkClient.getSecureOrProxyClient(state);
    final url = '${state.magicServerUrl}/api/sync/workspace';

    try {
      final response = await client.get(
        Uri.parse(url),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) {
        throw WorkspaceSyncException('Server returned HTTP ${response.statusCode}: ${response.body}');
      }

      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final localRulesList = (decoded['local_rules'] as List<dynamic>? ?? [])
          .map((e) => LocalRule.fromJson(e as Map<String, dynamic>))
          .toList();
      final hookScriptsList = (decoded['js_hooks'] as List<dynamic>? ?? [])
          .map((e) => HookScript.fromJson(e as Map<String, dynamic>))
          .toList();

      state.importWorkspace(localRulesList, hookScriptsList);

      final ts = decoded['timestamp'];
      String timeStr;
      if (ts is int) {
        timeStr = DateTime.fromMillisecondsSinceEpoch(ts).toString().split('.').first;
      } else {
        timeStr = DateTime.now().toString().split('.').first;
      }
      state.updateLastSynced(timeStr);
    } catch (e) {
      if (e is WorkspaceSyncException) rethrow;
      throw WorkspaceSyncException('Connection failed: $e');
    } finally {
      client.close();
    }
  }
}
