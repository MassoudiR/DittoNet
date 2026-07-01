import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/browser_state.dart';
import '../../core/interceptor_core.dart';

class ConnectionDialog extends StatefulWidget {
  const ConnectionDialog({super.key});

  @override
  State<ConnectionDialog> createState() => _ConnectionDialogState();
}

class _ConnectionDialogState extends State<ConnectionDialog> {
  late TextEditingController _ipController;
  late TextEditingController _portController;
  late bool _isLocalMode;

  @override
  void initState() {
    super.initState();
    final state = context.read<BrowserState>();
    _ipController = TextEditingController(text: state.backendIp);
    _portController = TextEditingController(text: state.backendPort.toString());
    _isLocalMode = state.isLocalMode;
    
    // Force health check on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
       context.read<InterceptorCore>().forceHealthCheck();
    });
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  void _save(BuildContext context) {
    context.read<BrowserState>().updateConnectionConfig(
      _ipController.text,
      int.tryParse(_portController.text) ?? 5000,
      _isLocalMode,
    );
    context.read<InterceptorCore>().forceHealthCheck();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BrowserState>();
    
    return AlertDialog(
      backgroundColor: const Color(0xFF2C2C2C),
      title: Row(
        children: [
          Icon(
            Icons.circle,
            size: 16,
            color: state.connectionStatus == ConnectionStatus.green
                ? Colors.greenAccent
                : state.connectionStatus == ConnectionStatus.yellow
                    ? Colors.amberAccent
                    : Colors.redAccent,
          ),
          const SizedBox(width: 8),
          const Text('Server Configuration'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_isLocalMode)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text('Latency: ${state.currentLatencyMs}ms', style: const TextStyle(color: Colors.grey)),
              ),
            TextField(
              controller: _ipController,
              decoration: const InputDecoration(labelText: 'Backend IP', border: OutlineInputBorder()),
              enabled: !_isLocalMode,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _portController,
              decoration: const InputDecoration(labelText: 'Port', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
              enabled: !_isLocalMode,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: Text(_isLocalMode ? 'Local Mode (Active)' : 'Remote Server Mode', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              subtitle: Text(_isLocalMode ? 'Traffic intercepted locally via offline rule engine' : 'Connected to PC Python Backend', style: const TextStyle(color: Colors.white54, fontSize: 12)),
              value: _isLocalMode,
              activeThumbColor: Colors.tealAccent,
              onChanged: (val) {
                setState(() => _isLocalMode = val);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.tealAccent, foregroundColor: Colors.black),
          onPressed: () => _save(context),
          child: Text(_isLocalMode ? 'Save Local Config' : 'Save & Connect Server', style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}
