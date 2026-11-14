import 'package:flutter_test/flutter_test.dart';
import 'package:darktg/main.dart';

void main() {
  testWidgets('DARKTG opens with its main navigation', (tester) async {
    await tester.pumpWidget(const DarkTgApp());

    expect(find.text('DARKTG'), findsOneWidget);
    expect(find.text('Чаты'), findsOneWidget);
    expect(find.text('Контакты'), findsOneWidget);
    expect(find.text('Настройки'), findsOneWidget);
  });
}
