import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import '../../../state/browser_state.dart';

/// Helper to present Site Security & Permissions bottom sheet
void showSiteSecuritySheet(BuildContext context, InAppWebViewController? webViewController, String currentUrl) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => SiteSecuritySheet(webViewController: webViewController, currentUrl: currentUrl),
  );
}

/// Site Security, Storage Cleanup & Precise Hardware/JS Permission UI Sheet
class SiteSecuritySheet extends StatefulWidget {
  final InAppWebViewController? webViewController;
  final String currentUrl;

  const SiteSecuritySheet({super.key, this.webViewController, this.currentUrl = ''});

  @override
  State<SiteSecuritySheet> createState() => _SiteSecuritySheetState();
}

class _SiteSecuritySheetState extends State<SiteSecuritySheet> {
  bool _isClearingCookies = false;
  bool _isClearingStorage = false;
  bool _isClearingCache = false;

  Future<void> _clearCookies() async {
    setState(() => _isClearingCookies = true);
    await CookieManager.instance().deleteAllCookies();
    setState(() => _isClearingCookies = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Site Cookies Deleted'), backgroundColor: Colors.teal),
      );
    }
  }

  Future<void> _clearStorage() async {
    setState(() => _isClearingStorage = true);
    await widget.webViewController?.evaluateJavascript(source: 'localStorage.clear(); sessionStorage.clear();');
    setState(() => _isClearingStorage = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Web Storage (Local/Session) Cleared'), backgroundColor: Colors.teal),
      );
    }
  }

  Future<void> _clearCache() async {
    setState(() => _isClearingCache = true);
    await InAppWebViewController.clearAllCache();
    setState(() => _isClearingCache = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Browser Cache Purged'), backgroundColor: Colors.teal),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BrowserState>();
    final activeUrl = widget.currentUrl.isEmpty ? state.currentUrl : widget.currentUrl;
    final host = state.getHostFromUrl(activeUrl);
    final perm = state.getPermissionsForHost(host);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 20)],
      ),
      padding: const EdgeInsets.all(20),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Row(
                children: [
                  const Icon(Icons.lock, color: Colors.greenAccent, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      host.isEmpty ? 'Site Security' : 'Permissions for $host',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                activeUrl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.white54, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 20),

              // Section A: Data Cleanup Actions
              const Text(
                'DATA CLEANUP ACTIONS',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.tealAccent, letterSpacing: 1.2),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildCleanupCard(
                      icon: Icons.cookie,
                      iconColor: Colors.amberAccent,
                      label: 'Cookies',
                      isClearing: _isClearingCookies,
                      onTap: _clearCookies,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCleanupCard(
                      icon: Icons.storage,
                      iconColor: Colors.cyanAccent,
                      label: 'Storage',
                      isClearing: _isClearingStorage,
                      onTap: _clearStorage,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildCleanupCard(
                      icon: Icons.cleaning_services,
                      iconColor: Colors.purpleAccent,
                      label: 'Cache',
                      isClearing: _isClearingCache,
                      onTap: _clearCache,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Section B: Live Site Permissions
              const Text(
                'HARDWARE & JS PERMISSIONS (ORIGIN SCOPED)',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orangeAccent, letterSpacing: 1.2),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(color: const Color(0xFF141414), borderRadius: BorderRadius.circular(12)),
                child: Column(
                  children: [
                    SwitchListTile(
                      activeThumbColor: Colors.orangeAccent,
                      title: const Text('JavaScript Execution', style: TextStyle(color: Colors.white, fontSize: 14)),
                      subtitle: const Text('Enables dynamic script hooking & site rendering', style: TextStyle(color: Colors.white54, fontSize: 11)),
                      secondary: const Icon(Icons.javascript, color: Colors.amberAccent, size: 28),
                      value: perm.allowJavascript,
                      onChanged: (val) async {
                        state.updatePermissionForHost(host, perm.copyWith(allowJavascript: val));
                        await widget.webViewController?.setSettings(
                          settings: InAppWebViewSettings(javaScriptEnabled: val),
                        );
                        widget.webViewController?.reload();
                      },
                    ),
                    const Divider(height: 1, color: Colors.white10),
                    SwitchListTile(
                      activeThumbColor: Colors.orangeAccent,
                      title: const Text('Camera & Microphone', style: TextStyle(color: Colors.white, fontSize: 14)),
                      subtitle: const Text('Gates WebRTC streams & media captures', style: TextStyle(color: Colors.white54, fontSize: 11)),
                      secondary: const Icon(Icons.camera_alt, color: Colors.cyanAccent),
                      value: perm.allowCameraMic,
                      onChanged: (val) => state.updatePermissionForHost(host, perm.copyWith(allowCameraMic: val)),
                    ),
                    const Divider(height: 1, color: Colors.white10),
                    SwitchListTile(
                      activeThumbColor: Colors.orangeAccent,
                      title: const Text('Geolocation Access', style: TextStyle(color: Colors.white, fontSize: 14)),
                      subtitle: const Text('Gates HTML5 Geolocation API prompts', style: TextStyle(color: Colors.white54, fontSize: 11)),
                      secondary: const Icon(Icons.location_on, color: Colors.greenAccent),
                      value: perm.allowLocation,
                      onChanged: (val) => state.updatePermissionForHost(host, perm.copyWith(allowLocation: val)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCleanupCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required bool isClearing,
    required VoidCallback onTap,
  }) {
    return Material(
      color: const Color(0xFF141414),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: isClearing ? null : onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isClearing)
                const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.tealAccent))
              else
                Icon(icon, color: iconColor, size: 24),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              const Text(
                'Clear',
                style: TextStyle(color: Colors.white38, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
