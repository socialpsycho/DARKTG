import 'dart:async';
import 'package:flutter/material.dart';
import '../main.dart' show accent, darkSurface;
import '../services/tdlib_service.dart';
import 'chat_conversation_page.dart';

class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});
  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  final Map<int, Map<String, dynamic>> _chats = {};
  StreamSubscription<Map<String, dynamic>>? _subscription;
  String _query = '';

  int _asInt(dynamic value) => value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subscription = TdlibService.instance.events.listen(_onEvent);
    if (TdlibService.instance.isReady) _loadChats();
  }

  void _loadChats() {
    if (!TdlibService.instance.isReady || _loading) return;
    setState(() { _loading = true; _error = null; });
    try {
      TdlibService.instance.sendRawRequest({
        '@type': 'getChats', 'chat_list': {'@type': 'chatListMain'}, 'limit': 100,
      });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _onEvent(Map<String, dynamic> event) {
    if (!mounted) return;
    final type = event['@type'];
    if (type == 'updateAuthorizationState') {
      final state = event['authorization_state'];
      if (state is Map && state['@type'] == 'authorizationStateReady') _loadChats();
    } else if (type == 'chats') {
      final ids = event['chat_ids'];
      if (ids is List) {
        for (final id in ids) {
          if (id is int) {
            try { TdlibService.instance.sendRawRequest({'@type': 'getChat', 'chat_id': id}); } catch (_) {}
          }
        }
        setState(() => _loading = false);
      }
    } else if (type == 'chat' || type == 'updateNewChat') {
      final chat = type == 'chat' ? event : event['chat'];
      if (chat is Map && chat['id'] is int) {
        setState(() { _chats[chat['id'] as int] = Map<String, dynamic>.from(chat); _loading = false; });
      }
    } else if (type == 'updateNewMessage') {
      final message = event['message'];
      if (message is Map && message['chat_id'] is int) {
        final id = message['chat_id'] as int;
        final chat = _chats[id];
        if (chat != null) setState(() => chat['last_message'] = message);
      }
    } else if (type == 'updateChatTitle' || type == 'updateChatLastMessage' ||
        type == 'updateChatPosition' || type == 'updateChatReadInbox') {
      final id = event['chat_id'];
      if (id is int && _chats.containsKey(id)) {
        setState(() {
          final chat = _chats[id]!;
          if (type == 'updateChatTitle') chat['title'] = event['title'];
          if (type == 'updateChatLastMessage') chat['last_message'] = event['last_message'];
        });
      }
    } else if (type == 'error') {
      setState(() { _loading = false; _error = event['message']?.toString() ?? 'Ошибка Telegram'; });
    } else if (type == 'darktgTdlibReady') {
      _loadChats();
    }
  }

  String _lastMessage(Map<String, dynamic> chat) {
    final message = chat['last_message'];
    if (message is! Map) return 'Нет сообщений';
    final content = message['content'];
    if (content is! Map) return 'Сообщение';
    final kind = content['@type']?.toString() ?? '';
    if (kind == 'messageText') {
      final text = content['text'];
      if (text is Map) return text['text']?.toString() ?? '';
    }
    if (kind == 'messagePhoto') return 'Фото';
    if (kind == 'messageVideo') return 'Видео';
    if (kind == 'messageVoiceNote') return 'Голосовое сообщение';
    if (kind == 'messageDocument') return 'Файл';
    return 'Сообщение';
  }

  @override
  void dispose() { _subscription?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final chats = _chats.values.where((chat) =>
      (chat['title']?.toString().toLowerCase() ?? '').contains(_query.toLowerCase())).toList()
      ..sort((a, b) {
        final ap = a['positions']; final bp = b['positions'];
        final ao = ap is List && ap.isNotEmpty && ap.first is Map ? _asInt(ap.first['order']) : 0;
        final bo = bp is List && bp.isNotEmpty && bp.first is Map ? _asInt(bp.first['order']) : 0;
        return bo.compareTo(ao);
      });

    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
        child: Row(children: [
          Container(width: 46, height: 46,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF00D5FF), Color(0xFF8B5CF6)]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: accent.withValues(alpha: .28), blurRadius: 18)],
            ),
            child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 29)),
          const SizedBox(width: 12),
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('DARKTG', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
            Text('PRIVATE MESSENGER', style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1.7)),
          ])),
          IconButton(onPressed: _loadChats, icon: const Icon(Icons.refresh_rounded)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: TextField(
          onChanged: (value) => setState(() => _query = value),
          decoration: InputDecoration(
            hintText: 'Поиск чатов', prefixIcon: const Icon(Icons.search_rounded),
            filled: true, fillColor: darkSurface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          ),
        ),
      ),
      Expanded(child: chats.isNotEmpty
        ? ListView.separated(
            itemCount: chats.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 84, color: Color(0xFF29263A)),
            itemBuilder: (context, index) {
              final chat = chats[index];
              final id = _asInt(chat['id']);
              final title = chat['title']?.toString() ?? 'Чат';
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                leading: CircleAvatar(radius: 27, backgroundColor: accent.withValues(alpha: .18),
                  child: Text(title.isNotEmpty ? title.characters.first.toUpperCase() : 'D',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(_lastMessage(chat), maxLines: 1, overflow: TextOverflow.ellipsis),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                  builder: (_) => ChatConversationPage(chatId: id, title: title))),
              );
            },
          )
        : Center(child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(TdlibService.instance.isReady ? Icons.chat_bubble_outline_rounded : Icons.link_off,
                size: 42, color: Colors.white54),
              const SizedBox(height: 12),
              Text(_error ?? (TdlibService.instance.isReady
                ? (_loading ? 'Загружаем чаты…' : 'Чатов пока нет')
                : 'Подключите Telegram в настройках, чтобы загрузить чаты.'), textAlign: TextAlign.center),
              if (_error != null || TdlibService.instance.isReady)
                TextButton(onPressed: _loadChats, child: const Text('Повторить')),
            ]),
          ))),
    ]);
  }
}
