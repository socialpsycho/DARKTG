import 'package:flutter/material.dart';
import '../services/tdlib_service.dart';

class PrivacySettingsPage extends StatefulWidget {
  const PrivacySettingsPage({super.key});

  @override
  State<PrivacySettingsPage> createState() => _PrivacySettingsPageState();
}

class _PrivacySettingsPageState extends State<PrivacySettingsPage> {
  static const _settings = <_PrivacyOption>[
    _PrivacyOption(
      key: 'last_seen',
      title: 'Время последнего посещения',
      description: 'Кто может видеть, когда вы были в сети',
      icon: Icons.schedule,
      tdlibType: 'userPrivacySettingShowStatus',
    ),
    _PrivacyOption(
      key: 'profile_photo',
      title: 'Фотография профиля',
      description: 'Кто может видеть фотографию профиля',
      icon: Icons.account_circle_outlined,
      tdlibType: 'userPrivacySettingShowProfilePhoto',
    ),
    _PrivacyOption(
      key: 'calls',
      title: 'Звонки',
      description: 'Кто может вам звонить',
      icon: Icons.call_outlined,
      tdlibType: 'userPrivacySettingAllowCalls',
    ),
  ];

  final Map<String, bool> _enabled = {};
  bool _loading = true;
  String? _error;
  final Set<String> _saving = {};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<bool> _loadOption(_PrivacyOption option) async {
    final response = await TdlibService.instance.requestRaw({
      '@type': 'getUserPrivacySettingRules',
      'setting': {'@type': option.tdlibType},
    });
    final rules = response['rules'];
    if (rules is! List) return false;

    // Treat AllowAll and AllowContacts as enabled for the simple on/off UI.
    // Unknown/custom user rules remain visible as enabled when any allow rule exists.
    return rules.whereType<Map>().any((rule) {
      final type = rule['@type']?.toString() ?? '';
      return type == 'userPrivacySettingRuleAllowAll' ||
          type == 'userPrivacySettingRuleAllowContacts' ||
          type == 'userPrivacySettingRuleAllowUsers' ||
          type == 'userPrivacySettingRuleAllowChatMembers';
    });
  }

  Future<void> _loadAll() async {
    if (!TdlibService.instance.isReady) {
      setState(() {
        _loading = false;
        _error = 'Сначала подключите аккаунт Telegram.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final values = <String, bool>{};
      for (final option in _settings) {
        values[option.key] = await _loadOption(option);
      }
      if (!mounted) return;
      setState(() {
        _enabled
          ..clear()
          ..addAll(values);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _setOption(_PrivacyOption option, bool value) async {
    if (_saving.contains(option.key)) return;
    final previous = _enabled[option.key] ?? false;
    setState(() {
      _enabled[option.key] = value;
      _saving.add(option.key);
    });
    try {
      await TdlibService.instance.requestRaw({
        '@type': 'setUserPrivacySettingRules',
        'setting': {'@type': option.tdlibType},
        'rules': {
          '@type': 'userPrivacySettingRules',
          'rules': [
            {
              '@type': value
                  ? 'userPrivacySettingRuleAllowAll'
                  : 'userPrivacySettingRuleRestrictAll',
            },
          ],
        },
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _enabled[option.key] = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось изменить настройку: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving.remove(option.key));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Конфиденциальность'),
        actions: [
          IconButton(
            tooltip: 'Обновить',
            onPressed: _loading ? null : _loadAll,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _loadAll,
                          child: const Text('Повторить'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView(
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(18, 18, 18, 10),
                      child: Text(
                        'ДОСТУП К ДАННЫМ',
                        style: TextStyle(
                          color: Color(0xFF229ED9),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    for (final option in _settings)
                      SwitchListTile(
                        secondary: Icon(option.icon),
                        title: Text(option.title),
                        subtitle: Text(option.description),
                        value: _enabled[option.key] ?? false,
                        onChanged: _saving.contains(option.key)
                            ? null
                            : (value) => _setOption(option, value),
                      ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(18, 16, 18, 24),
                      child: Text(
                        'Переключатель «Включено» устанавливает правило «Все пользователи», а «Выключено» — «Никто». Это упрощённый режим: существующие исключения для отдельных пользователей и контактов при изменении будут заменены.',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _PrivacyOption {
  final String key;
  final String title;
  final String description;
  final IconData icon;
  final String tdlibType;

  const _PrivacyOption({
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.tdlibType,
  });
}
