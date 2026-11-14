import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Stores messages observed by this DARKTG installation and snapshots edits.
/// This is a local archive, not a server-side recovery mechanism.
class LocalMessageArchive {
  LocalMessageArchive._();

  static final LocalMessageArchive instance = LocalMessageArchive._();

  final Map<String, Map<String, dynamic>> _records = {};
  StreamSubscription<Map<String, dynamic>>? _subscription;
  Future<void> _writeQueue = Future<void>.value();
  File? _file;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    final directory = await getApplicationSupportDirectory();
    _file = File('${directory.path}/darktg_message_archive.json');
    if (await _file!.exists()) {
      try {
        final decoded = jsonDecode(await _file!.readAsString());
        if (decoded is Map && decoded['records'] is List) {
          for (final item in decoded['records'] as List) {
            if (item is Map && item['key'] is String) {
              _records[item['key'] as String] =
                  Map<String, dynamic>.from(item);
            }
          }
        }
      } on FormatException {
        // A damaged archive is ignored; future events create a fresh archive.
        _records.clear();
      }
    }
    _initialized = true;
  }

  void attach(Stream<Map<String, dynamic>> events) {
    _subscription ??= events.listen((event) {
      unawaited(recordUpdate(event));
    });
  }

  Future<void> recordUpdate(Map<String, dynamic> event) async {
    if (!_initialized) await initialize();
    final type = event['@type'];

    if (type == 'messages') {
      final messages = event['messages'];
      var changed = false;
      if (messages is List) {
        for (final item in messages) {
          if (item is Map) changed = _storeMessage(item) || changed;
        }
      }
      if (changed) await _persist();
      return;
    }

    if (type == 'updateNewMessage') {
      final message = event['message'];
      if (message is Map) {
        final value = Map<String, dynamic>.from(message);
        final chatId = value['chat_id'];
        final messageId = value['id'];
        if (chatId is int && messageId is int) {
          _storeMessage(value);
          await _persist();
        }
      }
    } else if (type == 'updateMessageContent') {
      final chatId = event['chat_id'];
      final messageId = event['message_id'];
      if (chatId is int && messageId is int) {
        final key = _key(chatId, messageId);
        final record = _records[key];
        if (record != null) {
          final message = Map<String, dynamic>.from(
            (record['message'] as Map?)?.cast<String, dynamic>() ?? {},
          );
          final revisions = List<dynamic>.from(
            record['revisions'] as List? ?? const [],
          );
          revisions.add({
            'content': message['content'],
            'captured_at': DateTime.now().millisecondsSinceEpoch,
          });
          message['content'] = event['new_content'];
          record['message'] = message;
          record['revisions'] = revisions;
          record['edited_at'] = DateTime.now().millisecondsSinceEpoch;
          await _persist();
        }
      }
    } else if (type == 'updateDeleteMessages') {
      final chatId = event['chat_id'];
      final ids = event['message_ids'];
      if (chatId is int && ids is List) {
        var changed = false;
        for (final id in ids.whereType<int>()) {
          final record = _records[_key(chatId, id)];
          if (record != null) {
            record['deleted'] = true;
            record['deleted_at'] = DateTime.now().millisecondsSinceEpoch;
            changed = true;
          }
        }
        if (changed) await _persist();
      }
    }
  }

  Future<List<Map<String, dynamic>>> getChatMessages(int chatId) async {
    if (!_initialized) await initialize();
    final result = _records.values
        .where((record) => record['chat_id'] == chatId)
        .map((record) => Map<String, dynamic>.from(record))
        .toList()
      ..sort((a, b) => ((a['first_seen_at'] as int?) ?? 0)
          .compareTo((b['first_seen_at'] as int?) ?? 0));
    return result;
  }

  bool _storeMessage(Map message) {
    final value = Map<String, dynamic>.from(message);
    final chatId = value['chat_id'];
    final messageId = value['id'];
    if (chatId is! int || messageId is! int) return false;
    final key = _key(chatId, messageId);
    _records.putIfAbsent(key, () => {
      'key': key,
      'chat_id': chatId,
      'message_id': messageId,
      'first_seen_at': DateTime.now().millisecondsSinceEpoch,
      'revisions': <dynamic>[],
    });
    _records[key]!['message'] = value;
    _records[key]!['last_seen_at'] = DateTime.now().millisecondsSinceEpoch;
    return true;
  }

  String _key(int chatId, int messageId) => '$chatId:$messageId';

  Future<void> _persist() {
    final file = _file;
    if (file == null) return Future<void>.value();
    _writeQueue = _writeQueue.then((_) async {
      final payload = jsonEncode({
        'version': 1,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'records': _records.values.toList(),
      });
      await file.writeAsString(payload, flush: true);
    });
    return _writeQueue;
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    await _writeQueue;
  }
}
