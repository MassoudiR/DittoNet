import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class UpdateModel {
  final String version;
  final String changelog;
  final String apkUrl;

  UpdateModel({
    required this.version,
    required this.changelog,
    required this.apkUrl,
  });
}

class GitHubUpdater {
  GitHubUpdater._privateConstructor();
  static final GitHubUpdater instance = GitHubUpdater._privateConstructor();

  static const String _latestApiUrl = 'https://api.github.com/repos/MassoudiR/DittoNet/releases/latest';
  static const String _allReleasesApiUrl = 'https://api.github.com/repos/MassoudiR/DittoNet/releases';

  Future<String> getCurrentVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      return packageInfo.version;
    } catch (_) {
      return '1.0.0';
    }
  }

  /// Checks for OTA updates from public GitHub releases.
  /// Returns [UpdateModel] if a higher APK release is available, otherwise null.
  Future<UpdateModel?> checkForUpdates() async {
    try {
      Map<String, dynamic>? releaseData;

      var response = await http.get(
        Uri.parse(_latestApiUrl),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        releaseData = jsonDecode(response.body);
      } else if (response.statusCode == 404) {
        // Fallback to checking all releases array if 'latest' tag returns 404
        response = await http.get(
          Uri.parse(_allReleasesApiUrl),
          headers: {'Accept': 'application/vnd.github.v3+json'},
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final List<dynamic> list = jsonDecode(response.body);
          if (list.isNotEmpty) {
            releaseData = list.first as Map<String, dynamic>;
          }
        }
      }

      if (releaseData == null) {
        debugPrint('GitHubUpdater: No published releases found on GitHub repo yet.');
        return null;
      }

      final String rawTag = releaseData['tag_name']?.toString() ?? '';
      final String body = releaseData['body']?.toString() ?? 'No release notes provided.';
      final List<dynamic>? assets = releaseData['assets'];

      if (rawTag.isEmpty) return null;

      String apkUrl = '';
      if (assets != null) {
        for (final asset in assets) {
          final String name = asset['name']?.toString() ?? '';
          final String downloadUrl = asset['browser_download_url']?.toString() ?? '';
          if (name.endsWith('.apk') || downloadUrl.endsWith('.apk')) {
            apkUrl = downloadUrl;
            break;
          }
        }
      }

      // If no APK asset is attached, fall back to html release url
      if (apkUrl.isEmpty) {
        apkUrl = releaseData['html_url']?.toString() ?? '';
      }
      if (apkUrl.isEmpty) return null;

      final currentVersion = await getCurrentVersion();
      final cleanRemoteVersion = _cleanVersion(rawTag);
      final cleanCurrentVersion = _cleanVersion(currentVersion);

      debugPrint('GitHubUpdater: Current version ($cleanCurrentVersion) vs Remote ($cleanRemoteVersion)');

      if (_isVersionHigher(cleanRemoteVersion, cleanCurrentVersion)) {
        return UpdateModel(
          version: rawTag,
          changelog: body,
          apkUrl: apkUrl,
        );
      }
    } catch (e) {
      debugPrint('GitHubUpdater Error: $e');
    }
    return null;
  }

  String _cleanVersion(String version) {
    String cleaned = version.trim();
    if (cleaned.toLowerCase().startsWith('v')) {
      cleaned = cleaned.substring(1);
    }
    final dashIndex = cleaned.indexOf('-');
    if (dashIndex != -1) cleaned = cleaned.substring(0, dashIndex);
    final plusIndex = cleaned.indexOf('+');
    if (plusIndex != -1) cleaned = cleaned.substring(0, plusIndex);
    return cleaned;
  }

  bool _isVersionHigher(String remote, String current) {
    try {
      final remoteParts = remote.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      final maxLength = remoteParts.length > currentParts.length ? remoteParts.length : currentParts.length;

      for (int i = 0; i < maxLength; i++) {
        final r = i < remoteParts.length ? remoteParts[i] : 0;
        final c = i < currentParts.length ? currentParts[i] : 0;
        if (r > c) return true;
        if (r < c) return false;
      }
    } catch (e) {
      debugPrint('Version comparison failure: $e');
    }
    return false;
  }
}
