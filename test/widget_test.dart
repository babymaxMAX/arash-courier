// Пакет тестирования виджетов Flutter.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
// Тестируемое приложение (MyApp из main.dart).
import 'package:arash_curier/main.dart';

void main() {
  // testWidgets — асинхронный тест с WidgetTester (симуляция UI).
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Строим дерево виджетов MyApp в тестовой среде.
    await tester.pumpWidget(const MyApp());

    // Ищем текст «0» — в шаблонном тесте счётчика (может не совпасть с реальным UI).
    expect(find.text('0'), findsOneWidget);
    // Текста «1» ещё не должно быть.
    expect(find.text('1'), findsNothing);

    // Симулируем нажатие на иконку «+».
    await tester.tap(find.byIcon(Icons.add));
    // Перерисовываем один кадр после tap.
    await tester.pump();

    // После инкремента «0» исчезает.
    expect(find.text('0'), findsNothing);
    // Появляется «1».
    expect(find.text('1'), findsOneWidget);
  });
}
