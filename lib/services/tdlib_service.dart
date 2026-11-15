import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:handy_tdlib_next/handy_tdlib_next.dart';
import 'package:path_provider/path_provider.dart';
import '../core/telegram/config.dart';
import 'ghost_mode_service.dart';

enum TdlibEngineStatus { notStarted, starting, ready, unsupportedPlatform, failed }

class TdlibService {
  TdlibService._();
  static final TdlibService instance = TdlibService._();

  static const int buildApiId = TelegramApiConfig.apiId;
  static const String buildApiHash = TelegramApiConfig.apiHash;
  static bool get hasBuildCredentials =>
      buildApiId > 0 && buildApiHash.isNotEmpty;

  final StreamController<Map<String, dynamic>> _events =
      StreamController<Map<String, dynamic>>.broadcast();

  TdlibEngineStatus _status = TdlibEngineStatus.notStarted;
  ReceivePort? _receivePort;
  Isolate? _isolate;
  SendPort? _workerPort;
  String? _lastError;
  bool _parametersConfigured = false;
  DateTime? _floodWaitUntil;
  Map<String, dynamic>? _lastAuthorizationState;

  TdlibEngineStatus get status => _status;
  Map<String, dynamic>? get lastAuthorizationState => _lastAuthorizationState;
  int get floodWaitRemainingSeconds {
    final until = _floodWaitUntil;
    if (until == null) return 0;
    final remaining = until.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }
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
        if (decoded is Map<String, dynamic>) {
          if (decoded['@type'] == 'error') {
            _handleTdlibError(decoded);
            return;
          }
          if (decoded['@type'] == 'updateAuthorizationState') {
            final auth = decoded['authorization_state'];
            if (auth is Map) {
              _lastAuthorizationState = Map<String, dynamic>.from(auth);
              if (auth['@type'] == 'authorizationStateWaitTdlibParameters' &&
                  !_parametersConfigured) {
                unawaited(_configureInitialParameters());
              }
            }
          }
          _events.add(decoded);
          final auth = decoded['authorization_state'];
          if (decoded['@type'] == 'updateAuthorizationState' &&
              auth is Map && auth['@type'] == 'authorizationStateReady' &&
              GhostModeService.instance.hideOnlineStatus && isReady) {
            sendRawRequest({
              '@type': 'setOption',
              'name': 'online',
              'value': {'@type': 'optionValueBoolean', 'value': false},
            });
          }
        }
      } catch (_) {}
    }
  }

  void sendRawRequest(Map<String, dynamic> request) {
    if (GhostModeService.instance.shouldSuppress(request)) return;
    final port = _workerPort;
    if (!isReady || port == null) throw StateError('TDLib is not ready.');
    port.send({'type': 'send', 'request': request});
  }

  Future<void> configureFromBuild() async {
    if (_parametersConfigured) return;
    _parametersConfigured = true;
    try {
      await configure(
        apiId: buildApiId,
        apiHash: buildApiHash,
        systemLanguageCode: TelegramApiConfig.systemLanguageCode,
        deviceModel: TelegramApiConfig.deviceModel,
        applicationVersion: TelegramApiConfig.applicationVersion,
      );
    } catch (_) {
      _parametersConfigured = false;
      rethrow;
    }
  }

  Future<void> _configureInitialParameters() async {
    try {
      await configureFromBuild();
      _events.add({'@type': 'darktgTdlibParametersConfigured'});
    } catch (error) {
      _events.add({
        '@type': 'error',
        'message': 'Не удалось настроить TDLib: $error',
      });
    }
  }

  void _handleTdlibError(Map<String, dynamic> error) {
    final message = error['message']?.toString() ?? 'Неизвестная ошибка TDLib';
    final pattern = RegExp(
      r'(?:FLOOD_WAIT_|retry after\s+)(\d+)',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(message);
    if (match != null) {
      final seconds = int.tryParse(match.group(1) ?? '') ?? 0;
      if (seconds > 0) {
        _floodWaitUntil = DateTime.now().add(Duration(seconds: seconds));
        _events.add({
          '@type': 'darktgFloodWait',
          'seconds': seconds,
          'message': message,
        });
        return;
      }
    }
    _events.add(error);
  }

  void _sendAuthenticationRequest(Map<String, dynamic> request) {
    final remaining = floodWaitRemainingSeconds;
    if (remaining > 0) {
      _events.add({
        '@type': 'darktgFloodWait',
        'seconds': remaining,
        'message': 'Подождите перед следующей попыткой авторизации.',
      });
      return;
    }
    sendRawRequest(request);
  }

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
      'database_encryption_key': '',
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

  // App-level equivalent of the "send code" step.
  void sendCode(String phoneNumber) => setPhoneNumber(phoneNumber);

  void setPhoneNumber(String phoneNumber) => _sendAuthenticationRequest({
    '@type': 'setAuthenticationPhoneNumber',
    'phone_number': phoneNumber.trim(),
    'settings': {'@type': 'phoneNumberAuthenticationSettings'},
  });

  void checkCode(String code) =>
      _sendAuthenticationRequest({'@type': 'checkAuthenticationCode', 'code': code.trim()});

  // App-level equivalent of the "sign in with code" step.
  void signIn(String code) => checkCode(code);

  void setEmailAddress(String emailAddress) =>
      _sendAuthenticationRequest({
        '@type': 'setAuthenticationEmailAddress',
        'email_address': emailAddress.trim(),
      });

  void checkEmailCode(String code) => _sendAuthenticationRequest({
    '@type': 'checkAuthenticationEmailCode',
    'code': code.trim(),
  });

  void checkPassword(String password) => _sendAuthenticationRequest({
    '@type': 'checkAuthenticationPassword',
    'password': password,
  });

  void registerUser({required String firstName, String lastName = ''}) {
    _sendAuthenticationRequest({
      '@type': 'registerUser',
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'disable_notification': false,
    });
  }

  void dispose() {
    _workerPort?.send({'type': 'close'});
    _receivePort?.close();
    _isolate?.kill(priority: Isolate.immediate);
    _status = TdlibEngineStatus.notStarted;
    _parametersConfigured = false;
    _lastAuthorizationState = null;
    _floodWaitUntil = null;
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
    var shouldStop = false;
    commands.listen((dynamic command) {
      if (command is Map && command['type'] == 'send') {
        final request = command['request'];
        if (request is Map) {
          TdPlugin.instance.tdSend(clientId, jsonEncode(request));
        }
      } else if (command is Map && command['type'] == 'close') {
        shouldStop = true;
        TdPlugin.instance.tdSend(clientId, jsonEncode({'@type': 'close'}));
      }
    });
    mainPort.send({'type': 'ready', 'port': commands.sendPort});
    while (!shouldStop) {
      final raw = TdPlugin.instance.tdReceive(0.25);
      if (raw != null) mainPort.send({'type': 'update', 'raw': raw});
      await Future<void>.delayed(Duration.zero);
    }
    commands.close();
  } catch (error) {
    mainPort.send({'type': 'error', 'message': error.toString()});
    commands.close();
  }
}
