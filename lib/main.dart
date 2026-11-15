import 'dart:async';
import 'package:flutter/material.dart';

import 'services/tdlib_service.dart';
import 'services/local_message_archive.dart';
import 'services/ghost_mode_service.dart';
import 'screens/auth_page.dart';
import 'screens/chats_page.dart';
import 'screens/contacts_page.dart';
import 'screens/settings_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load persisted privacy/device preferences before TDLib receives parameters.
  await GhostModeService.instance.initialize();
  await TdlibService.instance.initialize();
  await LocalMessageArchive.instance.initialize();
  LocalMessageArchive.instance.attach(TdlibService.instance.events);
  runApp(const DarkTgApp());
}

const Color darkBackground = Color(0xFF090812);
const Color darkSurface = Color(0xFF171525);
const Color accent = Color(0xFF229ED9);

class DarkTgApp extends StatelessWidget {
  const DarkTgApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DARKTG',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
          surface: darkSurface,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: darkBackground,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
        ),
        listTileTheme: const ListTileThemeData(
          iconColor: accent,
          contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 3),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF292936),
          space: 1,
          thickness: 0.6,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.selected) ? accent : null),
        ),
      ),
      home: const AuthorizationGate(),
    );
  }
}

/// The app root follows TDLib authorization updates. Login is shown only while
/// TDLib requests it; once authorizationStateReady arrives, the chat UI opens.
class AuthorizationGate extends StatefulWidget {
  const AuthorizationGate({super.key});

  @override
  State<AuthorizationGate> createState() => _AuthorizationGateState();
}

class _AuthorizationGateState extends State<AuthorizationGate> {
  StreamSubscription<Map<String, dynamic>>? _subscription;
  String? _authorizationType;
  bool isAuthorized = false;

  @override
  void initState() {
    super.initState();
    final initial = TdlibService.instance.lastAuthorizationState;
    _authorizationType = initial?['@type']?.toString();
    isAuthorized = _authorizationType == 'authorizationStateReady';
    _subscription = TdlibService.instance.events.listen(_onEvent);
  }

  void _onEvent(Map<String, dynamic> event) {
    if (!mounted || event['@type'] != 'updateAuthorizationState') return;
    final state = event['authorization_state'];
    if (state is! Map) return;
    final next = state['@type']?.toString();
    setState(() {
      _authorizationType = next;
      isAuthorized = next == 'authorizationStateReady';
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = TdlibService.instance.status;
    if (status == TdlibEngineStatus.failed ||
        status == TdlibEngineStatus.unsupportedPlatform) {
      return _StartupError(
        message: TdlibService.instance.lastError ??
            'TDLib недоступна на этой платформе.',
      );
    }

    // Strict tree boundary: MainScreen is not constructed until TDLib Ready.
    if (isAuthorized &&
        _authorizationType == 'authorizationStateReady') {
      return const MainScreen();
    }

    const authStates = {
      'authorizationStateWaitPhoneNumber',
      'authorizationStateWaitCode',
      'authorizationStateWaitPassword',
      'authorizationStateWaitEmailAddress',
      'authorizationStateWaitEmailCode',
      'authorizationStateWaitRegistration',
      'authorizationStateWaitOtherDeviceConfirmation',
      'authorizationStateWaitPremiumPurchase',
      'authorizationStateClosed',
    };

    if (_authorizationType != null && authStates.contains(_authorizationType)) {
      return const AuthPage();
    }

    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: accent),
            SizedBox(height: 18),
            Text('Подключаем Telegram…'),
          ],
        ),
      ),
    );
  }
}

class _StartupError extends StatelessWidget {
  final String message;
  const _StartupError({required this.message});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.orange, size: 42),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int selectedIndex = 0;

  static const pages = [ChatsPage(), ContactsPage(), SettingsPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: pages[selectedIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => setState(() => selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Чаты'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Контакты'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Настройки'),
        ],
      ),
    );
  }
}
