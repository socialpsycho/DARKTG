import 'package:flutter/material.dart';

import '../services/local_message_archive.dart';

class LocalMessageArchivePage extends StatefulWidget {
  final int chatId;
  final String chatTitle;

  const LocalMessageArchivePage({
    super.key,
    required this.chatId,
    required this.chatTitle,
  });

  @override
  State<LocalMessageArchivePage> createState() =>
      _LocalMessageArchivePageState();
}

class _LocalMessageArchivePageState extends State<LocalMessageArchivePage> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = LocalMessageArchive.instance.getChatMessages(widget.chatId);
  }

  String _text(Map<String, dynamic> record) {
    final message = record['message'];
    if (message is! Map) return 'Сообщение';
    final content = message['content'];
    if (content is! Map) return 'Сообщение';
    if (content['@type'] == 'messageText') {
      final text = content['text'];
      if (text is Map) return text['text']?.toString() ?? '';
    }
    return switch (content['@type']) {
      'messagePhoto' => 'Фото',
      'messageVideo' => 'Видео',
      'messageVoiceNote' => 'Голосовое сообщение',
      'messageDocument' => 'Файл',
      'messageSticker' => 'Стикер',
      _ => 'Сообщение',
    };
  }

  void _showRevisions(Map<String, dynamic> record) {
    final revisions = record['revisions'] as List? ?? const [];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('История изменений',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (revisions.isEmpty)
                const Text('Сохранённых предыдущих версий нет.')
              else
                ...revisions.reversed.map((item) {
                  final content = item is Map ? item['content'] : null;
                  final formatted = content is Map ? content['text'] : null;
                  final oldText = formatted is Map
                      ? formatted['text']?.toString()
                      : null;
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.history),
                    title: Text(oldText?.isNotEmpty == true
                        ? oldText!
                        : 'Предыдущая версия'),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Локальная история')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final records = snapshot.data ?? const [];
          if (records.isEmpty) {
            return const Center(
              child: Text('Пока нет сохранённых сообщений'),
            );
          }
          return ListView.separated(
            itemCount: records.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final record = records[records.length - 1 - index];
              final deleted = record['deleted'] == true;
              final revisions = record['revisions'] as List? ?? const [];
              return ListTile(
                leading: Icon(
                  deleted ? Icons.delete_outline : Icons.message_outlined,
                  color: deleted ? Colors.orangeAccent : null,
                ),
                title: Text(
                  _text(record),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text([
                  if (deleted) 'Удалено после получения',
                  if (revisions.isNotEmpty)
                    'Сохранено версий: ${revisions.length}',
                  if (!deleted && revisions.isEmpty) 'Получено приложением',
                ].join(' · ')),
                onTap: () => _showRevisions(record),
              );
            },
          );
        },
      ),
    );
  }
}
