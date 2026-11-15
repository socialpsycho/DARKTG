import 'package:flutter/material.dart';
import '../services/tdlib_service.dart';

class ActiveSessionsPage extends StatefulWidget {
  const ActiveSessionsPage({super.key});

  @override
  State<ActiveSessionsPage> createState() => _ActiveSessionsPageState();
}

class _ActiveSessionsPageState extends State<ActiveSessionsPage> {
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;
  String? _error;
  final Set<int> _terminating = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  int _intValue(dynamic value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;

  Future<void> _load() async {
    if (!TdlibService.instance.isReady) {
      setState(() {
        _loading = false;
        _error = 'Сначала подключите аккаунт Telegram.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await TdlibService.instance.requestRaw({
        '@type': 'getActiveSessions',
      });
      final active = response['sessions'];
      final items = active is List
          ? active.whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _sessions = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _terminate(Map<String, dynamic> session) async {
    final id = _intValue(session['id']);
    if (id == 0 || _terminating.contains(id)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Завершить сессию?'),
        content: Text(
          'Устройство: ${session['device_model'] ?? 'Неизвестное устройство'}\n'
          'IP: ${session['ip_address'] ?? 'неизвестен'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Завершить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _terminating.add(id));
    try {
      await TdlibService.instance.requestRaw({
        '@type': 'terminateSession',
        'session_id': id,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сессия завершена')),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось завершить сессию: $error')),
      );
    } finally {
      if (mounted) setState(() => _terminating.remove(id));
    }
  }

  String _activeDate(dynamic value) {
    final seconds = _intValue(value);
    if (seconds <= 0) return 'Нет данных об активности';
    final date = DateTime.fromMillisecondsSinceEpoch(seconds * 1000).toLocal();
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return 'Активность: $d.$m.${date.year} в $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Активные сессии'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _load,
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  ),
                )
              : _sessions.isEmpty
                  ? const Center(child: Text('Активных сессий не найдено'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: _sessions.length,
                        separatorBuilder: (_, __) => const Divider(indent: 72),
                        itemBuilder: (context, index) {
                          final session = _sessions[index];
                          final id = _intValue(session['id']);
                          final current = session['is_current'] == true;
                          final model = session['device_model']?.toString() ??
                              session['platform']?.toString() ??
                              'Неизвестное устройство';
                          final platform = session['platform']?.toString() ?? '';
                          final system = session['system_version']?.toString() ?? '';
                          final ip = session['ip_address']?.toString() ?? 'Неизвестен';
                          final country = session['country']?.toString() ?? '';
                          final region = session['region']?.toString() ?? '';
                          final location = [region, country]
                              .where((part) => part.isNotEmpty)
                              .join(', ');
                          return ListTile(
                            leading: CircleAvatar(
                              child: Icon(current
                                  ? Icons.phone_android
                                  : Icons.devices_other),
                            ),
                            title: Text(model),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (platform.isNotEmpty || system.isNotEmpty)
                                    Text([platform, system]
                                        .where((part) => part.isNotEmpty)
                                        .join(' • ')),
                                  Text('IP: $ip'),
                                  Text('Местоположение: ${location.isEmpty ? 'Неизвестно' : location}'),
                                  Text(_activeDate(session['date_active'])),
                                ],
                              ),
                            ),
                            isThreeLine: true,
                            trailing: current
                                ? const Chip(label: Text('Это устройство'))
                                : TextButton(
                                    onPressed: _terminating.contains(id)
                                        ? null
                                        : () => _terminate(session),
                                    child: _terminating.contains(id)
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Text('Завершить'),
                                  ),
                          );
                        },
                      ),
                    ),
    );
  }
}
