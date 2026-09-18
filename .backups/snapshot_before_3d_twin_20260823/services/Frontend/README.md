# Пульс города — Flutter

Мобильное приложение городского ситуационного контура (Нижневартовск).

## Запуск

```bash
flutter run --dart-define=PUBLIC_API_BASE_URL=http://127.0.0.1:8000
```

Продакшен (замените домен на ваш публичный HTTPS URL):

```bash
flutter build apk --release \
  --dart-define=PUBLIC_API_BASE_URL=https://your-domain.com \
  --dart-define=BACKEND_PUBLIC_FALLBACK=https://your-domain.com
```

Опциональные overrides:

```bash
flutter run \
  --dart-define=BACKEND_BASE_URL=https://your-domain.com \
  --dart-define=SATELLITE_TILE_URL=https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}
```

Конфигурация читается из `lib/map/map_config.dart` через `String.fromEnvironment`.
