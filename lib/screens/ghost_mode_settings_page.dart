import 'package:flutter/material.dart';
import '../services/ghost_mode_service.dart';
import '../services/tdlib_service.dart';

class GhostModeSettingsPage extends StatefulWidget {
  const GhostModeSettingsPage({super.key});

  @override
  State<GhostModeSettingsPage> createState() => _GhostModeSettingsPageState();
}

class _GhostModeSettingsPageState extends State<GhostModeSettingsPage> {
  final _ghost = GhostModeService.instance;
  bool _busy = false;

  Future<void> _change(Future<void> Function() action, {bool? onlineHidden}) async {
    setState(() => _busy = true);
    await action();
    if (onlineHidden != null && TdlibService.instance.isReady) {
      TdlibService.instance.setOnline(!onlineHidden);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _ghost.enabled;
    return Scaffold(
      appBar: AppBar(title: const Text('Ghost Mode')),
      body: ListView(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: .12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.visibility_off_outlined, color: Color(0xFF8B5CF6)),
                const SizedBox(width: 12),
                Expanded(child: Text(
                  enabled
                    ? 'Ghost Mode включён. DARKTG будет пропускать выбранные исходящие сигналы активности.'
                    : 'Выбери, какие сигналы активности DARKTG не должен отправлять.',
                )),
              ],
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.done_all),
            title: const Text('Не отправлять отметки о прочтении'),
            subtitle: const Text('DARKTG не вызывает viewMessages для подтверждения прочтения.'),
            value: _ghost.hideReadReceipts,
            onChanged: _busy ? null : (v) => _change(() => _ghost.setHideReadReceipts(v)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.keyboard),
            title: const Text('Скрывать набор текста и загрузки'),
            subtitle: const Text('Блокировать sendChatAction для набора текста и индикаторов загрузки.'),
            value: _ghost.hideTyping,
            onChanged: _busy ? null : (v) => _change(() => _ghost.setHideTyping(v)),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.circle_outlined),
            title: const Text('Не показывать онлайн'),
            subtitle: const Text('Не включать online через TDLib setOption. Это не скрывает уже отправленные сервером данные.'),
            value: _ghost.hideOnlineStatus,
            onChanged: _busy ? null : (v) => _change(() => _ghost.setHideOnlineStatus(v), onlineHidden: v),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Text(
              'Важно: Ghost Mode управляет действиями, которые отправляет сам DARKTG. Он не может отменить отметки или события, уже обработанные Telegram, и не гарантирует скрытие всех типов активности.',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
