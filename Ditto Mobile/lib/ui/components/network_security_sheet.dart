import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/browser_state.dart';

class NetworkSecuritySheet extends StatefulWidget {
  const NetworkSecuritySheet({super.key});

  @override
  State<NetworkSecuritySheet> createState() => _NetworkSecuritySheetState();
}

class _NetworkSecuritySheetState extends State<NetworkSecuritySheet> {
  late bool _isProxyEnabled;
  late TextEditingController _hostController;
  late TextEditingController _portController;

  @override
  void initState() {
    super.initState();
    final state = context.read<BrowserState>();
    _isProxyEnabled = state.isExternalProxyEnabled;
    _hostController = TextEditingController(text: state.externalProxyHost);
    _portController = TextEditingController(text: state.externalProxyPort);
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BrowserState>();

    return Material(
      color: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.security, color: Colors.tealAccent),
                  const SizedBox(width: 10),
                  const Text(
                    'Network & Security Suite',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 24),

              // Section 1: SSL Pinning Bypass
              const Text(
                'SSL Certificate Verification',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.tealAccent),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: state.isSslBypassEnabled ? Colors.orangeAccent : Colors.white12),
                ),
                child: SwitchListTile(
                  title: const Text('SSL Certificate Bypass', style: TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: const Text(
                    'Ignores invalid, expired, or self-signed upstream SSL certificates',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  secondary: const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
                  value: state.isSslBypassEnabled,
                  activeThumbColor: Colors.orangeAccent,
                  onChanged: (val) => state.toggleSslBypass(val),
                ),
              ),
              const SizedBox(height: 20),

              // Section 2: External Proxy Chaining
              const Text(
                'External Proxy Chaining',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.tealAccent),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _isProxyEnabled ? Colors.tealAccent : Colors.white12),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Route Traffic via Chained Proxy', style: TextStyle(color: Colors.white, fontSize: 14)),
                      subtitle: const Text(
                        'Routes internal HTTP requests and native WebView traffic to external proxy',
                        style: TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      secondary: const Icon(Icons.hub, color: Colors.tealAccent),
                      value: _isProxyEnabled,
                      activeThumbColor: Colors.tealAccent,
                      onChanged: (val) {
                        setState(() => _isProxyEnabled = val);
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _hostController,
                            enabled: _isProxyEnabled,
                            style: TextStyle(color: _isProxyEnabled ? Colors.white : Colors.white38, fontFamily: 'monospace', fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'Proxy Host / IP',
                              labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                              hintText: '192.168.1.100',
                              hintStyle: const TextStyle(color: Colors.white24),
                              filled: true,
                              fillColor: const Color(0xFF1E1E1E),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: TextField(
                            controller: _portController,
                            enabled: _isProxyEnabled,
                            keyboardType: TextInputType.number,
                            style: TextStyle(color: _isProxyEnabled ? Colors.white : Colors.white38, fontFamily: 'monospace', fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'Port',
                              labelStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                              hintText: '8080',
                              hintStyle: const TextStyle(color: Colors.white24),
                              filled: true,
                              fillColor: const Color(0xFF1E1E1E),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Section 3: Network Throttling (Artificial Latency)
              const Text(
                'Network Throttling',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF141414),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: state.networkThrottleMs > 0 ? Colors.cyanAccent : Colors.white12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: state.networkThrottleMs,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF2C2C2C),
                    icon: const Icon(Icons.speed, color: Colors.cyanAccent),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('No Throttling (0ms Latency)')),
                      DropdownMenuItem(value: 500, child: Text('Fast 3G Simulation (+500ms)')),
                      DropdownMenuItem(value: 2000, child: Text('Slow 2G Simulation (+2000ms)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        state.updateThrottleMs(val);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.tealAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.save),
                  label: const Text('Save Security Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: () {
                    state.saveProxySettings(
                      _isProxyEnabled,
                      _hostController.text.trim(),
                      _portController.text.trim(),
                    );
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Network & Security Settings Applied')),
                    );
                  },
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        ),
      ),
    );
  }
}
