import 'package:flutter/material.dart';

import 'services/tdlib_service.dart';
import 'services/local_message_archive.dart';
import 'services/ghost_mode_service.dart';
import 'screens/telegram_connect_page.dart';
import 'screens/chats_page.dart';
import 'screens/ghost_mode_settings_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GhostModeService.instance.initialize();
  await TdlibService.instance.initialize();
  await LocalMessageArchive.instance.initialize();
  LocalMessageArchive.instance.attach(TdlibService.instance.events);
  runApp(const DarkTgApp());
}

const Color darkBackground = Color(0xFF090812);
const Color darkSurface = Color(0xFF171525);
const Color accent = Color(0xFF8B5CF6);

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
        appBarTheme: const AppBarTheme(backgroundColor: darkBackground, surfaceTintColor: Colors.transparent),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF100F1B),
          indicatorColor: accent.withValues(alpha: 0.22),
          labelTextStyle: WidgetStateProperty.all(const TextStyle(fontWeight: FontWeight.w600)),
        ),
        cardTheme: CardThemeData(color: darkSurface, surfaceTintColor: Colors.transparent),
        colorScheme: ColorScheme.fromSeed(
          seedColor: accent,
          brightness: Brightness.dark,
          surface: darkSurface,
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int selectedIndex = 0;

  static const pages = [
    ChatsPage(),
    ContactsPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: pages[selectedIndex]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Чаты',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Контакты',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Настройки',
          ),
        ],
      ),
    );
  }
}

class ContactsPage extends StatelessWidget {
  const ContactsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _TopBar(title: 'Контакты', subtitle: 'Люди и группы'),
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Найти контакт',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: darkSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const Expanded(
          child: Center(
            child: Text('Контакты появятся после подключения Telegram'),
          ),
        ),
      ],
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const _TopBar(title: 'Настройки', subtitle: 'Профиль и параметры приложения'),
        const SizedBox(height: 12),
        const ListTile(
          leading: CircleAvatar(
            radius: 28,
            backgroundColor: darkSurface,
            child: Icon(Icons.person_outline, color: accent, size: 28),
          ),
          title: Text('Мой профиль'),
          subtitle: Text('Профиль появится после подключения Telegram'),
          trailing: Icon(Icons.chevron_right, color: Colors.white38),
        ),
        const Divider(height: 24),
        _SettingTile(
          icon: Icons.link,
          title: 'Подключить Telegram',
          subtitle: 'Вход в аккаунт и синхронизация',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const TelegramConnectPage()),
          ),
        ),
        _SettingTile(
          icon: Icons.notifications_none,
          title: 'Уведомления и звуки',
          subtitle: 'Настройки уведомлений',
          onTap: () => _showInfo(context, 'Уведомления и звуки', 'Настройки уведомлений появятся после подключения Telegram.'),
        ),
        _SettingTile(
          icon: Icons.lock_outline,
          title: 'Конфиденциальность',
          subtitle: 'Безопасность и приватность',
          onTap: () => _showInfo(context, 'Конфиденциальность', 'Стандартные настройки приватности будут добавлены при интеграции Telegram.'),
        ),
        _SettingTile(
          icon: Icons.data_usage,
          title: 'Данные и память',
          subtitle: 'Использование памяти и сети',
          onTap: () => _showInfo(context, 'Данные и память', 'Раздел пока готовится.'),
        ),
        _SettingTile(
          icon: Icons.chat_bubble_outline,
          title: 'Настройки чатов',
          subtitle: 'Отображение и поведение чатов',
          onTap: () => _showInfo(context, 'Настройки чатов', 'Раздел пока готовится.'),
        ),
        const SizedBox(height: 18),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'ДОПОЛНИТЕЛЬНЫЕ ВОЗМОЖНОСТИ',
            style: TextStyle(color: accent, fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.bold),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          child: Card(
            color: darkSurface,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.bolt, color: accent, size: 27),
              ),
              title: const Text('Настройки DARKTG', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Ghost Mode, оформление, история и другие функции'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const DarkTgSettingsPage()),
              ),
            ),
          ),
        ),
        const Center(child: Text('DARKTG • Prototype 0.2.0', style: TextStyle(color: Colors.white54))),
        const SizedBox(height: 24),
      ],
    );
  }
}

class DarkTgSettingsPage extends StatefulWidget {
  const DarkTgSettingsPage({super.key});

  @override
  State<DarkTgSettingsPage> createState() => _DarkTgSettingsPageState();
}

class _DarkTgSettingsPageState extends State<DarkTgSettingsPage> {
  // These switches currently control prototype UI state only.
  // Telegram-side behavior will be connected after the client API integration.
  bool saveHistory = true;
  bool translate = false;
  bool voiceEffects = false;
  bool appLock = false;

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon, color: accent),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      activeThumbColor: accent,
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Настройки DARKTG'),
        backgroundColor: darkBackground,
      ),
      body: ListView(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withValues(alpha: 0.25)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: accent),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Это первые интерактивные настройки прототипа. Переключатели пока меняют состояние интерфейса на время работы приложения. Для реальной работы с Telegram потребуется подключение клиентского API.',
                  ),
                ),
              ],
            ),
          ),
          const _SectionTitle('ПРИВАТНОСТЬ'),
          ListTile(
            leading: const Icon(Icons.visibility_off_outlined, color: accent),
            title: const Text('Ghost Mode'),
            subtitle: const Text('Скрытие прочтения, набора текста и онлайн-сигнала'),
            trailing: const Icon(Icons.chevron_right, color: Colors.white38),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const GhostModeSettingsPage()),
            ),
          ),
          _switchTile(
            icon: Icons.history,
            title: 'История сообщений',
            subtitle: 'Включить локальное сохранение полученных сообщений',
            value: saveHistory,
            onChanged: (value) => setState(() => saveHistory = value),
          ),
          const _SectionTitle('ВНЕШНИЙ ВИД'),
          ListTile(
            leading: const Icon(Icons.palette_outlined, color: accent),
            title: const Text('Темы и оформление'),
            subtitle: const Text('Выбор оформления будет следующим этапом'),
            trailing: const Icon(Icons.chevron_right, color: Colors.white38),
            onTap: () => _showInfo(context, 'Темы и оформление', 'Следующим этапом добавим выбор акцентного цвета и фона.'),
          ),
          const _SectionTitle('ИНСТРУМЕНТЫ'),
          _switchTile(
            icon: Icons.translate,
            title: 'Переводчик',
            subtitle: 'Подготовить перевод сообщений',
            value: translate,
            onChanged: (value) => setState(() => translate = value),
          ),
          _switchTile(
            icon: Icons.graphic_eq,
            title: 'Голосовые эффекты',
            subtitle: 'Локальная обработка аудио — в разработке',
            value: voiceEffects,
            onChanged: (value) => setState(() => voiceEffects = value),
          ),
          ListTile(
            leading: const Icon(Icons.person_add_alt_1, color: accent),
            title: const Text('Аккаунты'),
            subtitle: const Text('Несколько аккаунтов — после интеграции Telegram'),
            trailing: const Icon(Icons.chevron_right, color: Colors.white38),
            onTap: () => _showInfo(context, 'Аккаунты', 'Подключение аккаунтов будет реализовано через Telegram client API. Не вводите коды входа в сторонние формы.'),
          ),
          const _SectionTitle('ЗАЩИТА'),
          _switchTile(
            icon: Icons.lock_outline,
            title: 'Блокировка приложения',
            subtitle: 'Переключатель прототипа локальной защиты',
            value: appLock,
            onChanged: (value) => setState(() => appLock = value),
          ),
          const SizedBox(height: 20),
          const Center(
            child: Text('DARKTG • Prototype 0.3.0', style: TextStyle(color: Colors.white54)),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final String subtitle;

  const _TopBar({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.bolt, color: accent, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white60)),
              ],
            ),
          ),
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.more_horiz),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: accent,
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: accent),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right, color: Colors.white38),
      onTap: onTap,
    );
  }
}

void _showInfo(BuildContext context, String title, String message) {
  showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Понятно'),
        ),
      ],
    ),
  );
}
