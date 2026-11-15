import 'dart:ui';
import 'package:flutter/material.dart';
import '../main.dart' show accent;

class FloatingBottomNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final int unreadChats;
  final int unreadCalls;
  const FloatingBottomNavigationBar({super.key,required this.selectedIndex,required this.onDestinationSelected,this.unreadChats=0,this.unreadCalls=0});

  @override
  Widget build(BuildContext context) {
    const items=[
      (Icons.people_alt_outlined,Icons.people_alt_rounded,'Контакты'),
      (Icons.call_outlined,Icons.call_rounded,'Звонки'),
      (Icons.chat_bubble_outline_rounded,Icons.chat_bubble_rounded,'Чаты'),
      (Icons.settings_outlined,Icons.settings_rounded,'Настройки'),
    ];
    final badges=[0,unreadCalls,unreadChats,0];
    return SafeArea(minimum:const EdgeInsets.fromLTRB(18,0,18,12),child:ClipRRect(
      borderRadius:BorderRadius.circular(27),child:BackdropFilter(
        filter:ImageFilter.blur(sigmaX:18,sigmaY:18),
        child:Container(height:66,decoration:BoxDecoration(
          color:const Color(0xE6192030),borderRadius:BorderRadius.circular(27),
          border:Border.all(color:Colors.white.withValues(alpha:.10)),
          boxShadow:const [BoxShadow(color:Colors.black38,blurRadius:22,offset:Offset(0,8))]),
          child:Row(children:List.generate(items.length,(i){
            final selected=selectedIndex==i;final item=items[i];final badge=badges[i];
            return Expanded(child:InkWell(onTap:()=>onDestinationSelected(i),child:Column(
              mainAxisAlignment:MainAxisAlignment.center,children:[
                Stack(clipBehavior:Clip.none,children:[
                  Icon(selected?item.$2:item.$1,size:23,color:selected?accent:Colors.white60),
                  if(badge>0) Positioned(right:-10,top:-6,child:Container(
                    padding:const EdgeInsets.symmetric(horizontal:4),
                    constraints:const BoxConstraints(minWidth:15,minHeight:15),
                    decoration:const BoxDecoration(color:Color(0xFFFF4D5E),shape:BoxShape.circle),
                    child:Text(badge>99?'99+':'$badge',textAlign:TextAlign.center,
                      style:const TextStyle(color:Colors.white,fontSize:9,fontWeight:FontWeight.w700)))),
                ]),
                const SizedBox(height:4),
                Text(item.$3,style:TextStyle(fontSize:10,color:selected?Colors.white:Colors.white54,
                  fontWeight:selected?FontWeight.w600:FontWeight.w400)),
              ])));
          }))))));
  }
}
