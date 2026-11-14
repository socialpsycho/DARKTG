import 'dart:async';
import 'package:flutter/material.dart';
import '../services/tdlib_service.dart';
import 'local_message_archive_page.dart';

class ChatConversationPage extends StatefulWidget {
  final int chatId;
  final String title;
  const ChatConversationPage({super.key, required this.chatId, required this.title});

  @override
  State<ChatConversationPage> createState() => _ChatConversationPageState();
}

class _ChatConversationPageState extends State<ChatConversationPage> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  StreamSubscription<Map<String, dynamic>>? _subscription;
  bool _loading = true;
  bool _sending = false;
  DateTime? _lastTypingAction;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subscription = TdlibService.instance.events.listen(_onEvent);
    _loadHistory();
  }

  void _loadHistory() {
    try {
      TdlibService.instance.sendRawRequest({
        '@type': 'getChatHistory',
        'chat_id': widget.chatId,
        'from_message_id': 0,
        'offset': 0,
        'limit': 50,
        'only_local': false,
      });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _onEvent(Map<String, dynamic> event) {
    if (!mounted) return;
    final type = event['@type'];
    if (type == 'messages') {
      final list = event['messages'];
      if (list is List) {
        setState(() {
          _messages
            ..clear()
            ..addAll(list.whereType<Map>().map((m) => Map<String, dynamic>.from(m)));
          _messages.sort((a, b) => ((a['date'] as int?) ?? 0).compareTo((b['date'] as int?) ?? 0));
          _loading = false;
        });
        _markMessagesRead(_messages);
        _scrollToBottom();
      }
    } else if (type == 'updateNewMessage') {
      final message = event['message'];
      if (message is Map && message['chat_id'] == widget.chatId) {
        setState(() {
          final value = Map<String, dynamic>.from(message);
          final id = value['id'];
          final index = _messages.indexWhere((m) => m['id'] == id);
          if (index >= 0) {
            _messages[index] = value;
          } else {
            _messages.add(value);
            _messages.sort((a, b) => ((a['date'] as int?) ?? 0).compareTo((b['date'] as int?) ?? 0));
          }
          _sending = false;
        });
        if (message['is_outgoing'] != true) _markMessagesRead([Map<String, dynamic>.from(message)]);
        _scrollToBottom();
      }
    } else if (type == 'updateMessageContent' && event['chat_id'] == widget.chatId) {
      final id = event['message_id'];
      final index = _messages.indexWhere((m) => m['id'] == id);
      if (index >= 0) setState(() => _messages[index]['content'] = event['new_content']);
    } else if (type == 'updateDeleteMessages' && event['chat_id'] == widget.chatId) {
      final ids = event['message_ids'];
      if (ids is List) {
        setState(() {
          for (final id in ids.whereType<int>()) {
            final index = _messages.indexWhere((m) => m['id'] == id);
            if (index >= 0) _messages[index]['_darktg_deleted'] = true;
          }
        });
      }
    } else if (type == 'error') {
      setState(() { _sending = false; _loading = false; _error = event['message']?.toString(); });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180), curve: Curves.easeOut);
      }
    });
  }

  String _messageText(Map<String, dynamic> message) {
    final content = message['content'];
    if (content is! Map) return 'Сообщение';
    final type = content['@type'];
    if (type == 'messageText') {
      final formatted = content['text'];
      if (formatted is Map) return formatted['text']?.toString() ?? '';
    }
    if (type == 'messagePhoto') return '📷 Фото';
    if (type == 'messageVideo') return '🎬 Видео';
    if (type == 'messageVoiceNote') return '🎤 Голосовое сообщение';
    if (type == 'messageDocument') return '📎 Файл';
    if (type == 'messageSticker') return 'Стикер';
    return 'Сообщение';
  }

  void _markMessagesRead(List<Map<String, dynamic>> messages) {
    final ids = messages
        .where((message) => message['is_outgoing'] != true && message['id'] is int)
        .map((message) => message['id'] as int)
        .toList();
    if (ids.isEmpty) return;
    try {
      TdlibService.instance.sendRawRequest({
        '@type': 'viewMessages',
        'chat_id': widget.chatId,
        'message_ids': ids,
        'force_read': false,
      });
    } catch (_) {}
  }

  void _sendTypingAction() {
    final now = DateTime.now();
    if (_lastTypingAction != null &&
        now.difference(_lastTypingAction!) < const Duration(seconds: 4)) return;
    _lastTypingAction = now;
    try {
      TdlibService.instance.sendRawRequest({
        '@type': 'sendChatAction',
        'chat_id': widget.chatId,
        'action': {'@type': 'chatActionTyping'},
      });
    } catch (_) {}
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    try {
      TdlibService.instance.sendRawRequest({
        '@type': 'sendMessage',
        'chat_id': widget.chatId,
        'input_message_content': {
          '@type': 'inputMessageText',
          'text': {'@type': 'formattedText', 'text': text, 'entities': []},
          'clear_draft': true,
        },
      });
      _controller.clear();
      setState(() => _sending = true);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          const Text('DARKTG', style: TextStyle(fontSize: 11, color: Colors.white54)),
        ]),
        actions: [
          IconButton(
            tooltip: 'Локальная история',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => LocalMessageArchivePage(
                chatId: widget.chatId,
                chatTitle: widget.title,
              ),
            )),
            icon: const Icon(Icons.history),
          ),
          IconButton(onPressed: _loadHistory, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _messages.isEmpty
                  ? Center(child: Text(_error ?? 'Пока нет сообщений'))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final outgoing = message['is_outgoing'] == true;
                        return Align(
                          alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .82),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: outgoing ? const Color(0xFF5434A8) : const Color(0xFF1B1A2A),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(17),
                                topRight: const Radius.circular(17),
                                bottomLeft: Radius.circular(outgoing ? 17 : 5),
                                bottomRight: Radius.circular(outgoing ? 5 : 17),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_messageText(message)),
                                if (message['_darktg_deleted'] == true) ...[
                                  const SizedBox(height: 4),
                                  const Text('Сохранено DARKTG · удалено в Telegram',
                                    style: TextStyle(fontSize: 10, color: Colors.orangeAccent)),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
        if (_error != null)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent))),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
            child: Row(children: [
              Expanded(child: TextField(
                controller: _controller,
                minLines: 1, maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Сообщение',
                  filled: true, fillColor: const Color(0xFF171625),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                onChanged: (_) => _sendTypingAction(),
                onSubmitted: (_) => _send(),
              )),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _sending ? null : _send,
                icon: const Icon(Icons.send_rounded),
                style: IconButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}
