import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/browser_state.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> with SingleTickerProviderStateMixin {
  final _ipController = TextEditingController(text: '192.168.1.100');
  final _portController = TextEditingController(text: '5000');
  bool _isConnecting = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _connect(BuildContext context) async {
    setState(() => _isConnecting = true);
    final state = Provider.of<BrowserState>(context, listen: false);
    
    state.updateConnectionConfig(
      _ipController.text, 
      int.tryParse(_portController.text) ?? 5000, 
      false
    );
    
    // Simulate ping / initial health check
    await Future.delayed(const Duration(seconds: 1));
    
    if (mounted) {
       Navigator.pushReplacementNamed(context, '/browser');
    }
  }

  void _continueLocal(BuildContext context) {
    final state = Provider.of<BrowserState>(context, listen: false);
    state.updateConnectionConfig(_ipController.text, int.tryParse(_portController.text) ?? 5000, true);
    Navigator.pushReplacementNamed(context, '/browser');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          ),
        ),
        child: RepaintBoundary(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/ditto_logo.png', height: 110),
                  const SizedBox(height: 24),
                  const Text(
                    'DITTONET BROWSER',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Transparent Proxy Bridge',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 48),
                  Card(
                    color: Colors.black45,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          TextField(
                            controller: _ipController,
                            decoration: const InputDecoration(
                              labelText: 'Backend IP',
                              prefixIcon: Icon(Icons.dns, color: Colors.tealAccent),
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _portController,
                            decoration: const InputDecoration(
                              labelText: 'Port',
                              prefixIcon: Icon(Icons.numbers, color: Colors.tealAccent),
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 32),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.tealAccent,
                                foregroundColor: Colors.black,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: _isConnecting ? null : () => _connect(context),
                              child: _isConnecting
                                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.black))
                                  : const Text('CONNECT & LAUNCH', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () => _continueLocal(context),
                            child: const Text('Continue in Local Mode', style: TextStyle(color: Colors.grey)),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
}
