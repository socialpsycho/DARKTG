import 'dart:convert';
import 'dart:io';

import 'package:handy_tdlib_next/handy_tdlib_next.dart';

enum TdlibEngineStatus {
  notStarted,
  ready,
  unsupportedPlatform,
  failed,
}

/// Android TDLib bridge.
///
/// This initializes the native TDLib engine and creates a client ID.
/// It does not authenticate a Telegram account or start receiving updates yet.
class TdlibService {
  TdlibService._();

  static final TdlibService instance = TdlibService._();

  TdlibEngineStatus _status = TdlibEngineStatus.notStarted;
  int? _clientId;
  String? _lastError;

  TdlibEngineStatus get status => _status;
  bool get isReady => _status == TdlibEngineStatus.ready;
  String? get lastError => _lastError;

  Future<void> initialize() async {
    if (_status == TdlibEngineStatus.ready) return;

    if (!Platform.isAndroid) {
      _status = TdlibEngineStatus.unsupportedPlatform;
      return;
    }

    try {
      await TdPlugin.initialize();
      _clientId = TdPlugin.instance.tdCreateClientId();
      _status = TdlibEngineStatus.ready;
      _lastError = null;
    } catch (error) {
      _status = TdlibEngineStatus.failed;
      _lastError = error.toString();
    }
  }

  /// Sends a raw TDLib JSON request after initialization.
  ///
  /// Do not call this with credentials or secrets embedded in source code.
  void sendRawRequest(Map<String, dynamic> request) {
    final clientId = _clientId;
    if (!isReady || clientId == null) {
      throw StateError('TDLib is not initialized.');
    }

    TdPlugin.instance.tdSend(clientId, jsonEncode(request));
  }
}
