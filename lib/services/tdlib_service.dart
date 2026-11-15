import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:handy_tdlib_next/handy_tdlib_next.dart';
import 'package:path_provider/path_provider.dart';
import '../core/telegram/config.dart';
import 'ghost_mode_service.dart';

enum TdlibEngineStatus { notStarted, starting, ready, unsupportedPlatform, failed }

class TdlibService {
  TdlibService._();
  static final TdlibService instance = TdlibService._();

  static const int buildApiId = Config.apiId;
  static const String buildApiHash = Config.apiHash;
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
  bool _autoDownloadConfigured = false;
  DateTime? _floodWaitUntil;
  Map<String, dynamic>? _lastAuthorizationState;
  int _nextRequestId = 0;
  final Map<String, Completer<Map<String, dynamic>>> _pendingRequests = {};

  TdlibEngineStatus get status => _status;
  Map<String, dynamic>? get lastAuthorizationState => _lastAuthorizationState;
  int get floodWaitRemainingSeconds {
    final until = _floodWaitUntil;
    if (until == null) return 0;
    final remainingMs = until.difference(DateTime.now()).inMilliseconds;
    return remainingMs > 0 ? (remainingMs / 1000).ceil() : 0;
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
      debugPrint('[DARKTG][TDLib] Initialization failed: $_lastError');
      _events.add({'@type': 'darktgTdlibError', 'message': _lastError});
    }
  }

  Future<void> retryInitialization() async {
    dispose();
    await initialize();
  }

  void _handleWorkerMessage(dynamic message) {
    if (message is! Map) return;
    final type = message['type'];
    if (type == 'ready' && message['port'] is SendPort) {
      _workerPort = message['port'] as SendPort;
      _status = TdlibEngineStatus.ready;
      _lastError = null;
      _events.add({'@type': 'darktgTdlibReady'});
      // Ask TDLib for its current authorization state. Some TDLib builds do
      // not deliver the initial state until this request is made.
      try {
        sendRawRequest({'@type': 'getAuthorizationState'});
        debugPrint('[DARKTG][TDLib] Sent getAuthorizationState');
      } catch (error) {
        _lastError = 'Не удалось запросить состояние авторизации: $error';
        debugPrint('[DARKTG][TDLib] getAuthorizationState failed: $_lastError');
        _events.add({
          '@type': 'darktgTdlibStartupError',
          'message': _lastError,
        });
      }
    } else if (type == 'error') {
      _lastError = message['message']?.toString() ?? 'TDLib worker error';
      debugPrint('[DARKTG][TDLib] Worker error: $_lastError');
      _status = TdlibEngineStatus.failed;
      _events.add({'@type': 'darktgTdlibError', 'message': _lastError});
    } else if (type == 'update' && message['event'] is Map) {
      final decoded = Map<String, dynamic>.from(message['event'] as Map);
      final extra = decoded['@extra']?.toString();
      if (extra != null) {
        final completer = _pendingRequests.remove(extra);
        if (completer != null) {
          if (decoded['@type'] == 'error') {
            debugPrint('[DARKTG][TDLib] TdError: ${decoded['message'] ?? decoded}');
            completer.completeError(StateError(decoded['message']?.toString() ?? 'TDLib request failed'));
          } else {
            completer.complete(decoded);
          }
          return;
        }
      }
      try {
        if (decoded['@type'] == 'error') {
          _handleTdlibError(decoded);
          return;
        }
          final responseType = decoded['@type']?.toString() ?? '';
          if (responseType == 'updateAuthorizationState') {
            final auth = decoded['authorization_state'];
            if (auth is Map) _acceptAuthorizationState(Map<String, dynamic>.from(auth));
          } else if (responseType.startsWith('authorizationState')) {
            // getAuthorizationState returns the authorizationState object
            // directly rather than wrapping it in updateAuthorizationState.
            _acceptAuthorizationState(decoded);
          }
          _events.add(decoded);
          final auth = decoded['authorization_state'];
          if (decoded['@type'] == 'updateAuthorizationState' &&
              auth is Map && auth['@type'] == 'authorizationStateReady' &&
              GhostModeService.instance.hideOnlineStatus && isReady) {
            setOnline(false);
          }
      } catch (_) {}
    }
  }

  void _acceptAuthorizationState(Map<String, dynamic> auth) {
    final type = auth['@type']?.toString();
    debugPrint('[DARKTG][TDLib] Authorization state: $type');
    _lastAuthorizationState = auth;
    _events.add({
      '@type': 'updateAuthorizationState',
      'authorization_state': auth,
    });
    if (type == 'authorizationStateWaitTdlibParameters' &&
        !_parametersConfigured) {
      unawaited(_configureInitialParameters());
    }
    if (type == 'authorizationStateReady') {
      unawaited(configureAutoDownloadSettings());
    }
  }

  /// Set conservative automatic download limits on mobile data, higher limits
  /// on Wi-Fi, and disable automatic downloads while roaming.
  Future<void> configureAutoDownloadSettings() async {
    if (_autoDownloadConfigured || !isReady) return;
    _autoDownloadConfigured = true;
    const profiles = <Map<String, dynamic>>[
      {
        'type': 'networkTypeMobile',
        'enabled': true,
        'photo': 5 * 1024 * 1024,
        'video': 10 * 1024 * 1024,
        'other': 5 * 1024 * 1024,
        'bitrate': 512,
      },
      {
        'type': 'networkTypeWiFi',
        'enabled': true,
        'photo': 20 * 1024 * 1024,
        'video': 100 * 1024 * 1024,
        'other': 100 * 1024 * 1024,
        'bitrate': 2000,
      },
      {
        'type': 'networkTypeMobileRoaming',
        'enabled': false,
        'photo': 0,
        'video': 0,
        'other': 0,
        'bitrate': 0,
      },
    ];
    for (final profile in profiles) {
      try {
        await requestRaw({
          '@type': 'setAutoDownloadSettings',
          'type': {'@type': profile['type']},
          'settings': {
            '@type': 'autoDownloadSettings',
            'is_auto_download_enabled': profile['enabled'],
            'max_photo_file_size': profile['photo'],
            'max_video_file_size': profile['video'],
            'max_other_file_size': profile['other'],
            'video_upload_bitrate': profile['bitrate'],
            'preload_large_videos': false,
            'preload_next_audio': true,
            'preload_stories': false,
            'use_less_data_for_calls': profile['type'] != 'networkTypeWiFi',
          },
        });
      } catch (error) {
        debugPrint('[DARKTG][TDLib] Auto-download settings failed: ' + error.toString());
      }
    }
  }

  /// Sends a TDLib JSON request after applying the global Ghost Mode policy.
  /// All outbound requests must pass through this method.
  void sendRawRequest(Map<String, dynamic> request) {
    if (GhostModeService.instance.shouldSuppress(request)) return;
    final port = _workerPort;
    if (!isReady || port == null) throw StateError('TDLib is not ready.');
    port.send({'type': 'send', 'request': request});
  }

  /// Sends a request and awaits its response using TDLib's @extra correlation.
  Future<Map<String, dynamic>> requestRaw(
    Map<String, dynamic> request, {
    Duration timeout = const Duration(seconds: 20),
  }) {
    if (GhostModeService.instance.shouldSuppress(request)) {
      return Future.error(StateError('Request blocked by Ghost Mode.'));
    }
    final port = _workerPort;
    if (!isReady || port == null) {
      return Future.error(StateError('TDLib is not ready.'));
    }
    final id = 'darktg-${++_nextRequestId}';
    final completer = Completer<Map<String, dynamic>>();
    _pendingRequests[id] = completer;
    port.send({'type': 'send', 'request': {...request, '@extra': id}});
    return completer.future.timeout(timeout, onTimeout: () {
      _pendingRequests.remove(id);
      throw TimeoutException('TDLib request timed out');
    });
  }

  /// TDLib JSON wrapper for SendChatAction / ChatActionTyping.
  /// The central request filter prevents the signal leaving this device
  /// whenever Ghost Mode's typing protection is enabled.
  void sendChatAction({
    required int chatId,
    required Map<String, dynamic> action,
  }) {
    sendRawRequest({
      '@type': 'sendChatAction',
      'chat_id': chatId,
      'action': action,
    });
  }

  /// TDLib JSON wrapper for ViewMessages. It is suppressed centrally when
  /// the read-receipt protection is enabled.
  void viewMessages({
    required int chatId,
    required List<int> messageIds,
    bool forceRead = false,
  }) {
    if (messageIds.isEmpty) return;
    sendRawRequest({
      '@type': 'viewMessages',
      'chat_id': chatId,
      'message_ids': messageIds,
      'force_read': forceRead,
    });
  }

  /// TDLib does not expose a SetOnline request. Its online signal is the
  /// "online" option; the central filter blocks attempts to set it to true.
  void setOnline(bool online) {
    sendRawRequest({
      '@type': 'setOption',
      'name': 'online',
      'value': {'@type': 'optionValueBoolean', 'value': online},
    });
  }

  Future<void> configureFromBuild() async {
    if (_parametersConfigured) return;
    _parametersConfigured = true;
    try {
      await configure(
        apiId: buildApiId,
        apiHash: buildApiHash,
        systemLanguageCode: Config.systemLanguageCode,
        deviceModel: GhostModeService.instance.useCustomDeviceModel
            ? Config.deviceModel
            : 'Android',
        applicationVersion: Config.applicationVersion,
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
      final message = 'Не удалось настроить TDLib: $error';
      _lastError = message;
      debugPrint('[DARKTG][TDLib] setTdlibParameters failed: $message');
      _events.add({
        '@type': 'darktgTdlibStartupError',
        'message': message,
      });
    }
  }

  void _handleTdlibError(Map<String, dynamic> error) {
    final message = error['message']?.toString() ?? 'Неизвестная ошибка TDLib';
    debugPrint('[DARKTG][TDLib] TdError: $message');
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
    await requestRaw({
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
    'code': {
      '@type': 'emailAddressAuthenticationCode',
      'code': code.trim(),
    },
  });

  void checkPassword(String password) => _sendAuthenticationRequest({
    '@type': 'checkAuthenticationPassword',
    'password': password,
  });

  /// Ends the current Telegram authorization session.
  void logOut() => _sendAuthenticationRequest({'@type': 'logOut'});

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
    _lastError = null;
    _parametersConfigured = false;
    _autoDownloadConfigured = false;
    _lastAuthorizationState = null;
    _floodWaitUntil = null;
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) completer.completeError(StateError('TDLib service disposed.'));
    }
    _pendingRequests.clear();
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
      if (raw != null) {
        try {
          // Parse TDLib JSON on the worker isolate, not the UI isolate.
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            mainPort.send({'type': 'update', 'event': Map<String, dynamic>.from(decoded)});
          }
        } catch (_) {
          // Ignore malformed native payloads without blocking the UI isolate.
        }
      }
      await Future<void>.delayed(Duration.zero);
    }
    commands.close();
  } catch (error) {
    mainPort.send({'type': 'error', 'message': error.toString()});
    commands.close();
  }
}
