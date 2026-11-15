import 'package:flutter/material.dart';

import '../core/telegram/config.dart';
import '../main.dart' show accent, darkSurface;
import '../services/ghost_mode_service.dart';
import '../services/local_message_archive.dart';
import '../services/tdlib_service.dart';
import 'active_sessions_page.dart';
import 'data_memory_page.dart';
import 'privacy_settings_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final GhostModeService _ghost = GhostModeService.instance;
  bool _history = LocalMessageArchive.instance.enabled;
  bool _working = false;

  Future<void> _setGhostMode(bool value) async {
    setState(() => _working = true);
    await _ghost.setAllEnabled(value);
    if (TdlibService.instance.isReady) {
      // A false online option is deliberately allowed by the request filter.
      TdlibService.instance.setOnline(!value);
    }
    if (mounted) setState(() => _working = false);
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        content: const Text('Потребуется снова пройти авторизацию Telegram.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _working = true);
    try {
      TdlibService.instance.logOut();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось выйти: $error')),
        );
        setState(() => _working = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            const Text('Настройки',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            const Text('Управление DARKTG и аккаунтом',
                style: TextStyle(color: Colors.white54)),
            const SizedBox(height: 22),
            Card(
              color: darkSurface,
              child: Column(
                children: [
                  SwitchListTile(
                    secondary: const Icon(Icons.visibility_off_outlined),
                    title: const Text('Ghost Mode',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text(
                      'Блокировать уведомления о прочтении и действиях, не публиковать онлайн',
                    ),
                    value: _ghost.isGhostModeEnabled,
                    onChanged: _working ? null : _setGhostMode,
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  SwitchListTile(
                    title: const Text('Скрывать прочтение'),
                    subtitle: const Text('Не отправлять viewMessages'),
                    value: _ghost.hideReadReceipts,
                    onChanged: _working ? null : (v) async {
                      await _ghost.setHideReadReceipts(v);
                      if (mounted) setState(() {});
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Скрывать набор текста'),
                    subtitle: const Text('Не отправлять sendChatAction'),
                    value: _ghost.hideTyping,
                    onChanged: _working ? null : (v) async {
                      await _ghost.setHideTyping(v);
                      if (mounted) setState(() {});
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Скрывать онлайн'),
                    subtitle: const Text('Оставлять online=false в TDLib'),
                    value: _ghost.hideOnlineStatus,
                    onChanged: _working ? null : (v) async {
                      await _ghost.setHideOnlineStatus(v);
                      if (TdlibService.instance.isReady) {
                        TdlibService.instance.setOnline(!v);
                      }
                      if (mounted) setState(() {});
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            const _SectionLabel('АККАУНТ И ПРИВАТНОСТЬ'),
            _SettingsTile(
              icon: Icons.lock_outline,
              title: 'Конфиденциальность',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const PrivacySettingsPage(),
                ),
              ),
            ),
            _SettingsTile(
              icon: Icons.devices_outlined,
              title: 'Активные сеансы',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ActiveSessionsPage(),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const _SectionLabel('ХРАНИЛИЩЕ'),
            _SettingsTile(
              icon: Icons.storage_outlined,
              title: 'Данные и память',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const DataMemoryPage(),
                ),
              ),
            ),
            SwitchListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              title: const Text('Локальная история'),
              subtitle: const Text('Сохранять сообщения на этом устройстве'),
              value: _history,
              onChanged: _working ? null : (value) async {
                await LocalMessageArchive.instance.setEnabled(value);
                if (mounted) setState(() => _history = value);
              },
            ),
            const SizedBox(height: 12),
            const _SectionLabel('ВНЕШНИЙ ВИД И УСТРОЙСТВО'),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: const Icon(Icons.phone_android_outlined),
              title: const Text('Модель устройства'),
              subtitle: Text(_ghost.useCustomDeviceModel
                  ? '${Config.deviceModel} · при следующем запуске'
                  : 'Android · при следующем запуске'),
              trailing: Switch(
                value: _ghost.useCustomDeviceModel,
                onChanged: _working ? null : (value) async {
                  await _ghost.setUseCustomDeviceModel(value);
                  if (mounted) setState(() {});
                },
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _working ? null : _logout,
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              label: const Text('Выйти из аккаунта',
                  style: TextStyle(color: Colors.redAccent)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                side: const BorderSide(color: Colors.redAccent),
              ),
            ),
            const SizedBox(height: 22),
            const Center(
              child: Text('DARKTG',
                  style: TextStyle(color: Colors.white38, letterSpacing: 2)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel(this.title);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
    child: Text(title, style: const TextStyle(
      color: accent, fontSize: 11, fontWeight: FontWeight.w700,
      letterSpacing: 1.2,
    )),
  );
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
    leading: Icon(icon),
    title: Text(title),
    trailing: const Icon(Icons.chevron_right, color: Colors.white38),
    onTap: onTap,
  );
}
