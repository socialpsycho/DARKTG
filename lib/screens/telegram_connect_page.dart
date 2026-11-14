import 'dart:async';

import 'package:flutter/material.dart';

import '../services/tdlib_service.dart';

class TelegramConnectPage extends StatefulWidget {
  const TelegramConnectPage({super.key});

  @override
  State<TelegramConnectPage> createState() => _TelegramConnectPageState();
}

class _TelegramConnectPageState extends State<TelegramConnectPage> {
  final _apiId = TextEditingController();
  final _apiHash = TextEditingController();
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  StreamSubscription<Map<String, dynamic>>? _subscription;

  String _step = 'loading';
  String _message = 'Подключаем TDLib…';
  bool _busy = false;

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
        setState(() {
          _step = 'credentials';
          _message = 'Введите параметры приложения Telegram API.';
        });
        return;
      }
      if (service.status == TdlibEngineStatus.failed ||
          service.status == TdlibEngineStatus.unsupportedPlatform) {
        setState(() {
          _step = 'error';
          _message = service.lastError ??
              'Подключение доступно только в Android-сборке.';
        });
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    if (mounted) {
      setState(() {
        _step = 'error';
        _message = 'TDLib не запустилась. Проверьте Android-сборку.';
      });
    }
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
            _step = 'credentials';
            _message = 'Нужно настроить подключение Telegram API.';
            break;
          case 'authorizationStateWaitPhoneNumber':
            _step = 'phone';
            _message = 'Введите номер телефона аккаунта.';
            break;
          case 'authorizationStateWaitCode':
            _step = 'code';
            _message = 'Введите код, полученный в Telegram.';
            break;
          case 'authorizationStateWaitPassword':
            _step = 'password';
            _message = 'Для аккаунта включена двухэтапная проверка.';
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
            _message = 'Сессия TDLib закрыта.';
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

  Future<void> _configure() async {
    final id = int.tryParse(_apiId.text.trim());
    if (id == null || _apiHash.text.trim().isEmpty) {
      setState(() => _message = 'Проверьте API ID и API Hash.');
      return;
    }
    try {
      await TdlibService.instance.configure(
        apiId: id,
        apiHash: _apiHash.text,
        systemLanguageCode: 'ru',
        deviceModel: 'DARKTG Android',
        applicationVersion: '0.4.0',
      );
      setState(() {
        _step = 'waiting';
        _busy = true;
        _message = 'Настраиваем подключение…';
      });
    } catch (error) {
      setState(() => _message = error.toString());
    }
  }

  void _sendPhone() {
    if (_phone.text.trim().isEmpty) return;
    TdlibService.instance.setPhoneNumber(_phone.text);
    setState(() {
      _busy = true;
      _message = 'Отправляем запрос на вход…';
    });
  }

  void _sendCode() {
    if (_code.text.trim().isEmpty) return;
    TdlibService.instance.checkCode(_code.text);
    setState(() {
      _busy = true;
      _message = 'Проверяем код…';
    });
  }

  void _sendPassword() {
    if (_password.text.isEmpty) return;
    TdlibService.instance.checkPassword(_password.text);
    _password.clear();
    setState(() {
      _busy = true;
      _message = 'Проверяем пароль…';
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _apiId.dispose();
    _apiHash.dispose();
    _phone.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Widget _field(TextEditingController controller, String label,
      {bool secret = false, TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: secret,
        keyboardType: keyboard,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Подключение Telegram')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(_message),
          const SizedBox(height: 20),
          if (_step == 'credentials') ...[
            _field(_apiId, 'API ID', keyboard: TextInputType.number),
            _field(_apiHash, 'API Hash', secret: true),
            const Text(
              'Эти параметры вводятся только в приложении и не должны отправляться в чат или публиковаться в репозитории.',
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _configure, child: const Text('Продолжить')),
          ],
          if (_step == 'phone') ...[
            _field(_phone, 'Номер телефона', keyboard: TextInputType.phone),
            FilledButton(onPressed: _sendPhone, child: const Text('Получить код')),
          ],
          if (_step == 'code') ...[
            _field(_code, 'Код из Telegram', keyboard: TextInputType.number),
            FilledButton(onPressed: _sendCode, child: const Text('Подтвердить код')),
          ],
          if (_step == 'password') ...[
            _field(_password, 'Пароль двухэтапной проверки', secret: true),
            FilledButton(onPressed: _sendPassword, child: const Text('Подтвердить')),
          ],
          if (_step == 'ready')
            const ListTile(
              leading: Icon(Icons.check_circle, color: Colors.green),
              title: Text('Аккаунт авторизован'),
              subtitle: Text('Синхронизация чатов будет следующим этапом.'),
            ),
          if (_step == 'error' || _step == 'closed')
            TextButton(
              onPressed: _waitForEngine,
              child: const Text('Повторить проверку'),
            ),
          if (_busy) const LinearProgressIndicator(),
        ],
      ),
    );
  }
}
