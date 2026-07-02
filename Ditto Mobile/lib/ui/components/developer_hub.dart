import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import '../../state/browser_state.dart';
import 'script_manager_sheet.dart';
import 'local_rules_sheet.dart';
import 'network_security_sheet.dart';
import 'support_sheet.dart';

class DeveloperHub extends StatelessWidget {
  final int initialIndex;

  const DeveloperHub({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      initialIndex: initialIndex > 1 ? 0 : initialIndex,
      length: 2,
      child: Material(
        color: const Color(0xFF1E1E1E),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const TabBar(
              indicatorColor: Colors.tealAccent,
              labelColor: Colors.tealAccent,
              unselectedLabelColor: Colors.grey,
              tabs: [
                Tab(icon: Icon(Icons.list_alt), text: 'Logs'),
                Tab(icon: Icon(Icons.settings), text: 'Settings'),
              ],
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  _LogViewerTab(),
                  _SettingsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    ));
  }
}

class _LogViewerTab extends StatelessWidget {
  const _LogViewerTab();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BrowserState>();
    final logs = state.trafficLogs.reversed.toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Logs: ${logs.length}'),
              TextButton.icon(
                onPressed: () => state.clearLogs(),
                icon: const Icon(Icons.clear_all, color: Colors.redAccent),
                label: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
              )
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: logs.length,
            itemBuilder: (context, index) {
              final log = logs[index];
              Color typeColor = Colors.grey;
              if (log.type.contains('Modified')) typeColor = Colors.orangeAccent;
              if (log.type.contains('Blocked')) typeColor = Colors.redAccent;
              if (log.type.contains('Intercepted')) typeColor = Colors.blueAccent;

              return ListTile(
                dense: true,
                leading: Text(log.method, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                title: Text(log.url, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
                subtitle: Text('${log.timestamp.hour}:${log.timestamp.minute}:${log.timestamp.second} • ${log.type}', style: TextStyle(color: typeColor, fontSize: 10)),
                trailing: log.statusCode != null ? Text(log.statusCode.toString(), style: TextStyle(color: log.statusCode == 200 ? Colors.green : Colors.amber)) : null,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BrowserState>();

    return ListView(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(context).padding.bottom + 36),
      children: [
        const Text('User-Agent Spoofing', style: TextStyle(fontWeight: FontWeight.bold)),
        DropdownButton<String>(
          value: state.currentUserAgent.isEmpty ? 'Default Android Chrome' : state.currentUserAgent,
          isExpanded: true,
          dropdownColor: const Color(0xFF2C2C2C),
          items: <String>[
            'Default Android Chrome',
            'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/114.0.0.0 Safari/537.36'
          ].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value, maxLines: 1, overflow: TextOverflow.ellipsis),
            );
          }).toList(),
          onChanged: (val) {
            if (val != null) state.updateUserAgent(val);
          },
        ),
        if (state.currentUserAgent == 'Default Android Chrome' || state.currentUserAgent.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(
              'Active Device UA: ${state.sanitizedNativeUserAgent}',
              style: const TextStyle(color: Colors.tealAccent, fontSize: 11),
            ),
          ),
        const Divider(color: Colors.white24),
        SwitchListTile(
          title: Text(state.isLocalMode ? 'Local Mode (Active)' : 'Remote Server Mode', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text(state.isLocalMode ? 'Using local offline rule engine instead of Python backend' : 'Connected to PC Python Server backend', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          value: state.isLocalMode,
          activeThumbColor: Colors.tealAccent,
          onChanged: (val) => state.updateConnectionConfig(state.backendIp, state.backendPort, val),
        ),
        const Divider(color: Colors.white24),
        SwitchListTile(
          title: const Text('Developer Console (DevTools)'),
          subtitle: const Text('Inject Eruda or vConsole for debugging'),
          value: state.isDevToolsEnabled,
          activeThumbColor: Colors.tealAccent,
          onChanged: (val) => state.toggleDevTools(val),
        ),
        if (state.isDevToolsEnabled) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 4.0),
            child: Text('DevTools Engine', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
          ),
          DropdownButton<String>(
            value: state.devToolsEngine,
            isExpanded: true,
            dropdownColor: const Color(0xFF2C2C2C),
            items: const [
              DropdownMenuItem(value: 'eruda', child: Text('Eruda (Standard Console)')),
              DropdownMenuItem(value: 'vconsole', child: Text('vConsole (Clean Log Viewer)')),
            ],
            onChanged: (val) {
              if (val != null) state.updateDevToolsEngine(val);
            },
          ),
        ],
        const Divider(color: Colors.white24),
        ListTile(
          title: const Text('JS Hooking Manager'),
          subtitle: const Text('Inject custom scripts at document start'),
          trailing: const Icon(Icons.code, color: Colors.tealAccent),
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const ScriptManagerSheet(),
            );
          },
        ),
        const Divider(color: Colors.white24),

        ListTile(
          title: const Text('Local Rules Manager'),
          subtitle: const Text('Manage standalone BLOCK, REPLACE & INJECT rules'),
          trailing: const Icon(Icons.rule, color: Colors.tealAccent),
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const LocalRulesSheet(),
            );
          },
        ),
        const Divider(color: Colors.white24),
        ListTile(
          title: const Text('Network & Security Suite'),
          subtitle: const Text('Configure Proxy Chaining & SSL Certificate Bypass'),
          trailing: const Icon(Icons.security, color: Colors.tealAccent),
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const NetworkSecuritySheet(),
            );
          },
        ),
        const SizedBox(height: 24),


        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: () async {
                  final cookieManager = CookieManager.instance();
                  await cookieManager.deleteAllCookies();
                  InAppWebViewController.clearAllCache();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cookies & Cache Cleared')));
                  }
                },
                icon: const Icon(Icons.delete_sweep),
                label: const Text('Clear Cookies & Cache', style: TextStyle(fontSize: 13)),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00E5FF), foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16)),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const SupportSheet(),
                );
              },
              icon: const Icon(Icons.info_outline, color: Colors.black),
              label: const Text('Info & Update', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        )
      ],
    );
  }
}

class LogsWindow extends StatelessWidget {
  const LogsWindow({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Row(
                children: [
                  const Icon(Icons.list_alt, color: Colors.tealAccent),
                  const SizedBox(width: 8),
                  const Text('Traffic & Console Logs', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            const Divider(color: Colors.white12),
            const Expanded(child: _LogViewerTab()),
          ],
        ),
      ),
    );
  }
}

class SettingsWindow extends StatelessWidget {
  const SettingsWindow({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF1E1E1E),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Row(
                children: [
                  const Icon(Icons.settings, color: Colors.tealAccent),
                  const SizedBox(width: 8),
                  const Text('Browser Settings & Dev Tools', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close, color: Colors.grey), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            const Divider(color: Colors.white12),
            const Expanded(child: _SettingsTab()),
          ],
        ),
      ),
    );
  }
}
