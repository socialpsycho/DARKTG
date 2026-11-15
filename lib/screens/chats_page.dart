import 'dart:async';
import 'package:flutter/material.dart';
import '../main.dart' show accent, darkBackground, darkSurface;
import '../services/tdlib_service.dart';
import '../services/cache_service.dart';
import 'chat_conversation_page.dart';

class ChatsPage extends StatefulWidget {
  final VoidCallback? onOpenGhostMode;
  final VoidCallback? onNewMessage;
  const ChatsPage({super.key, this.onOpenGhostMode, this.onNewMessage});
  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  final Map<int, Map<String, dynamic>> _chats = {};
  StreamSubscription<Map<String, dynamic>>? _subscription;
  String _query = '';
  String _folder = 'Все';
  bool _loading = false;
  String? _error;
  static const _folders = ['Все', 'Чисто чилл', 'Жынсы', 'экспресс'];
  int _int(dynamic v) => v is int ? v : int.tryParse(v?.toString() ?? '') ?? 0;

  @override
  void initState() {
    super.initState();
    _subscription = TdlibService.instance.events.listen(_onEvent);
    if (TdlibService.instance.isReady) _loadChats();
  }

  void _loadChats() {
    if (!TdlibService.instance.isReady || _loading) return;
    setState(() { _loading = true; _error = null; });
    try {
      TdlibService.instance.sendRawRequest({'@type':'getChats','chat_list':{'@type':'chatListMain'},'limit':100});
    } catch (e) { setState(() { _loading = false; _error = e.toString(); }); }
  }

  void _onEvent(Map<String, dynamic> e) {
    if (!mounted) return;
    final t = e['@type'];
    if (t == 'updateAuthorizationState') {
      final s = e['authorization_state'];
      if (s is Map && s['@type'] == 'authorizationStateReady') _loadChats();
    } else if (t == 'chats') {
      final ids = e['chat_ids'];
      if (ids is List) {
        for (final id in ids.whereType<int>()) {
          try { TdlibService.instance.sendRawRequest({'@type':'getChat','chat_id':id}); } catch (_) {}
        }
        setState(() => _loading = false);
      }
    } else if (t == 'chat' || t == 'updateNewChat') {
      final c = t == 'chat' ? e : e['chat'];
      if (c is Map && c['id'] is int) {
        setState(() { _chats[c['id'] as int] = Map<String,dynamic>.from(c); _loading = false; });
      }
    } else if (t == 'updateNewMessage') {
      final m = e['message'];
      if (m is Map && m['chat_id'] is int && _chats.containsKey(m['chat_id'])) {
        setState(() => _chats[m['chat_id']]['last_message'] = m);
      }
    } else if (t == 'updateChatTitle' || t == 'updateChatLastMessage' ||
        t == 'updateChatPosition' || t == 'updateChatReadOutbox' || t == 'updateChatUnreadCount') {
      final id = e['chat_id'];
      if (id is int && _chats.containsKey(id)) setState(() {
        final c = _chats[id]!;
        if (t == 'updateChatTitle') c['title'] = e['title'];
        if (t == 'updateChatLastMessage') c['last_message'] = e['last_message'];
        if (t == 'updateChatPosition') c['positions'] = e['positions'];
        if (t == 'updateChatReadOutbox') c['last_read_outbox_message_id'] = e['last_read_outbox_message_id'];
        if (t == 'updateChatUnreadCount') c['unread_count'] = e['unread_count'];
      });
    } else if (t == 'error') {
      setState(() { _loading = false; _error = e['message']?.toString() ?? 'Ошибка Telegram'; });
    } else if (t == 'darktgTdlibReady') _loadChats();
  }

  String _preview(Map<String,dynamic> c) {
    final m = c['last_message'];
    if (m is! Map || m['content'] is! Map) return 'Нет сообщений';
    final v = m['content'] as Map;
    final k = v['@type'];
    if (k == 'messageText' && v['text'] is Map) return (v['text'] as Map)['text']?.toString() ?? '';
    const labels = {'messagePhoto':'Фото','messageVideo':'Видео','messageVoiceNote':'Голосовое сообщение','messageDocument':'Файл','messageSticker':'Стикер','messageAnimation':'GIF'};
    return labels[k] ?? 'Сообщение';
  }

  String _time(Map<String,dynamic> c) {
    final m = c['last_message'];
    if (m is! Map) return '';
    final n = _int(m['date']);
    if (n <= 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(n * 1000).toLocal();
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
    }
    return '${d.day.toString().padLeft(2,'0')}.${d.month.toString().padLeft(2,'0')}';
  }

  bool _pinned(Map<String,dynamic> c) {
    final p = c['positions'];
    return p is List && p.any((x) => x is Map && x['list'] is Map &&
      x['list']['@type'] == 'chatListMain' && x['is_pinned'] == true);
  }

  @override
  void dispose() { _subscription?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final list = _chats.values.where((c) => (c['title']?.toString().toLowerCase() ?? '').contains(_query.toLowerCase())).toList()
      ..sort((a,b) {
        final ap=a['positions'], bp=b['positions'];
        final ao=ap is List && ap.isNotEmpty && ap.first is Map ? _int(ap.first['order']) : 0;
        final bo=bp is List && bp.isNotEmpty && bp.first is Map ? _int(bp.first['order']) : 0;
        return bo.compareTo(ao);
      });
    return Scaffold(
      backgroundColor: darkBackground,
      body: SafeArea(bottom:false, child: Column(children:[
        Padding(padding: const EdgeInsets.fromLTRB(12,8,10,10), child: Row(children:[
          TextButton(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Управление папками скоро появится'))),
            style:TextButton.styleFrom(foregroundColor:accent), child:const Text('Изм.')),
          const Spacer(),
          Container(width:40,height:40,decoration:BoxDecoration(shape:BoxShape.circle,color:const Color(0xFF253C59),border:Border.all(color:Colors.white12)),
            child:const Icon(Icons.person_rounded,color:Colors.white70)),
          const Spacer(),
          IconButton(tooltip:'Фильтр',onPressed:()=>setState(()=>_folder='Все'),icon:const Icon(Icons.filter_list_rounded,color:Colors.white70)),
          IconButton(tooltip:'Ghost Mode',onPressed:widget.onOpenGhostMode,icon:const Icon(Icons.visibility_off_rounded,color:accent)),
          IconButton(tooltip:'Новое сообщение',onPressed:widget.onNewMessage,
            style:IconButton.styleFrom(backgroundColor:accent,foregroundColor:Colors.white,fixedSize:const Size(40,40)),
            icon:const Icon(Icons.edit_rounded,size:20)),
        ])),
        SizedBox(height:44,child:ListView.separated(
          padding:const EdgeInsets.symmetric(horizontal:14),scrollDirection:Axis.horizontal,itemCount:_folders.length,
          separatorBuilder:(_,__)=>const SizedBox(width:8),
          itemBuilder:(context,i){final f=_folders[i];final selected=f==_folder;return ChoiceChip(
            label:Text(f),selected:selected,showCheckmark:false,onSelected:(_)=>setState(()=>_folder=f),
            backgroundColor:darkSurface,selectedColor:const Color(0xFF173B58),
            side:BorderSide(color:selected?accent.withValues(alpha:.65):Colors.white10),
            labelStyle:TextStyle(color:selected?Colors.white:Colors.white60,fontSize:13),
            shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(18)));},
        )),
        Padding(padding:const EdgeInsets.fromLTRB(14,12,14,8),child:TextField(
          onChanged:(v)=>setState(()=>_query=v),style:const TextStyle(fontSize:15),
          decoration:InputDecoration(hintText:'Поиск',hintStyle:const TextStyle(color:Colors.white38),
            prefixIcon:const Icon(Icons.search_rounded,color:Colors.white38),filled:true,fillColor:darkSurface,
            contentPadding:const EdgeInsets.symmetric(vertical:0),
            border:OutlineInputBorder(borderRadius:BorderRadius.circular(16),borderSide:BorderSide.none)))),
        Expanded(child:list.isEmpty ? Center(child:Padding(padding:const EdgeInsets.all(28),child:Column(mainAxisSize:MainAxisSize.min,children:[
          Icon(TdlibService.instance.isReady?Icons.chat_bubble_outline_rounded:Icons.link_off,size:42,color:Colors.white38),
          const SizedBox(height:12),
          Text(_error ?? (TdlibService.instance.isReady?(_loading?'Загружаем чаты…':'Чатов пока нет'):'Подключите Telegram, чтобы увидеть чаты.'),
            textAlign:TextAlign.center,style:const TextStyle(color:Colors.white60)),
          if(_error!=null || TdlibService.instance.isReady) TextButton(onPressed:_loadChats,child:const Text('Повторить')),
        ]))) : ListView.separated(
          padding:const EdgeInsets.only(top:3,bottom:100),itemCount:list.length,
          separatorBuilder:(_,__)=>const Divider(height:1,indent:84,color:Color(0xFF202333)),
          itemBuilder:(context,i){
            final c=list[i];final id=_int(c['id']);final title=c['title']?.toString()??'Чат';
            final unread=_int(c['unread_count']);final m=c['last_message'];
            final outgoing=m is Map && m['is_outgoing']==true;
            final read=outgoing && _int(c['last_read_outbox_message_id'])>=_int(m['id']) && _int(m['id'])>0;
            return ListTile(
              contentPadding:const EdgeInsets.symmetric(horizontal:16,vertical:5),
              leading:CacheService.instance.avatar(fileId:CacheService.instance.fileIdFromChat(c),
                imageUrl:CacheService.instance.imageUrlFromChat(c),localPath:CacheService.instance.localPathFromChat(c),fallbackText:title,radius:28),
              title:Row(children:[Expanded(child:Text(title,maxLines:1,overflow:TextOverflow.ellipsis,
                style:const TextStyle(fontSize:16,fontWeight:FontWeight.w600))),
                if(_pinned(c)) const Padding(padding:EdgeInsets.only(left:5),child:Icon(Icons.push_pin_rounded,size:14,color:Colors.white38))]),
              subtitle:Row(children:[
                if(outgoing) ...[Icon(read?Icons.done_all_rounded:Icons.done_rounded,size:17,color:read?const Color(0xFF42B8F4):Colors.white38),const SizedBox(width:3)],
                Expanded(child:Text(_preview(c),maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white54,fontSize:13)))]),
              trailing:SizedBox(width:52,child:Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.end,children:[
                Text(_time(c),style:TextStyle(fontSize:11,color:unread>0?accent:Colors.white38)),
                if(unread>0) ...[const SizedBox(height:5),Container(constraints:const BoxConstraints(minWidth:19,minHeight:19),
                  padding:const EdgeInsets.symmetric(horizontal:5),alignment:Alignment.center,
                  decoration:const BoxDecoration(color:accent,shape:BoxShape.circle),
                  child:Text(unread>99?'99+':'$unread',style:const TextStyle(color:Colors.white,fontSize:10,fontWeight:FontWeight.w700)))],
              ])),
              onTap:()=>Navigator.of(context).push(MaterialPageRoute<void>(builder:(_)=>ChatConversationPage(chatId:id,title:title))));
          })),
      ])),
    );
  }
}
