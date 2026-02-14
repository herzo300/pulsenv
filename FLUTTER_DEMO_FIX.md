# 🐛 Проблема запуска Flutter Demo вместо приложения

## Описание проблемы

При запуске `flutter run` открывалось демо-приложение "Пульс Города" вместо основного приложения "СообщиО".

## Причина

В проекте были **два файла main.dart**:

1. **Правильный файл:** `./lib/main.dart` - Приложение "СообщиО"
   - Импортирует: `lib/screens/map_screen.dart`
   - Использует класс: `SoobshioApp`

2. **Демо файл:** `./lib/lib/main.dart` - Приложение "Пульс Города"
   - Импортирует: `flutter_map`, `flutter_map_marker_cluster`
   - Использует класс: `PulsGorodaApp`

Flutter автоматически использует файл `lib/main.dart` внутри директории проекта, поэтому при запуске из `./lib/` использовался неправильный файл.

## ✅ Решение

Демо файл переименован в `main_demo_backup.dart`:

```bash
mv ./lib/lib/main.dart ./lib/lib/main_demo_backup.dart
```

Теперь Flutter будет использовать правильный файл `./lib/main.dart` с приложением "СообщиО".

## 🚀 Запуск приложения

### Запуск Backend (Python)
```bash
cd C:\Soobshio_project
python main.py
```

### Запуск Frontend (Flutter Web)
```bash
cd C:\Soobshio_project\lib
flutter run -d chrome
```

### Запуск Frontend (Flutter Mobile)
```bash
cd C:\Soobshio_project\lib
flutter run
```

## 📁 Структура файлов

```
Soobshio_project/
├── lib/
│   ├── main.dart                    ✅ Правильный main (СообщиО)
│   ├── pubspec.yaml                 ✅ Конфигурация
│   └── lib/
│       ├── models/                   ✅ Модели
│       ├── screens/                  ✅ Экраны (map_screen.dart и т.д.)
│       ├── services/                 ✅ Сервисы
│       ├── widgets/                  ✅ Виджеты
│       └── main_demo_backup.dart      ✅ Бэкап демо (Пульс Города)
```

## 🎯 Правильный main.dart

**Файл:** `./lib/main.dart`

```dart
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'lib/screens/map_screen.dart';

Future<void> main() async {
  await SentryFlutter.init(
    (options) {
      options.dsn = 'ТВОЙ_SENTRY_DSN';
      options.tracesSampleRate = 1.0;
    },
    appRunner: () => runApp(const SoobshioApp()),
  );
}

class SoobshioApp extends StatelessWidget {
  const SoobshioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'СообщиО',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const ComplaintMapScreen(),
    );
  }
}
```

## 🔍 Проверка

После исправления проверьте, что Flutter использует правильный файл:

```bash
cd C:\Soobshio_project\lib
flutter run -d chrome
```

Должно открыться приложение **"СообщиО"** с картой, а не **"Пульс Города"**.

## ⚠️ Если проблема всё ещё есть

Если Flutter всё ещё показывает демо-приложение, попробуйте:

1. **Очистите кэш Flutter:**
   ```bash
   flutter clean
   flutter pub get
   ```

2. **Удалите демо-файл полностью:**
   ```bash
   rm ./lib/lib/main_demo_backup.dart
   ```

3. **Укажите точку входа явно:**
   ```bash
   flutter run -t lib/main.dart
   ```

---

**Статус:** ✅ Исправлено
**Дата:** 9 февраля 2026 г.
