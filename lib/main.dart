import 'dart:async';
import 'package:flutter/material.dart';

import 'core/telegram/config.dart';
import 'services/tdlib_service.dart';
import 'services/local_message_archive.dart';
import 'services/ghost_mode_service.dart';
import 'screens/auth_page.dart';
import 'screens/chats_page.dart';
import 'screens/contacts_page.dart';
import 'screens/active_sessions_page.dart';
import 'screens/privacy_settings_page.dart';
import 'screens/data_memory_page.dart';

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

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 22, 20, 14),
          child: Text('Настройки', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
        ),
        ListTile(
          leading: const CircleAvatar(
            backgroundColor: darkSurface,
            child: Icon(Icons.person_outline, color: accent),
          ),
          title: const Text('Мой профиль'),
          subtitle: const Text('Профиль аккаунта Telegram'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showUnavailable(context, 'Профиль', 'Просмотр и редактирование профиля будет подключён к данным аккаунта TDLib.'),
        ),
        const Divider(indent: 18, endIndent: 18),
        _SettingsRow(
          icon: Icons.notifications_none,
          title: 'Уведомления и звуки',
          onTap: () => _showUnavailable(context, 'Уведомления и звуки', 'Раздел пока не подключён к настройкам TDLib.'),
        ),
        _SettingsRow(
          icon: Icons.lock_outline,
          title: 'Конфиденциальность и безопасность',
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const PrivacySettingsPage(),
          )),
        ),
        _SettingsRow(
          icon: Icons.data_usage,
          title: 'Данные и память',
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const DataMemoryPage(),
          )),
        ),
        _SettingsRow(
          icon: Icons.devices,
          title: 'Устройства',
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const ActiveSessionsPage(),
          )),
        ),
        const Divider(indent: 18, endIndent: 18),
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
          child: Text('DARKTG', style: TextStyle(color: accent, fontWeight: FontWeight.w700, letterSpacing: 1.1)),
        ),
        ListTile(
          leading: const Icon(Icons.bolt, color: accent),
          title: const Text('Настройки DARKTG', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: const Text('Ghost Mode, история и модель устройства'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => const DarkTgSettingsPage(),
          )),
        ),
        const SizedBox(height: 24),
        const Center(child: Text('DARKTG', style: TextStyle(color: Colors.white38))),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _SettingsRow({required this.icon, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon),
    title: Text(title),
    trailing: const Icon(Icons.chevron_right, color: Colors.white38),
    onTap: onTap,
  );
}

class DarkTgSettingsPage extends StatefulWidget {
  const DarkTgSettingsPage({super.key});

  @override
  State<DarkTgSettingsPage> createState() => _DarkTgSettingsPageState();
}

class _DarkTgSettingsPageState extends State<DarkTgSettingsPage> {
  final _ghost = GhostModeService.instance;
  bool _history = LocalMessageArchive.instance.enabled;
  bool _busy = false;

  Future<void> _setAllGhost(bool value) async {
    setState(() => _busy = true);
    await _ghost.setAllEnabled(value);
    if (value && TdlibService.instance.isReady) {
      TdlibService.instance.setOnline(false);
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _setRead(bool value) async {
    await _ghost.setHideReadReceipts(value);
    if (mounted) setState(() {});
  }

  Future<void> _setTyping(bool value) async {
    await _ghost.setHideTyping(value);
    if (mounted) setState(() {});
  }

  Future<void> _setOnline(bool value) async {
    await _ghost.setHideOnlineStatus(value);
    if (TdlibService.instance.isReady) TdlibService.instance.setOnline(!value);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('DARKTG')),
      body: ListView(
        children: [
          const _SettingsSection('GHOST MODE'),
          SwitchListTile(
            secondary: const Icon(Icons.visibility_off_outlined),
            title: const Text('Ghost Mode'),
            subtitle: const Text('Включить выбранные ограничения активности'),
            value: _ghost.enabled,
            onChanged: _busy ? null : _setAllGhost,
          ),
          SwitchListTile(
            title: const Text('Скрывать прочтение'),
            subtitle: const Text('Не отправлять viewMessages'),
            value: _ghost.hideReadReceipts,
            onChanged: _busy ? null : _setRead,
          ),
          SwitchListTile(
            title: const Text('Скрывать набор текста'),
            subtitle: const Text('Не отправлять sendChatAction'),
            value: _ghost.hideTyping,
            onChanged: _busy ? null : _setTyping,
          ),
          SwitchListTile(
            title: const Text('Скрывать онлайн'),
            subtitle: const Text('Не включать online через TDLib'),
            value: _ghost.hideOnlineStatus,
            onChanged: _busy ? null : _setOnline,
          ),
          const Divider(indent: 18, endIndent: 18),
          const _SettingsSection('ИСТОРИЯ'),
          SwitchListTile(
            secondary: const Icon(Icons.history),
            title: const Text('Локальная история сообщений'),
            subtitle: const Text('Сохранять сообщения, полученные этим устройством'),
            value: _history,
            onChanged: (value) async {
              await LocalMessageArchive.instance.setEnabled(value);
              if (mounted) setState(() => _history = value);
            },
          ),
          const Divider(indent: 18, endIndent: 18),
          const _SettingsSection('УСТРОЙСТВО'),
          ListTile(
            leading: const Icon(Icons.phone_android),
            title: const Text('Модель устройства'),
            subtitle: Text(_ghost.useCustomDeviceModel
                ? '${Config.deviceModel} • применяется при следующем запуске TDLib'
                : 'Android • применяется при следующем запуске TDLib'),
          ),
          SwitchListTile(
            title: const Text('Использовать модель DARKTG'),
            subtitle: const Text('Изменение вступит в силу при следующей инициализации TDLib'),
            value: _ghost.useCustomDeviceModel,
            onChanged: (value) async {
              await _ghost.setUseCustomDeviceModel(value);
              if (mounted) setState(() {});
            },
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 12, 18, 24),
            child: Text(
              'Ghost Mode фильтрует исходящие запросы, которые отправляет DARKTG. Он не отменяет события, уже обработанные Telegram, и не гарантирует скрытие всех типов активности.',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  const _SettingsSection(this.title);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
    child: Text(title, style: const TextStyle(
      color: accent, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2,
    )),
  );
}

void _showUnavailable(BuildContext context, String title, String message) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('ОК'))],
    ),
  );
}
