import '../services/city_provider.dart';

/// Единое отображаемое имя приложения в UI.
abstract final class AppBranding {
  static const String appName = 'Пульс города';
  static String get cityName => CityProvider().activeCity.name;
  static const String tagline = 'Ситуационный контур города';
  static String get splashSubtitle => '$cityName · карта, камеры, дайджест';
}

