import 'dart:async';
import 'package:flutter/material.dart';
import '../services/tdlib_service.dart';

class TelegramConnectPage extends StatefulWidget {
  const TelegramConnectPage({super.key});

  @override
  State<TelegramConnectPage> createState() => _TelegramConnectPageState();
}

class _TelegramConnectPageState extends State<TelegramConnectPage> {
  final _countryCode = TextEditingController(text: '+');
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _email = TextEditingController();
  final _emailCode = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  StreamSubscription<Map<String, dynamic>>? _subscription;

  String _step = 'loading';
  String _message = 'Запускаем защищённое подключение…';
  bool _busy = false;
  String? _phoneNumber;

  @override
  void initState() {
    super.initState();
    _subscription = TdlibService.instance.events.listen(_onTdlibEvent);
    _syncAuthorizationState();
  }

  void _syncAuthorizationState() {
    final state = TdlibService.instance.lastAuthorizationState;
    if (state != null) {
      _applyAuthorizationState(state['@type']?.toString());
      return;
    }
    _waitForEngine();
  }

  Future<void> _waitForEngine() async {
    for (var i = 0; i < 80; i++) {
      if (!mounted) return;
      final service = TdlibService.instance;
      if (service.lastAuthorizationState != null) {
        _applyAuthorizationState(
          service.lastAuthorizationState!['@type']?.toString(),
        );
        return;
      }
      if (service.status == TdlibEngineStatus.failed ||
          service.status == TdlibEngineStatus.unsupportedPlatform) {
        setState(() {
          _step = 'error';
          _busy = false;
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
        _busy = false;
        _message = 'TDLib не запустилась. Проверьте Android-сборку.';
      });
    }
  }

  void _onTdlibEvent(Map<String, dynamic> event) {
    if (!mounted) return;
    if (event['@type'] == 'updateAuthorizationState') {
      final state = event['authorization_state'];
      if (state is Map) _applyAuthorizationState(state['@type']?.toString());
    } else if (event['@type'] == 'darktgFloodWait') {
      final seconds = (event['seconds'] as num?)?.toInt() ?? 0;
      setState(() {
        _busy = false;
        _message = 'Telegram просит подождать $seconds сек.';
      });
    } else if (event['@type'] == 'error') {
      setState(() {
        _busy = false;
        _message = event['message']?.toString() ?? 'Ошибка Telegram API.';
      });
    }
  }

  void _applyAuthorizationState(String? type) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      switch (type) {
        case 'authorizationStateWaitTdlibParameters':
          _step = 'loading';
          _message = 'Настраиваем защищённую сессию…';
          _busy = true;
          break;
        case 'authorizationStateWaitPhoneNumber':
          _step = 'phone';
          _message = 'Введите код страны и номер телефона.';
          break;
        case 'authorizationStateWaitCode':
          _step = 'code';
          _message = 'Введите код, полученный в Telegram или по SMS.';
          break;
        case 'authorizationStateWaitPassword':
          _step = 'password';
          _message = 'Введите пароль двухэтапной проверки.';
          break;
        case 'authorizationStateWaitEmailAddress':
          _step = 'email';
          _message = 'Введите адрес электронной почты для подтверждения.';
          break;
        case 'authorizationStateWaitEmailCode':
          _step = 'emailCode';
          _message = 'Введите код подтверждения из электронной почты.';
          break;
        case 'authorizationStateWaitRegistration':
          _step = 'registration';
          _message = 'Укажите имя для нового аккаунта.';
          break;
        case 'authorizationStateWaitOtherDeviceConfirmation':
          _step = 'otherDevice';
          _message = 'Подтвердите вход на другом устройстве Telegram.';
          break;
        case 'authorizationStateReady':
          _step = 'ready';
          _message = 'Telegram подключён.';
          break;
        case 'authorizationStateLoggingOut':
          _step = 'loading';
          _message = 'Выполняется выход…';
          _busy = true;
          break;
        case 'authorizationStateClosed':
          _step = 'closed';
          _message = 'Сессия закрыта. Повторите запуск авторизации.';
          break;
        default:
          _step = 'loading';
          _message = 'Ожидаем состояние авторизации Telegram…';
          _busy = true;
      }
    });
  }

  String _normalizedPhone() {
    final country = _countryCode.text.replaceAll(RegExp(r'[^0-9+]'), '');
    final number = _phone.text.replaceAll(RegExp(r'[^0-9]'), '');
    final prefix = country.startsWith('+') ? country : '+$country';
    return '$prefix$number';
  }

  void _sendPhone() {
    final phone = _normalizedPhone();
    if (!RegExp(r'^\+[1-9][0-9]{5,14}$').hasMatch(phone)) {
      setState(() => _message = 'Проверьте код страны и номер телефона.');
      return;
    }
    _phoneNumber = phone;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _message = 'Запрашиваем код у Telegram…';
    });
    TdlibService.instance.setPhoneNumber(phone);
  }

  void _sendCode() {
    final value = _code.text.trim();
    if (value.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _message = 'Проверяем код…';
    });
    TdlibService.instance.checkCode(value);
  }

  void _sendPassword() {
    if (_password.text.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _message = 'Проверяем пароль…';
    });
    TdlibService.instance.checkPassword(_password.text);
    _password.clear();
  }

  void _sendEmail() {
    if (_email.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _message = 'Отправляем запрос подтверждения…';
    });
    TdlibService.instance.setEmailAddress(_email.text.trim());
  }

  void _sendEmailCode() {
    if (_emailCode.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _message = 'Проверяем код…';
    });
    TdlibService.instance.checkEmailCode(_emailCode.text.trim());
  }

  void _sendRegistration() {
    if (_firstName.text.trim().isEmpty) return;
    setState(() {
      _busy = true;
      _message = 'Создаём аккаунт…';
    });
    TdlibService.instance.registerUser(
      firstName: _firstName.text,
      lastName: _lastName.text,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _countryCode.dispose();
    _phone.dispose();
    _code.dispose();
    _password.dispose();
    _email.dispose();
    _emailCode.dispose();
    _firstName.dispose();
    _lastName.dispose();
    super.dispose();
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool secret = false,
    TextInputType? keyboard,
    TextInputAction? action,
    void Function(String)? onSubmitted,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        obscureText: secret,
        keyboardType: keyboard,
        textInputAction: action,
        autocorrect: false,
        enableSuggestions: !secret,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _submit(String label, VoidCallback callback) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      onPressed: _busy ? null : callback,
      child: Text(label),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('DARKTG · Авторизация'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(22),
          children: [
            const SizedBox(height: 24),
            const Icon(Icons.shield_moon_outlined,
                size: 58, color: Color(0xFF229ED9)),
            const SizedBox(height: 18),
            const Text(
              'Добро пожаловать в DARKTG',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            Text(_message, textAlign: TextAlign.center),
            const SizedBox(height: 28),
            if (_step == 'phone') ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 94,
                    child: _field(
                      _countryCode,
                      'Код страны',
                      keyboard: TextInputType.phone,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field(
                      _phone,
                      'Номер телефона',
                      keyboard: TextInputType.phone,
                      action: TextInputAction.done,
                      onSubmitted: (_) => _sendPhone(),
                    ),
                  ),
                ],
              ),
              _submit('Получить код', _sendPhone),
            ],
            if (_step == 'code') ...[
              if (_phoneNumber != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text('Номер: $_phoneNumber',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white60)),
                ),
              _field(
                _code,
                'Код из Telegram / SMS',
                keyboard: TextInputType.number,
                action: TextInputAction.done,
                onSubmitted: (_) => _sendCode(),
              ),
              _submit('Подтвердить код', _sendCode),
            ],
            if (_step == 'password') ...[
              _field(
                _password,
                'Пароль двухэтапной проверки',
                secret: true,
                action: TextInputAction.done,
                onSubmitted: (_) => _sendPassword(),
              ),
              _submit('Войти', _sendPassword),
            ],
            if (_step == 'email') ...[
              _field(_email, 'Электронная почта',
                  keyboard: TextInputType.emailAddress),
              _submit('Продолжить', _sendEmail),
            ],
            if (_step == 'emailCode') ...[
              _field(_emailCode, 'Код из письма',
                  keyboard: TextInputType.number),
              _submit('Подтвердить', _sendEmailCode),
            ],
            if (_step == 'registration') ...[
              _field(_firstName, 'Имя'),
              _field(_lastName, 'Фамилия (необязательно)'),
              _submit('Зарегистрироваться', _sendRegistration),
            ],
            if (_step == 'otherDevice')
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Откройте Telegram на уже подключённом устройстве и подтвердите запрос на вход.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            if (_step == 'loading' || _busy) ...[
              const SizedBox(height: 18),
              const LinearProgressIndicator(),
            ],
            if (_step == 'error' || _step == 'closed')
              TextButton(
                onPressed: _waitForEngine,
                child: const Text('Повторить проверку'),
              ),
          ],
        ),
      ),
    );
  }
}
