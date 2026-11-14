import 'package:flutter/material.dart';

void main() => runApp(const DarkTgApp());

const Color darkBackground = Color(0xFF10131A);
const Color darkSurface = Color(0xFF191E29);
const Color accent = Color(0xFF4C8DFF);

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

class ChatsPage extends StatelessWidget {
  const ChatsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final chats = [
      ('DARKTG', 'Добро пожаловать в DARKTG', '12:40', Icons.bolt),
      ('Избранное', 'Заметки и сохранённые сообщения', 'Вчера', Icons.bookmark),
      ('Telegram', 'Здесь появятся ваши чаты после подключения', 'Пн', Icons.send),
    ];

    return Column(
      children: [
        const _TopBar(title: 'DARKTG', subtitle: 'Ваше пространство'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Поиск',
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
        Expanded(
          child: ListView.separated(
            itemCount: chats.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 84),
            itemBuilder: (context, index) {
              final chat = chats[index];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                leading: CircleAvatar(
                  radius: 27,
                  backgroundColor: accent.withValues(alpha: 0.18),
                  child: Icon(chat.$4, color: accent),
                ),
                title: Text(chat.$1, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(chat.$2, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: Text(chat.$3, style: Theme.of(context).textTheme.labelSmall),
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Подключение Telegram появится на следующем этапе')),
                ),
              );
            },
          ),
        ),
      ],
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
        const _TopBar(title: 'Настройки DARKTG', subtitle: 'Персонализация и функции'),
        const SizedBox(height: 12),
        const _SectionTitle('ПРИВАТНОСТЬ'),
        _SettingTile(
          icon: Icons.visibility_off_outlined,
          title: 'Ghost Mode',
          subtitle: 'Настройки отображения статуса',
          onTap: () => _showInfo(context, 'Ghost Mode', 'Доступные настройки будут зависеть от возможностей Telegram API.'),
        ),
        _SettingTile(
          icon: Icons.history,
          title: 'История сообщений',
          subtitle: 'Локальное хранение уже полученных сообщений',
          onTap: () => _showInfo(context, 'История сообщений', 'Можно хранить только сообщения, которые клиент законно получил.'),
        ),
        const _SectionTitle('ВНЕШНИЙ ВИД'),
        _SettingTile(
          icon: Icons.palette_outlined,
          title: 'Темы и оформление',
          subtitle: 'Цвета, фон и внешний вид',
          onTap: () => _showInfo(context, 'Темы', 'Настройка тем будет добавлена позже.'),
        ),
        const _SectionTitle('ИНСТРУМЕНТЫ'),
        _SettingTile(
          icon: Icons.translate,
          title: 'Переводчик',
          subtitle: 'Перевод сообщений',
          onTap: () => _showInfo(context, 'Переводчик', 'Функция будет добавлена на следующем этапе.'),
        ),
        _SettingTile(
          icon: Icons.graphic_eq,
          title: 'Голосовые эффекты',
          subtitle: 'Локальная обработка аудио',
          onTap: () => _showInfo(context, 'Голосовые эффекты', 'Функция пока находится в планах.'),
        ),
        _SettingTile(
          icon: Icons.person_add_alt_1,
          title: 'Аккаунты',
          subtitle: 'Управление профилями',
          onTap: () => _showInfo(context, 'Аккаунты', 'Поддержка нескольких аккаунтов появится после интеграции.'),
        ),
        _SettingTile(
          icon: Icons.lock_outline,
          title: 'Блокировка приложения',
          subtitle: 'Защита локального доступа',
          onTap: () => _showInfo(context, 'Блокировка', 'Локальная защита будет добавлена позже.'),
        ),
        const SizedBox(height: 24),
        const Center(child: Text('DARKTG • Prototype 0.1.0')),
        const SizedBox(height: 24),
      ],
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
