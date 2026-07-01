import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'state/browser_state.dart';
import 'core/interceptor_core.dart';
import 'ui/setup_screen.dart';
import 'ui/browser_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BrowserState(prefs)),
        ProxyProvider<BrowserState, InterceptorCore>(
          update: (_, state, previousCore) => InterceptorCore(state),
          dispose: (_, core) => core.dispose(),
        ),
      ],
      child: MagicBrowserApp(prefs: prefs),
    ),
  );
}

class MagicBrowserApp extends StatelessWidget {
  final SharedPreferences prefs;
  
  const MagicBrowserApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    // Check if IP is already configured to skip setup screen
    final isConfigured = prefs.getString('backendIp') != null && prefs.getString('backendIp')!.isNotEmpty;

    return MaterialApp(
      title: 'DittoNet Browser',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.tealAccent,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF121212),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E1E1E),
          elevation: 0,
        ),
        listTileTheme: const ListTileThemeData(
          tileColor: Colors.transparent,
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFF1E1E1E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        ),
      ),
      initialRoute: isConfigured ? '/browser' : '/',
      routes: {
        '/': (context) => const SetupScreen(),
        '/browser': (context) => const BrowserScreen(),
      },
      debugShowCheckedModeBanner: false,
    );
  }
}
