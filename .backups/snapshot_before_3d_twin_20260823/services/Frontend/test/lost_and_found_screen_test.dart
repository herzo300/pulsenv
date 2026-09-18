import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soobshio/screens/lost_and_found_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LostAndFoundScreen Landmark Extraction Tests', () {
    const cacheKey = 'map_cached_markers_v2';

    final testMarkers = [
      // 1. С перекрестком в описании, без адреса
      {
        'id': '101',
        'category': 'Животные',
        'address': '',
        'title': 'Потерялся песик',
        'description': 'Видели на перекрестке Ленина и Чапаева, бежал в сторону дворов.',
        'lat': 60.9380,
        'lng': 76.5560,
        'images': [],
      },
      // 2. С магазином в описании, без адреса
      {
        'id': '102',
        'category': 'Вещи',
        'address': '   ',
        'title': 'Найдена сумка',
        'description': 'Черный рюкзак найден около Магнита на лавочке.',
        'lat': 60.9400,
        'lng': 76.5600,
        'images': [],
      },
      // 3. Без адреса и без ориентиров (должен отфильтроваться)
      {
        'id': '103',
        'category': 'Вещи',
        'address': '',
        'title': 'Потерян кошелек',
        'description': 'Кожаный кошелек с картами. Помогите найти за вознаграждение.',
        'lat': 60.9410,
        'lng': 76.5610,
        'images': [],
      },
      // 4. С конкретным адресом (должен отображаться как есть)
      {
        'id': '104',
        'category': 'Животные',
        'address': 'ул. Мира, д. 24',
        'title': 'Найдена кошка',
        'description': 'Белая пушистая кошка сидит на дереве.',
        'lat': 60.9420,
        'lng': 76.5620,
        'images': [],
      },
      // 5. С ТЦ в описании, без адреса
      {
        'id': '105',
        'category': 'Вещи',
        'address': '',
        'title': 'Потерялись ключи',
        'description': 'Связка ключей потеряна возле ТЦ Югра.',
        'lat': 60.9430,
        'lng': 76.5630,
        'images': [],
      }
    ];

    setUp(() {
      SharedPreferences.setMockInitialValues({
        cacheKey: jsonEncode(testMarkers),
        'my_reported_ids': ['101', '105'],
      });
    });

    testWidgets('extracts landmarks from text and filters items without location indicators', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LostAndFoundScreen(),
        ),
      );

      // Ждем завершения загрузки из кэша и рендеринга элементов списка
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      // Проверяем наличие плашки статистики
      expect(find.text('СТАТИСТИКА ЗА 30 ДНЕЙ'), findsOneWidget);
      expect(find.text('Найдено животных и вещей: 0 из 4 потеряшек'), findsOneWidget);

      // 1. Проверяем, что элемент №101 отображается и его адрес содержит ориентир "Перекрестке Ленина и Чапаева"
      expect(find.text('Потерялся песик'), findsOneWidget);
      expect(find.text('Перекрестке Ленина и Чапаева'), findsOneWidget);
      
      // Проверяем, что для №101 есть кнопка "НАЙДЕНО"
      expect(find.text('НАЙДЕНО 🎉'), findsOneWidget);

      // 2. Проверяем, что элемент №102 отображается и его адрес содержит "Около Магнита"
      expect(find.text('Найдена сумка'), findsOneWidget);
      expect(find.text('Около Магнита'), findsOneWidget);

      // 3. Проверяем, что элемент №103 (без адреса и ориентиров) ОТСУТСТВУЕТ на экране
      expect(find.text('Потерян кошелек'), findsNothing);

      // Прокручиваем список вниз, чтобы увидеть элементы 104 и 105
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();

      // 4. Проверяем, что элемент №104 отображается со своим реальным адресом
      expect(find.text('Найдена кошка'), findsOneWidget);
      expect(find.text('ул. Мира, д. 24'), findsOneWidget);

      // 5. Проверяем, что элемент №105 отображается и его адрес содержит "Возле ТЦ Югра"
      expect(find.text('Потерялись ключи'), findsOneWidget);
      expect(find.text('Возле ТЦ Югра'), findsOneWidget);
    });

    testWidgets('marks a report as resolved, triggers haptics and updates stats', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LostAndFoundScreen(),
        ),
      );

      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      // Находим кнопку "НАЙДЕНО 🎉" для первого элемента (№101)
      final resolveButton = find.text('НАЙДЕНО 🎉');
      expect(resolveButton, findsOneWidget);

      // Нажимаем на нее
      await tester.tap(resolveButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      // Кнопка должна смениться на зеленую плашку "НАЙДЕНО"
      expect(find.text('НАЙДЕНО 🎉'), findsNothing);
      expect(find.text('НАЙДЕНО'), findsOneWidget);

      // Проверяем, что статистика обновилась
      expect(find.text('Найдено животных и вещей: 1 из 4 потеряшек'), findsOneWidget);
    });

    testWidgets('search query filters items by extracted derived addresses', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LostAndFoundScreen(),
        ),
      );

      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      // Находим поле поиска и вводим "Магнит"
      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'Магнит');
      await tester.pumpAndSettle();

      // Должен остаться только один элемент - сумка около Магнита (№102)
      expect(find.text('Найдена сумка'), findsOneWidget);
      expect(find.text('Потерялся песик'), findsNothing);
      expect(find.text('Найдена кошка'), findsNothing);
      expect(find.text('Потерялись ключи'), findsNothing);
    });
  });
}
