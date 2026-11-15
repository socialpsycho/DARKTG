import 'package:shared_preferences/shared_preferences.dart';

/// Persistent local policy for outbound activity signals sent by DARKTG.
class GhostModeService {
  GhostModeService._();

  static final GhostModeService instance = GhostModeService._();

  SharedPreferences? _preferences;

  bool hideReadReceipts = false;
  bool hideTyping = false;
  bool hideOnlineStatus = false;
  bool useCustomDeviceModel = true;

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
    useCustomDeviceModel = _preferences!.getBool('darktg_custom_device_model') ?? true;
  }

  Future<void> setAllEnabled(bool value) async {
    await setHideReadReceipts(value);
    await setHideTyping(value);
    await setHideOnlineStatus(value);
  }

  Future<void> setUseCustomDeviceModel(bool value) async {
    useCustomDeviceModel = value;
    await _preferences?.setBool('darktg_custom_device_model', value);
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

    if (type == 'viewMessages' && hideReadReceipts) return true;

    // Recording a voice note is a typing/activity signal and is hidden by
    // the same preference as ordinary "typing..." notifications.
    if (type == 'sendChatAction' && hideTyping) {
      final action = request['action'];
      if (action is Map) {
        final actionType = action['@type']?.toString();
        if (actionType == 'chatActionTyping' ||
            actionType == 'chatActionRecordingVoiceNote' ||
            actionType == 'chatActionChoosingSticker' ||
            actionType == 'chatActionUploadingPhoto' ||
            actionType == 'chatActionUploadingVideo' ||
            actionType == 'chatActionUploadingDocument') {
          return true;
        }
      }
    }

    // TDLib has no SetOnline method: online state is controlled by
    // setOption(name: "online"). Allow false so the client can stay offline;
    // suppress any attempt to publish online while Ghost Mode is active.
    if (isGhostModeEnabled &&
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
