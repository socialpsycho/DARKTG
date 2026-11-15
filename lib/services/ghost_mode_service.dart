import 'package:shared_preferences/shared_preferences.dart';

/// Persistent local policy for outbound activity signals sent by DARKTG.
class GhostModeService {
  GhostModeService._();

  static final GhostModeService instance = GhostModeService._();

  SharedPreferences? _preferences;

  bool hideReadReceipts = false;
  bool hideTyping = false;
  bool hideOnlineStatus = false;

  /// True when at least one Ghost Mode protection is enabled.
  bool get isGhostModeEnabled => enabled;

  bool get enabled =>
      hideReadReceipts || hideTyping || hideOnlineStatus;

  Future<void> initialize() async {
    _preferences ??= await SharedPreferences.getInstance();
    hideReadReceipts =
        _preferences!.getBool('ghost_hide_read_receipts') ?? false;
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

  /// Central outbound-request filter. Incoming TDLib updates (including
  /// updateUserStatus) are deliberately not filtered here.
  bool shouldSuppress(Map<String, dynamic> request) {
    final type = request['@type'];

    if (hideReadReceipts && type == 'viewMessages') {
      return true;
    }

    // TDLib's JSON method is sendChatAction. This blocks typing, recording,
    // uploading and other chat-action signals while the option is enabled.
    if (hideTyping && type == 'sendChatAction') {
      return true;
    }

    // TDLib has no SetOnline method: online state is controlled by
    // setOption(name: "online", value: optionValueBoolean).
    if (hideOnlineStatus &&
        (type == 'setOnline' ||
            (type == 'setOption' && request['name'] == 'online')) &&
        _onlineValue(request) == true) {
      return true;
    }

    return false;
  }

  bool? _onlineValue(Map<String, dynamic> request) {
    if (request['@type'] == 'setOnline') {
      return request['online'] as bool?;
    }

    final value = request['value'];
    if (value is Map && value['@type'] == 'optionValueBoolean') {
      return value['value'] as bool?;
    }
    return null;
  }
}
