import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:handy_tdlib_next/handy_tdlib_next.dart';
import 'package:path_provider/path_provider.dart';

enum TdlibEngineStatus { notStarted, starting, ready, unsupportedPlatform, failed }

/// Owns the TDLib worker isolate. TDLib receive calls are kept off the UI isolate.
class TdlibService {
  TdlibService._();
  static final TdlibService instance = TdlibService._();

  final StreamController<Map<String, dynamic>> _events =
      StreamController<Map<String, dynamic>>.broadcast();

  TdlibEngineStatus _status = TdlibEngineStatus.notStarted;
  ReceivePort? _receivePort;
  Isolate? _isolate;
  SendPort? _workerPort;
  String? _lastError;

  TdlibEngineStatus get status => _status;
  bool get isReady => _status == TdlibEngineStatus.ready;
  String? get lastError => _lastError;
  Stream<Map<String, dynamic>> get events => _events.stream;

  Future<void> initialize() async {
    if (_status == TdlibEngineStatus.ready ||
        _status == TdlibEngineStatus.starting) return;
    if (!Platform.isAndroid) {
      _status = TdlibEngineStatus.unsupportedPlatform;
      return;
    }

    _status = TdlibEngineStatus.starting;
    _receivePort = ReceivePort();
    _receivePort!.listen(_handleWorkerMessage);
    try {
      _isolate = await Isolate.spawn<SendPort>(
        _tdlibWorker,
        _receivePort!.sendPort,
        debugName: 'DARKTG TDLib worker',
      );
    } catch (error) {
      _status = TdlibEngineStatus.failed;
      _lastError = error.toString();
      rethrow;
    }
  }

  void _handleWorkerMessage(dynamic message) {
    if (message is! Map) return;
    final type = message['type'];
    if (type == 'ready' && message['port'] is SendPort) {
      _workerPort = message['port'] as SendPort;
      _status = TdlibEngineStatus.ready;
      _lastError = null;
      _events.add({'@type': 'darktgTdlibReady'});
    } else if (type == 'error') {
      _lastError = message['message']?.toString() ?? 'TDLib worker error';
      _status = TdlibEngineStatus.failed;
      _events.add({'@type': 'darktgTdlibError', 'message': _lastError});
    } else if (type == 'update' && message['raw'] is String) {
      try {
        final decoded = jsonDecode(message['raw'] as String);
        if (decoded is Map<String, dynamic>) _events.add(decoded);
      } catch (_) {
        // Ignore malformed native output; never crash the application UI.
      }
    }
  }

  void sendRawRequest(Map<String, dynamic> request) {
    final port = _workerPort;
    if (!isReady || port == null) {
      throw StateError('TDLib is not ready.');
    }
    port.send({'type': 'send', 'request': request});
  }

  /// Starts TDLib configuration. API credentials are accepted at runtime and
  /// are never written to source code or sent to the repository.
  Future<void> configure({
    required int apiId,
    required String apiHash,
    required String systemLanguageCode,
    required String deviceModel,
    required String applicationVersion,
  }) async {
    if (apiId <= 0 || apiHash.trim().isEmpty) {
      throw ArgumentError('A valid API ID and API hash are required.');
    }

    final appSupport = await getApplicationSupportDirectory();
    final root = Directory('${appSupport.path}/darktg_tdlib');
    final files = Directory('${root.path}/files');
    await root.create(recursive: true);
    await files.create(recursive: true);

    sendRawRequest({
      '@type': 'setTdlibParameters',
      'database_directory': root.path,
      'files_directory': files.path,
      'use_file_database': true,
      'use_chat_info_database': true,
      'use_message_database': true,
      'use_secret_chats': false,
      'api_id': apiId,
      'api_hash': apiHash.trim(),
      'system_language_code': systemLanguageCode,
      'device_model': deviceModel,
      'system_version': Platform.operatingSystemVersion,
      'application_version': applicationVersion,
      'enable_storage_optimizer': true,
      'ignore_file_names': false,
    });
  }

  void setPhoneNumber(String phoneNumber) {
    sendRawRequest({
      '@type': 'setAuthenticationPhoneNumber',
      'phone_number': phoneNumber.trim(),
      'settings': {'@type': 'phoneNumberAuthenticationSettings'},
    });
  }

  void checkCode(String code) {
    sendRawRequest({'@type': 'checkAuthenticationCode', 'code': code.trim()});
  }

  void checkPassword(String password) {
    sendRawRequest({
      '@type': 'checkAuthenticationPassword',
      'password': password,
    });
  }

  void dispose() {
    _workerPort?.send({'type': 'close'});
    _receivePort?.close();
    _isolate?.kill(priority: Isolate.immediate);
    _status = TdlibEngineStatus.notStarted;
    _workerPort = null;
    _isolate = null;
    _receivePort = null;
  }
}

Future<void> _tdlibWorker(SendPort mainPort) async {
  final commands = ReceivePort();
  try {
    await TdPlugin.initialize();
    final clientId = TdPlugin.instance.tdCreateClientId();
    commands.listen((dynamic command) {
      if (command is! Map || command['type'] != 'send') return;
      final request = command['request'];
      if (request is Map) {
        TdPlugin.instance.tdSend(clientId, jsonEncode(request));
      }
    });
    mainPort.send({'type': 'ready', 'port': commands.sendPort});

    // TDLib's blocking receive runs in this isolate, not on Flutter's UI thread.
    while (true) {
      final raw = TdPlugin.instance.tdReceive(1);
      if (raw != null) mainPort.send({'type': 'update', 'raw': raw});
    }
  } catch (error) {
    mainPort.send({'type': 'error', 'message': error.toString()});
    commands.close();
  }
}
