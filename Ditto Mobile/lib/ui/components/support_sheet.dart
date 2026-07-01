import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/services/update_service.dart';
import 'update_dialog.dart';

class SupportSheet extends StatefulWidget {
  const SupportSheet({super.key});

  @override
  State<SupportSheet> createState() => _SupportSheetState();
}

class _SupportSheetState extends State<SupportSheet> {
  bool _isCheckingUpdate = false;
  String _currentVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  void _loadVersion() async {
    final ver = await GitHubUpdater.instance.getCurrentVersion();
    if (mounted) {
      setState(() => _currentVersion = ver);
    }
  }

  void _copyAddress(BuildContext context, String name, String address) {
    Clipboard.setData(ClipboardData(text: address));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name address copied to clipboard!'),
        backgroundColor: const Color(0xFF00E5FF),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openGitHub() async {
    final uri = Uri.parse('https://github.com/MassoudiR/DittoNet');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch GitHub URL');
    }
  }

  void _checkForUpdates() async {
    setState(() => _isCheckingUpdate = true);
    final update = await GitHubUpdater.instance.checkForUpdates();
    if (!mounted) return;
    setState(() => _isCheckingUpdate = false);

    if (update != null) {
      Navigator.pop(context);
      showDialog(
        context: context,
        builder: (context) => UpdateDialog(updateModel: update),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You are up to date! (Running v$_currentVersion)'),
          backgroundColor: const Color(0xFF00E5FF),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF16182C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: Color(0xFF00E5FF), width: 1.5)),
      ),
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).padding.bottom + 24),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.volunteer_activism, color: Color(0xFF00E5FF), size: 28),
                SizedBox(width: 10),
                Text(
                  'GitHub & Support Me',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'DittoNet Browser v$_currentVersion • Proudly Open Source',
              style: const TextStyle(color: Colors.white54, fontSize: 13, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 22),

            // Check for Updates Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isCheckingUpdate ? null : _checkForUpdates,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 8,
                  shadowColor: const Color(0xFF00E5FF).withAlpha(100),
                ),
                icon: _isCheckingUpdate
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.system_update_alt_rounded, color: Colors.black),
                label: Text(
                  _isCheckingUpdate ? 'Checking GitHub Releases...' : 'Check for Updates',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.black),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // GitHub Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _openGitHub,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF9D4EDD),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 6,
                ),
                icon: const Icon(Icons.code),
                label: const Text('View on GitHub: MassoudiR/DittoNet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 28),

            const Divider(color: Colors.white12),
            const SizedBox(height: 16),
            const Text(
              'CRYPTO DONATIONS',
              style: TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // USDT Card
            _buildCryptoCard(
              context,
              title: '⚡ USDT (TRON TRC20)',
              address: 'TNhAhjhvw1c1CyayxreLNxhD8u8UViLiY5',
              assetPath: 'assets/USDT-QR.png',
              accentColor: const Color(0xFF00F5D4),
            ),
            const SizedBox(height: 20),

            // BTC Card
            _buildCryptoCard(
              context,
              title: '₿ Bitcoin (BTC)',
              address: '16xTx25nuwDQ9gKwumJgjJCfRXVgag27vP',
              assetPath: 'assets/BTC-QR.png',
              accentColor: const Color(0xFFFFB703),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildCryptoCard(BuildContext context, {required String title, required String address, required String assetPath, required Color accentColor}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F101E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accentColor.withAlpha(100)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Text(title, style: TextStyle(color: accentColor, fontWeight: FontWeight.w900, fontSize: 16)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: Image.asset(assetPath, width: 160, height: 160, fit: BoxFit.contain),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white12)),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    address,
                    style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => _copyAddress(context, title.split(' ')[1], address),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: accentColor.withAlpha(50), borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.copy, color: accentColor, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
