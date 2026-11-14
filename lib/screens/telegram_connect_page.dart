import 'dart:async';
import 'package:flutter/material.dart';
import '../services/tdlib_service.dart';

class TelegramConnectPage extends StatefulWidget {
  const TelegramConnectPage({super.key});
  @override
  State<TelegramConnectPage> createState() => _TelegramConnectPageState();
}

class _TelegramConnectPageState extends State<TelegramConnectPage> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  StreamSubscription<Map<String, dynamic>>? _subscription;
  String _step = 'loading';
  String _message = 'Запускаем защищённое подключение…';
  bool _busy = false;
  bool _configured = false;

  @override
  void initState() {
    super.initState();
    _subscription = TdlibService.instance.events.listen(_onTdlibEvent);
    _waitForEngine();
  }

  Future<void> _waitForEngine() async {
    for (var i = 0; i < 40; i++) {
      if (!mounted) return;
      final service = TdlibService.instance;
      if (service.isReady) {
        if (!TdlibService.hasBuildCredentials) {
          setState(() {
            _step = 'error';
            _message = 'Эта сборка ещё не настроена владельцем DARKTG. API ID и API Hash не нужно вводить пользователям.';
          });
          return;
        }
        if (!_configured) {
          _configured = true;
          try {
            await service.configureFromBuild();
            if (mounted) setState(() {
              _step = 'waiting';
              _message = 'Подготавливаем вход в Telegram…';
              _busy = true;
            });
          } catch (error) {
            if (mounted) setState(() {
              _step = 'error';
              _message = error.toString();
            });
          }
        }
        return;
      }
      if (service.status == TdlibEngineStatus.failed ||
          service.status == TdlibEngineStatus.unsupportedPlatform) {
        setState(() {
          _step = 'error';
          _message = service.lastError ?? 'Подключение доступно только в Android-сборке.';
        });
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    if (mounted) setState(() {
      _step = 'error';
      _message = 'TDLib не запустилась. Проверьте Android-сборку.';
    });
  }

  void _onTdlibEvent(Map<String, dynamic> event) {
    if (!mounted) return;
    if (event['@type'] == 'updateAuthorizationState') {
      final state = event['authorization_state'];
      final type = state is Map ? state['@type']?.toString() : null;
      setState(() {
        _busy = false;
        switch (type) {
          case 'authorizationStateWaitTdlibParameters':
            _step = 'waiting';
            _message = 'Настраиваем защищённую сессию…';
            break;
          case 'authorizationStateWaitPhoneNumber':
            _step = 'phone';
            _message = 'Введите номер телефона для входа.';
            break;
          case 'authorizationStateWaitCode':
            _step = 'code';
            _message = 'Введите код, полученный от Telegram.';
            break;
          case 'authorizationStateWaitPassword':
            _step = 'password';
            _message = 'Введите пароль двухэтапной проверки Telegram.';
            break;
          case 'authorizationStateReady':
            _step = 'ready';
            _message = 'Telegram подключён.';
            break;
          case 'authorizationStateLoggingOut':
            _message = 'Выполняется выход…';
            break;
          case 'authorizationStateClosed':
            _step = 'closed';
            _message = 'Сессия Telegram закрыта.';
            break;
        }
      });
    } else if (event['@type'] == 'error') {
      setState(() {
        _busy = false;
        _message = event['message']?.toString() ?? 'Ошибка Telegram API.';
      });
    }
  }

  void _sendPhone() {
    if (_phone.text.trim().isEmpty) return;
    TdlibService.instance.setPhoneNumber(_phone.text);
    setState(() { _busy = true; _message = 'Запрашиваем код у Telegram…'; });
  }
  void _sendCode() {
    if (_code.text.trim().isEmpty) return;
    TdlibService.instance.checkCode(_code.text);
    setState(() { _busy = true; _message = 'Проверяем код…'; });
  }
  void _sendPassword() {
    if (_password.text.isEmpty) return;
    TdlibService.instance.checkPassword(_password.text);
    _password.clear();
    setState(() { _busy = true; _message = 'Проверяем пароль…'; });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _phone.dispose(); _code.dispose(); _password.dispose();
    super.dispose();
  }

  Widget _field(TextEditingController controller, String label,
      {bool secret = false, TextInputType? keyboard}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextField(
      controller: controller, obscureText: secret, keyboardType: keyboard,
      autocorrect: false,
      decoration: InputDecoration(labelText: label, border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16))),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Подключение Telegram')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Icon(Icons.shield_outlined, size: 54, color: Color(0xFF8B5CF6)),
        const SizedBox(height: 16),
        Text(_message, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        if (_step == 'phone') ...[
          _field(_phone, 'Номер телефона', keyboard: TextInputType.phone),
          FilledButton(onPressed: _busy ? null : _sendPhone, child: const Text('Получить код')),
        ],
        if (_step == 'code') ...[
          _field(_code, 'Код из Telegram', keyboard: TextInputType.number),
          FilledButton(onPressed: _busy ? null : _sendCode, child: const Text('Подтвердить код')),
        ],
        if (_step == 'password') ...[
          _field(_password, 'Пароль двухэтапной проверки', secret: true),
          FilledButton(onPressed: _busy ? null : _sendPassword, child: const Text('Подтвердить')),
        ],
        if (_step == 'ready')
          const ListTile(leading: Icon(Icons.check_circle, color: Colors.green),
            title: Text('Аккаунт авторизован'),
            subtitle: Text('Можно возвращаться к списку чатов.')),
        if (_step == 'error' || _step == 'closed')
          TextButton(onPressed: _waitForEngine, child: const Text('Повторить проверку')),
        if (_busy) const LinearProgressIndicator(),
      ]),
    );
  }
}
