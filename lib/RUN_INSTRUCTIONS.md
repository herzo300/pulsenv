# Этот файл указывает Flutter использовать правильный main.dart

## Инструкция по запуску приложения

### 1. Запуск Backend
```bash
cd C:\Soobshio_project
python main.py
```

### 2. Запуск Frontend (Web)
```bash
cd C:\Soobshio_project\lib
flutter run -d chrome
```

### 3. Запуск Frontend (Mobile)
```bash
cd C:\Soobshio_project\lib
flutter run
```

## Важные примечания:

1. **Основной main.dart**: `./lib/main.dart` (приложение "СообщиО")
2. **Демо main.dart**: `./lib/lib/main_demo_backup.dart` (приложение "Пульс Города")

Если Flutter всё ещё показывает демо-приложение, попробуйте:

```bash
cd C:\Soobshio_project\lib
flutter run -t lib/main.dart
```

Или удалите демо-файл:

```bash
cd C:\Soobshio_project\lib\lib
rm main_demo_backup.dart
```
