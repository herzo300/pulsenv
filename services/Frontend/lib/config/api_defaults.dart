/// Единая точка правды для сетевых адресов бэкенда.
///
/// Все дефолтные URL собираются здесь и могут быть переопределены
/// на этапе сборки без правок кода:
///
/// ```bash
/// flutter build apk \
///   --dart-define=BACKEND_BASE_URL=https://api.pulse-city.ru \
///   --dart-define=BACKEND_PUBLIC_FALLBACK=https://api.pulse-city.ru \
///   --dart-define=BACKEND_FALLBACK_URLS=https://backup.pulse-city.ru
/// ```
///
/// Продакшн-значение по умолчанию (VPS Timeweb).
/// При переезде на HTTPS-домен достаточно поменять одну константу здесь.
const String kDefaultBackendHost = 'http://45.153.68.59';

/// Адрес бэкенда с явным портом API (используется как резервный кандидат).
const String kDefaultBackendHostWithPort = '$kDefaultBackendHost:8000';
