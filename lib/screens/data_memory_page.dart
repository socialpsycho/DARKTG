import 'package:flutter/material.dart';
import '../services/tdlib_service.dart';

class DataMemoryPage extends StatefulWidget {
  const DataMemoryPage({super.key});

  @override
  State<DataMemoryPage> createState() => _DataMemoryPageState();
}

class _DataMemoryPageState extends State<DataMemoryPage> {
  bool _loading = true;
  bool _optimizing = false;
  String? _error;
  Map<String, dynamic> _statistics = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  int _number(dynamic value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes Б';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} КБ';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} МБ';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} ГБ';
  }

  Future<void> _load() async {
    if (!TdlibService.instance.isReady) {
      setState(() {
        _loading = false;
        _error = 'Нет активного подключения TDLib.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await TdlibService.instance.requestRaw({
        '@type': 'getStorageStatistics',
        'chat_limit': 0,
      });
      if (!mounted) return;
      setState(() {
        _statistics = result;
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

  Future<void> _optimize() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Оптимизировать хранилище?'),
        content: const Text(
          'TDLib удалит локальные файлы, которые можно повторно загрузить из Telegram. Сообщения и облачные данные аккаунта не удаляются.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Очистить кэш'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _optimizing = true;
      _error = null;
    });
    try {
      await TdlibService.instance.requestRaw({
        '@type': 'optimizeStorage',
        'size': 0,
        'ttl': 0,
        'count': 0,
        'immunity_delay': 0,
        'file_types': <dynamic>[],
        'chat_ids': <int>[],
        'exclude_chat_ids': <int>[],
        'return_deleted_file_statistics': false,
        'chat_limit': 0,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Оптимизация хранилища завершена')),
      );
      await _load();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _optimizing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = _number(_statistics['size']);
    final count = _number(_statistics['count']);
    final byChat = _statistics['by_chat'];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Данные и память'),
        actions: [
          IconButton(
            onPressed: _loading || _optimizing ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(18),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Использование хранилища',
                            style: TextStyle(color: Colors.white70)),
                        const SizedBox(height: 8),
                        Text(
                          _formatBytes(size),
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('$count файлов',
                            style: const TextStyle(color: Colors.white54)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (byChat is List)
                  for (final entry in byChat.whereType<Map>())
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(entry['chat'] is Map
                          ? (entry['chat']['title']?.toString() ?? 'Чат')
                          : 'Данные чата'),
                      subtitle: Text(
                        '${_formatBytes(_number(entry['size']))} · ${_number(entry['count'])} файлов',
                      ),
                    ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.orangeAccent)),
                  ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _optimizing ? null : _optimize,
                  icon: _optimizing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cleaning_services_outlined),
                  label: Text(_optimizing ? 'Оптимизация…' : 'Очистить кэш'),
                ),
              ],
            ),
    );
  }
}
