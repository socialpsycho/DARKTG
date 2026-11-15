import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../services/cache_service.dart';
import '../services/tdlib_service.dart';
import 'local_message_archive_page.dart';
import 'photo_viewer_screen.dart';

class ChatConversationPage extends StatefulWidget {
  final int chatId;
  final String title;
  const ChatConversationPage({super.key, required this.chatId, required this.title});

  @override
  State<ChatConversationPage> createState() => _ChatConversationPageState();
}

class _ChatConversationPageState extends State<ChatConversationPage> {
  final _controller = TextEditingController();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _recorder = AudioRecorder();
  final List<Map<String, dynamic>> _messages = [];
  StreamSubscription<Map<String, dynamic>>? _subscription;
  Timer? _recordTimer;
  bool _loading = true;
  bool _sending = false;
  bool _recording = false;
  bool _recordStarting = false;
  bool _pressingMic = false;
  bool _searchOpen = false;
  DateTime? _recordStartedAt;
  DateTime? _lastTypingAction;
  String? _recordPath;
  String? _error;
  String _searchQuery = '';
  int _waveTick = 0;

  int _asInt(dynamic value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;

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
        'limit': 100,
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
          _messages.sort((a, b) => _asInt(a['date']).compareTo(_asInt(b['date'])));
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
            _messages.sort((a, b) => _asInt(a['date']).compareTo(_asInt(b['date'])));
          }
          _sending = false;
        });
        if (message['is_outgoing'] != true) {
          _markMessagesRead([Map<String, dynamic>.from(message)]);
        }
        _scrollToBottom();
      }
    } else if (type == 'updateMessageContent' && event['chat_id'] == widget.chatId) {
      final id = event['message_id'];
      final index = _messages.indexWhere((m) => m['id'] == id);
      if (index >= 0) setState(() {
        _messages[index]['content'] = event['new_content'];
        _messages[index]['_darktg_edited'] = true;
      });
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
    } else if (type == 'updateFile') {
      // Refresh media tiles when TDLib reports download progress/completion.
      if (mounted) setState(() {});
    } else if (type == 'error') {
      setState(() { _sending = false; _loading = false; _error = event['message']?.toString(); });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
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
    if (type == 'messagePhoto') return 'Фото';
    if (type == 'messageVideo') return 'Видео';
    if (type == 'messageVoiceNote') return 'Голосовое сообщение';
    if (type == 'messageDocument') return 'Файл';
    if (type == 'messageSticker') return 'Стикер';
    return 'Сообщение';
  }

  String _caption(Map content) {
    final caption = content['caption'];
    if (caption is Map && caption['text'] is String) {
      return caption['text'] as String;
    }
    return '';
  }

  int? _photoFileId(Map content) {
    final photo = content['photo'];
    final sizes = photo is Map ? photo['sizes'] : null;
    if (sizes is! List) return null;
    for (final size in sizes.reversed) {
      if (size is Map && size['photo'] is Map) {
        final id = _asInt(size['photo']['id']);
        if (id > 0) return id;
      }
    }
    return null;
  }

  int? _videoFileId(Map content) {
    final video = content['video'];
    if (video is! Map || video['video'] is! Map) return null;
    final id = _asInt(video['video']['id']);
    return id > 0 ? id : null;
  }

  int? _videoThumbnailFileId(Map content) {
    final video = content['video'];
    final thumbnail = video is Map ? video['thumbnail'] : null;
    final file = thumbnail is Map ? thumbnail['file'] : null;
    final id = file is Map ? _asInt(file['id']) : 0;
    return id > 0 ? id : null;
  }

  Widget _mediaContent(Map content, bool isVideo) {
    final fileId = isVideo ? _videoThumbnailFileId(content) ?? _videoFileId(content)
        : _photoFileId(content);
    if (fileId == null) {
      return const SizedBox(
        width: 220,
        height: 150,
        child: Center(child: Icon(Icons.broken_image_outlined, color: Colors.white54)),
      );
    }
    return InkWell(
      onTap: () {
        final openId = isVideo ? _videoFileId(content) ?? fileId : fileId;
        Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => PhotoViewerScreen(
            fileId: openId,
            isVideo: isVideo,
            title: isVideo ? 'Видео' : 'Фото',
          ),
        ));
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CacheService.instance.media(
              fileId: fileId,
              width: 230,
              height: 220,
              fit: BoxFit.cover,
            ),
          ),
          if (isVideo)
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow_rounded, size: 32, color: Colors.white),
            ),
        ],
      ),
    );
  }

  Widget _messageBody(Map<String, dynamic> message) {
    final content = message['content'];
    if (content is! Map) return Text(_messageText(message));
    final type = content['@type'];
    final caption = _caption(content);
    if (type == 'messagePhoto' || type == 'messageVideo') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _mediaContent(content, type == 'messageVideo'),
          if (caption.isNotEmpty) ...[
            const SizedBox(height: 7),
            Text(caption),
          ],
        ],
      );
    }
    if (type == 'messageDocument') {
      final document = content['document'];
      final file = document is Map ? document['document'] : null;
      final name = document is Map ? document['file_name']?.toString() : null;
      return Row(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.insert_drive_file_outlined),
        const SizedBox(width: 8),
        Flexible(child: Text(name?.isNotEmpty == true ? name! : 'Документ')),
        if (file is Map && _asInt(file['id']) > 0)
          IconButton(
            tooltip: 'Открыть файл',
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
              builder: (_) => PhotoViewerScreen(
                fileId: _asInt(file['id']),
                title: name ?? 'Документ',
              ),
            )),
            icon: const Icon(Icons.open_in_new, size: 18),
          ),
      ]);
    }
    if (type == 'messageVoiceNote') {
      return Row(mainAxisSize: MainAxisSize.min, children: const [
        Icon(Icons.play_circle_fill_rounded, size: 28),
        SizedBox(width: 8),
        Text('Голосовое сообщение'),
      ]);
    }
    return Text(_messageText(message));
  }

  void _markMessagesRead(List<Map<String, dynamic>> messages) {
    final ids = messages
        .where((message) => message['is_outgoing'] != true && message['id'] is int)
        .map((message) => message['id'] as int)
        .toList();
    if (ids.isEmpty) return;
    try {
      TdlibService.instance.viewMessages(chatId: widget.chatId, messageIds: ids);
    } catch (_) {}
  }

  void _sendTypingAction() {
    final now = DateTime.now();
    if (_lastTypingAction != null &&
        now.difference(_lastTypingAction!) < const Duration(seconds: 4)) return;
    _lastTypingAction = now;
    try {
      TdlibService.instance.sendChatAction(
        chatId: widget.chatId,
        action: {'@type': 'chatActionTyping'},
      );
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
      setState(() { _sending = true; });
    } catch (e) {
      setState(() { _error = e.toString(); });
    }
  }

  Future<void> _pickAndSendDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: false,
      );
      if (result == null || result.files.isEmpty) return;
      final path = result.files.single.path;
      if (path == null || path.isEmpty) {
        setState(() { _error = 'Не удалось получить путь к файлу.'; });
        return;
      }
      TdlibService.instance.sendRawRequest({
        '@type': 'sendMessage',
        'chat_id': widget.chatId,
        'input_message_content': {
          '@type': 'inputMessageDocument',
          'document': {'@type': 'inputFileLocal', 'path': path},
          'thumbnail': null,
          'disable_content_type_detection': false,
        },
      });
    } catch (e) {
      if (mounted) setState(() { _error = 'Не удалось отправить файл: ' + e.toString(); });
    }
  }

  Future<void> _startRecording() async {
    if (_recording || _recordStarting) return;
    _recordStarting = true;
    try {
      final allowed = await _recorder.hasPermission();
      if (!allowed) {
        if (mounted) setState(() { _error = 'Разрешите доступ к микрофону.'; });
        return;
      }
      final dir = await getTemporaryDirectory();
      final path = dir.path + '/darktg_voice_' +
          DateTime.now().millisecondsSinceEpoch.toString() + '.m4a';
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 48000,
        ),
        path: path,
      );
      _recordPath = path;
      _recordStartedAt = DateTime.now();
      if (!_pressingMic) {
        await _recorder.stop();
        _recordPath = null;
        return;
      }
      if (mounted) setState(() { _recording = true; _error = null; });
      try {
        TdlibService.instance.sendChatAction(
          chatId: widget.chatId,
          action: {'@type': 'chatActionRecordingVoiceNote'},
        );
      } catch (_) {}
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(milliseconds: 110), (_) {
        if (mounted) setState(() { _waveTick++; });
      });
    } catch (e) {
      if (mounted) setState(() { _error = 'Не удалось начать запись: ' + e.toString(); });
    } finally {
      _recordStarting = false;
    }
  }

  Future<void> _stopRecording({bool send = true}) async {
    if (!_recording && !_recordStarting) return;
    _recordTimer?.cancel();
    _recordTimer = null;
    String? path;
    try {
      path = await _recorder.stop() ?? _recordPath;
    } catch (_) {
      path = _recordPath;
    }
    final started = _recordStartedAt;
    if (mounted) setState(() { _recording = false; });
    _recordPath = null;
    _recordStartedAt = null;
    try {
      TdlibService.instance.sendChatAction(
        chatId: widget.chatId,
        action: {'@type': 'chatActionCancel'},
      );
    } catch (_) {}
    if (!send || path == null || started == null) return;
    final duration = DateTime.now().difference(started).inSeconds;
    if (duration < 1 || !await File(path).exists()) {
      try { await File(path).delete(); } catch (_) {}
      return;
    }
    try {
      TdlibService.instance.sendRawRequest({
        '@type': 'sendMessage',
        'chat_id': widget.chatId,
        'input_message_content': {
          '@type': 'inputMessageVoiceNote',
          'voice_note': {'@type': 'inputFileLocal', 'path': path},
          'duration': duration,
          'waveform': '',
          'album_cover_thumbnail': null,
          'added_sticker_file_ids': <int>[],
        },
      });
    } catch (e) {
      if (mounted) setState(() { _error = 'Не удалось отправить голосовое: ' + e.toString(); });
    }
  }

  void _openQuickSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _recordTimer?.cancel();
    if (_recording || _recordStarting) {
      _recorder.stop();
    }
    _recorder.dispose();
    _controller.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleMessages = _messages.where((message) {
      if (_searchQuery.isEmpty) return true;
      return _messageText(message).toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: _searchOpen
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Быстрый поиск в чате',
                  border: InputBorder.none,
                ),
                onChanged: (value) => setState(() { _searchQuery = value; }),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const Text('DARKTG', style: TextStyle(fontSize: 11, color: Colors.white54)),
                ],
              ),
        actions: [
          IconButton(
            tooltip: 'Быстрый поиск',
            onPressed: _openQuickSearch,
            icon: Icon(_searchOpen ? Icons.close : Icons.search),
          ),
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
              : visibleMessages.isEmpty
                  ? Center(child: Text(_error ?? (_searchQuery.isEmpty ? 'Пока нет сообщений' : 'Ничего не найдено')))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                      itemCount: visibleMessages.length,
                      itemBuilder: (context, index) {
                        final message = visibleMessages[index];
                        final outgoing = message['is_outgoing'] == true;
                        return Align(
                          alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .82),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
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
                                _messageBody(message),
                                if (message['_darktg_edited'] == true ||
                                    (message['edit_date'] is int && message['edit_date'] > 0)) ...[
                                  const SizedBox(height: 4),
                                  const Text('Изменено',
                                      style: TextStyle(fontSize: 10, color: Colors.white60)),
                                ],
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 7, 8, 9),
            child: Row(children: [
              IconButton(
                tooltip: 'Отправить файл',
                onPressed: _pickAndSendDocument,
                icon: const Icon(Icons.attach_file_rounded),
              ),
              Expanded(
                child: _recording
                    ? Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF171625),
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Row(children: [
                          const Icon(Icons.fiber_manual_record, color: Colors.redAccent, size: 13),
                          const SizedBox(width: 8),
                          const Text('Запись', style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: List.generate(18, (i) {
                                final h = 7 + ((i * 7 + _waveTick * (i.isEven ? 3 : 5)) % 18);
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 100),
                                  width: 3,
                                  height: h.toDouble(),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF229ED9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _recordStartedAt == null ? '0:00' : _formatDuration(DateTime.now().difference(_recordStartedAt!)),
                            style: const TextStyle(fontSize: 12, color: Colors.white70),
                          ),
                        ]),
                      )
                    : TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 5,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: 'Сообщение',
                          filled: true,
                          fillColor: const Color(0xFF171625),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        ),
                        onChanged: (_) {
                          setState(() {});
                          _sendTypingAction();
                        },
                        onSubmitted: (_) => _send(),
                      ),
              ),
              const SizedBox(width: 5),
              if (_controller.text.trim().isNotEmpty && !_recording)
                IconButton.filled(
                  onPressed: _sending ? null : _send,
                  icon: const Icon(Icons.send_rounded),
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6)),
                )
              else
                Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (_) {
                    _pressingMic = true;
                    _startRecording();
                  },
                  onPointerUp: (_) {
                    _pressingMic = false;
                    _stopRecording();
                  },
                  onPointerCancel: (_) {
                    _pressingMic = false;
                    _stopRecording(send: false);
                  },
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      color: Color(0xFF8B5CF6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _recording ? Icons.mic : Icons.mic_none_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
            ]),
          ),
        ),
      ]),
    );
  }

  String _formatDuration(Duration duration) {
    final seconds = duration.inSeconds;
    return (seconds ~/ 60).toString() + ':' +
        (seconds % 60).toString().padLeft(2, '0');
  }
}
