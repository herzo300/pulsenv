import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:soobshio/screens/lost_and_found_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // На экране есть бесконечные анимации (пульс кнопки, конфетти, радар),
  // поэтому pumpAndSettle никогда не завершается. Используем ограниченную
  // серию pump (суммарно ~3 с — меньше таймаута сетевого запроса в 6 с).
  Future<void> settleBounded(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  group('LostAndFoundScreen (Бюро находок)', () {
    // Ключ кэша должен совпадать с _complaintsCachePrefKey в экране.
    const cacheKey = 'my_lost_and_found_items';

    final testItems = [
      {
        'id': 'a1',
        'category': 'Животные',
        'address': 'Парк Победы',
        'title': 'Потерялся песик Рекс',
        'description': 'Бежал в сторону дворов.',
        'lat': 60.9380,
        'lng': 76.5560,
        'status': 'open',
        'images': <String>[],
      },
      {
        'id': 'a2',
        'category': 'Животные',
        'address': 'ул. Мира, д. 24',
        'title': 'Найдена кошка Муся',
        'description': 'Белая пушистая кошка.',
        'lat': 60.9420,
        'lng': 76.5620,
        'status': 'resolved',
        'images': <String>[],
      },
      {
        'id': 'a3',
        'category': 'Животные',
        'address': 'Набережная',
        'title': 'Найден щенок корги',
        'description': 'Сидел на скамейке.',
        'lat': 60.9360,
        'lng': 76.5590,
        'status': 'open',
        'images': <String>[],
      },
      {
        'id': 't1',
        'category': 'Вещи',
        'address': 'ТЦ Югра Молл',
        'title': 'Потеряна связка ключей',
        'description': 'С брелоком StarLine.',
        'lat': 60.9420,
        'lng': 76.5910,
        'status': 'open',
        'images': <String>[],
      },
      {
        'id': 't2',
        'category': 'Вещи',
        'address': 'ул. Мира, д. 60',
        'title': 'Найдено портмоне',
        'description': 'Черный кожаный кошелек.',
        'lat': 60.9450,
        'lng': 76.5820,
        'status': 'resolved',
        'images': <String>[],
      },
    ];

    setUp(() {
      SharedPreferences.setMockInitialValues({
        cacheKey: jsonEncode(testItems),
      });
    });

    testWidgets('renders app bar, tabs with counts and stats bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LostAndFoundScreen(),
        ),
      );

      await settleBounded(tester);

      // Шапка
      expect(find.text('БЮРО НАХОДОК'), findsOneWidget);

      // Капсульные вкладки со счётчиками: 3 питомца и 2 вещи из кэша
      expect(find.text('🐾 ПИТОМЦЫ'), findsOneWidget);
      expect(find.text('🔑 ВЕЩИ И ДОКУМЕНТЫ'), findsOneWidget);
      expect(find.text('3'), findsWidgets);
      expect(find.text('2'), findsWidgets);

      // Мини-статистика
      expect(find.textContaining('Возвращено владельцам:'), findsOneWidget);

      // Кнопка добавления объявления
      expect(find.text('Нашел/Потерял'), findsOneWidget);
    });

    testWidgets('shows cached pet card on the first tab', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LostAndFoundScreen(),
        ),
      );

      await settleBounded(tester);

      // Первая вкладка (питомцы) показывает карточку из кэша
      expect(find.text('Потерялся песик Рекс'), findsOneWidget);
      expect(find.textContaining('Парк Победы'), findsWidgets);
    });

    testWidgets('switching to things tab shows cached thing card', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: LostAndFoundScreen(),
        ),
      );

      await settleBounded(tester);

      // Переключаемся на вкладку вещей
      await tester.tap(find.text('🔑 ВЕЩИ И ДОКУМЕНТЫ'));
      await settleBounded(tester);

      // На второй вкладке видна карточка вещи из кэша
      expect(find.text('Потеряна связка ключей'), findsOneWidget);
    });
  });
}
