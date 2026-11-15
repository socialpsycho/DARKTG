import 'dart:async';
import 'package:flutter/material.dart';

import 'services/tdlib_service.dart';
import 'services/local_message_archive.dart';
import 'services/ghost_mode_service.dart';
import 'screens/auth_page.dart';
import 'screens/chats_page.dart';
import 'screens/contacts_page.dart';
import 'screens/settings_page.dart';
import 'widgets/floating_bottom_navigation_bar.dart';

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
  String? _startupError;
  Timer? _startupTimer;
  bool isAuthorized = false;

  @override
  void initState() {
    super.initState();
    final service = TdlibService.instance;
    final initial = service.lastAuthorizationState;
    _authorizationType = initial?['@type']?.toString();
    _startupError = service.lastError;
    isAuthorized = _authorizationType == 'authorizationStateReady';
    _subscription = service.events.listen(_onEvent);
    if (_authorizationType == null && _startupError == null) {
      _armStartupTimeout();
    }
  }

  void _armStartupTimeout() {
    _startupTimer?.cancel();
    _startupTimer = Timer(const Duration(seconds: 20), () {
      if (!mounted || _authorizationType != null || isAuthorized) return;
      setState(() {
        _startupError = 'Превышено время ожидания ответа от сервера';
      });
    });
  }

  void _onEvent(Map<String, dynamic> event) {
    if (!mounted) return;
    final eventType = event['@type'];
    if (eventType == 'darktgTdlibError' ||
        eventType == 'darktgTdlibStartupError') {
      _startupTimer?.cancel();
      setState(() {
        _startupError = event['message']?.toString() ?? 'Ошибка запуска TDLib';
      });
      return;
    }
    if (eventType != 'updateAuthorizationState') return;
    final state = event['authorization_state'];
    if (state is! Map) return;
    final next = state['@type']?.toString();
    _startupTimer?.cancel();
    setState(() {
      _startupError = null;
      _authorizationType = next;
      isAuthorized = next == 'authorizationStateReady';
    });
  }

  Future<void> _retryStartup() async {
    _startupTimer?.cancel();
    setState(() {
      _startupError = null;
      _authorizationType = null;
      isAuthorized = false;
    });
    _armStartupTimeout();
    await TdlibService.instance.retryInitialization();
    if (!mounted) return;
    final state = TdlibService.instance.lastAuthorizationState;
    if (state != null) {
      _startupTimer?.cancel();
      final next = state['@type']?.toString();
      setState(() {
        _authorizationType = next;
        isAuthorized = next == 'authorizationStateReady';
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _startupTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = TdlibService.instance.status;
    if (_startupError != null ||
        status == TdlibEngineStatus.failed ||
        status == TdlibEngineStatus.unsupportedPlatform) {
      return _StartupError(
        message: _startupError ?? TdlibService.instance.lastError ??
            'TDLib недоступна на этой платформе.',
        onRetry: _retryStartup,
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
  final VoidCallback onRetry;
  const _StartupError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 14),
            Text(message, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Повторить'),
            ),
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



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: [
          const ContactsPage(),
          const _CallsPlaceholder(),
          ChatsPage(
            onOpenGhostMode: () => setState(() => selectedIndex = 3),
            onNewMessage: () => setState(() => selectedIndex = 0),
          ),
          const SettingsPage(),
        ],
      ),
      bottomNavigationBar: FloatingBottomNavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => setState(() => selectedIndex = index),
      ),
    );
  }
}


class _CallsPlaceholder extends StatelessWidget {
  const _CallsPlaceholder();
  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: darkBackground,
    body: Center(child: Column(mainAxisSize:MainAxisSize.min,children:[
      Icon(Icons.call_outlined,size:42,color:Colors.white38),
      SizedBox(height:12),
      Text('Звонки',style:TextStyle(fontSize:20,fontWeight:FontWeight.w600)),
      SizedBox(height:5),
      Text('История звонков появится здесь',style:TextStyle(color:Colors.white54)),
    ])),
  );
}
