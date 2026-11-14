import 'dart:async';
import 'package:flutter/material.dart';

import '../main.dart' show accent, darkSurface;
import '../services/tdlib_service.dart';
import 'chat_conversation_page.dart';

/// Contacts are loaded from the authenticated TDLib account.
class ContactsPage extends StatefulWidget {
  const ContactsPage({super.key});

  @override
  State<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends State<ContactsPage> {
  final Map<int, Map<String, dynamic>> _users = {};
  StreamSubscription<Map<String, dynamic>>? _subscription;
  String _query = '';
  bool _loading = false;
  int? _openingUserId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _subscription = TdlibService.instance.events.listen(_onEvent);
    if (TdlibService.instance.isReady) _loadContacts();
  }

  void _loadContacts() {
    if (!TdlibService.instance.isReady || _loading) return;
    setState(() { _loading = true; _error = null; });
    try {
      TdlibService.instance.sendRawRequest({'@type': 'getContacts'});
    } catch (error) {
      setState(() { _loading = false; _error = error.toString(); });
    }
  }

  void _onEvent(Map<String, dynamic> event) {
    if (!mounted) return;
    final type = event['@type'];
    if (type == 'updateAuthorizationState') {
      final state = event['authorization_state'];
      if (state is Map && state['@type'] == 'authorizationStateReady') {
        _loadContacts();
      }
    } else if (type == 'darktgTdlibReady') {
      // The authorization state will trigger the request once the account is ready.
    } else if (type == 'users') {
      final ids = event['user_ids'];
      if (ids is List) {
        for (final id in ids.whereType<int>()) {
          try {
            TdlibService.instance.sendRawRequest({'@type': 'getUser', 'user_id': id});
          } catch (_) {}
        }
        setState(() => _loading = false);
      }
    } else if (type == 'user' || type == 'updateUser') {
      final user = type == 'user' ? event : event['user'];
      if (user is Map && user['id'] is int) {
        setState(() => _users[user['id'] as int] = Map<String, dynamic>.from(user));
      }
    } else if (type == 'chat' && _openingUserId != null) {
      final chatType = event['type'];
      if (chatType is Map && chatType['@type'] == 'chatTypePrivate' &&
          chatType['user_id'] == _openingUserId) {
        final chatId = event['id'];
        final user = _users[_openingUserId];
        final title = _displayName(user ?? {});
        _openingUserId = null;
        if (chatId is int) {
          Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => ChatConversationPage(chatId: chatId, title: title),
          ));
        }
      }
    } else if (type == 'error') {
      setState(() {
        _loading = false;
        _openingUserId = null;
        _error = event['message']?.toString() ?? 'Ошибка Telegram';
      });
    }
  }

  String _displayName(Map<String, dynamic> user) {
    final first = user['first_name']?.toString() ?? '';
    final last = user['last_name']?.toString() ?? '';
    final name = '$first $last'.trim();
    return name.isEmpty ? (user['username']?.toString() ?? 'Пользователь') : name;
  }

  String _searchText(Map<String, dynamic> user) =>
      '${_displayName(user)} ${user['username'] ?? ''}'.toLowerCase();

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contacts = _users.values
        .where((user) => _query.isEmpty || _searchText(user).contains(_query.toLowerCase()))
        .toList()
      ..sort((a, b) => _displayName(a).toLowerCase().compareTo(_displayName(b).toLowerCase()));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.people_alt_outlined, color: accent, size: 26),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Контакты', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                Text('Ваши контакты Telegram', style: TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            )),
            IconButton(onPressed: _loadContacts, icon: const Icon(Icons.refresh)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: TextField(
            onChanged: (value) => setState(() => _query = value.trim()),
            decoration: InputDecoration(
              hintText: 'Найти контакт',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: darkSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: contacts.isNotEmpty
              ? ListView.separated(
                  itemCount: contacts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
                  itemBuilder: (context, index) {
                    final user = contacts[index];
                    final id = user['id'] as int;
                    final name = _displayName(user);
                    final username = user['username']?.toString() ?? '';
                    final photo = user['profile_photo'];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: accent.withValues(alpha: .18),
                        child: Text(name.isEmpty ? '?' : name.characters.first.toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(username.isEmpty ? 'Контакт Telegram' : '@$username'),
                      trailing: _openingUserId == id
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.chevron_right, color: Colors.white38),
                      onTap: _openingUserId == null ? () {
                        setState(() { _openingUserId = id; _error = null; });
                        try {
                          TdlibService.instance.sendRawRequest({
                            '@type': 'createPrivateChat',
                            'user_id': id,
                            'force': false,
                          });
                        } catch (error) {
                          setState(() { _openingUserId = null; _error = error.toString(); });
                        }
                      } : null,
                    );
                  },
                )
              : Center(child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(TdlibService.instance.isReady ? Icons.people_outline : Icons.link_off,
                      size: 42, color: Colors.white54),
                    const SizedBox(height: 12),
                    Text(_error ?? (TdlibService.instance.isReady
                      ? (_loading ? 'Загружаем контакты…' : 'Контактов не найдено')
                      : 'Подключите Telegram, чтобы увидеть контакты.'),
                      textAlign: TextAlign.center),
                    if (_error != null || TdlibService.instance.isReady)
                      TextButton(onPressed: _loadContacts, child: const Text('Повторить')),
                  ]),
                )),
        ),
        if (_error != null && contacts.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(_error!, style: const TextStyle(color: Colors.orangeAccent)),
          ),
      ],
    );
  }
}
