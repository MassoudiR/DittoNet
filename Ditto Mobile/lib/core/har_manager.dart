import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../state/browser_state.dart';

/// HAR (HTTP Archive 1.2) Generator and File Exporter Service
class HarManager {
  /// Presents dual-action export modal bottom sheet (Share vs Save Local)
  static void showExportModal(BuildContext context, BrowserState state) {
    final entries = List<Map<String, dynamic>>.from(state.recordedHarEntries);
    if (entries.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No HTTP traffic captured in session.')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.archive, color: Colors.redAccent, size: 24),
                  const SizedBox(width: 12),
                  const Text(
                    'Export Traffic (HAR 1.2)',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${entries.length} HTTP request/response payloads captured',
                style: const TextStyle(fontSize: 13, color: Colors.white54),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.share, color: Colors.tealAccent),
                title: const Text('Share HAR File', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Send via email, messenger, or cloud drive', style: TextStyle(color: Colors.white54, fontSize: 12)),
                tileColor: const Color(0xFF2C2C2C),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await exportAndShareHar(state, entries);
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.save_alt, color: Colors.orangeAccent),
                title: const Text('Save to Device', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Write session.har directly to local Documents folder', style: TextStyle(color: Colors.white54, fontSize: 12)),
                tileColor: const Color(0xFF2C2C2C),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await exportAndSaveLocal(context, state, entries);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  static Map<String, dynamic> _buildHarDict(List<Map<String, dynamic>> entries) {
    return {
      'log': {
        'version': '1.2',
        'creator': {
          'name': 'DittoNet Browser Mobile Security Suite',
          'version': '1.0.0',
        },
        'entries': entries,
      }
    };
  }

  /// Exports captured traffic entries as session.har and invokes native OS share modal
  static Future<void> exportAndShareHar(BrowserState state, [List<Map<String, dynamic>>? overrideEntries]) async {
    final entries = overrideEntries ?? List<Map<String, dynamic>>.from(state.recordedHarEntries);
    if (entries.isEmpty) return;

    final harStructure = _buildHarDict(entries);

    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/traffic_session.har');
      await file.writeAsString(jsonEncode(harStructure));

      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'DittoNet Browser Captured Traffic (HAR 1.2)',
      );

      state.clearHarEntries();
    } catch (e) {
      debugPrint('HAR Export Error: $e');
    }
  }

  /// Exports captured traffic directly to device Documents folder
  static Future<void> exportAndSaveLocal(BuildContext context, BrowserState state, List<Map<String, dynamic>> entries) async {
    if (entries.isEmpty) return;

    final harStructure = _buildHarDict(entries);

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File('${docDir.path}/capture_$timestamp.har');
      await file.writeAsString(jsonEncode(harStructure));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('HAR saved: ${file.path}'),
            backgroundColor: Colors.teal,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(label: 'OK', textColor: Colors.white, onPressed: () {}),
          ),
        );
      }

      state.clearHarEntries();
    } catch (e) {
      debugPrint('HAR Save Local Error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving HAR: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }
}
