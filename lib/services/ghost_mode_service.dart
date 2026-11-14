import 'package:shared_preferences/shared_preferences.dart';

/// Persistent local policy for requests that DARKTG sends through TDLib.
class GhostModeService {
  GhostModeService._();
  static final GhostModeService instance = GhostModeService._();

  SharedPreferences? _preferences;
  bool hideReadReceipts = false;
  bool hideTyping = false;
  bool hideOnlineStatus = false;

  bool get enabled => hideReadReceipts || hideTyping || hideOnlineStatus;

  Future<void> initialize() async {
    _preferences ??= await SharedPreferences.getInstance();
    hideReadReceipts = _preferences!.getBool('ghost_hide_read_receipts') ?? false;
    hideTyping = _preferences!.getBool('ghost_hide_typing') ?? false;
    hideOnlineStatus = _preferences!.getBool('ghost_hide_online') ?? false;
  }

  Future<void> setHideReadReceipts(bool value) async {
    hideReadReceipts = value;
    await _preferences?.setBool('ghost_hide_read_receipts', value);
  }

  Future<void> setHideTyping(bool value) async {
    hideTyping = value;
    await _preferences?.setBool('ghost_hide_typing', value);
  }

  Future<void> setHideOnlineStatus(bool value) async {
    hideOnlineStatus = value;
    await _preferences?.setBool('ghost_hide_online', value);
  }

  /// Returns true when the request would reveal activity the user chose to hide.
  bool shouldSuppress(Map<String, dynamic> request) {
    final type = request['@type'];
    if (hideReadReceipts && type == 'viewMessages') return true;
    if (hideTyping && type == 'sendChatAction') return true;
    if (hideOnlineStatus &&
        type == 'setOption' &&
        request['name'] == 'online' &&
        request['value'] is Map &&
        (request['value'] as Map)['value'] == true) {
      return true;
    }
    return false;
  }
}
