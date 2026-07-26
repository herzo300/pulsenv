// lib/services/city_provider.dart
// Провайдер активного города. Сохраняет выбор между сессиями.
import 'package:flutter/foundation.dart';
import '../data/city_config.dart';
import 'app_state_service.dart';

class CityProvider extends ChangeNotifier {
  CityProvider._() {
    // Listen to AppStateService changes to keep in sync
    AppStateService.instance.addListener(() {
      notifyListeners();
    });
  }
  static final CityProvider _instance = CityProvider._();
  factory CityProvider() => _instance;

  CityConfig get activeCity => CityConfig.byId(AppStateService.instance.state.activeCity);

  /// Загрузить сохранённый город при старте приложения
  Future<void> init() async {
    // Handled by AppStateService.initialize()
  }

  /// Сменить активный город
  Future<void> switchCity(CityConfig city) async {
    if (activeCity.id == city.id) return;
    await AppStateService.instance.saveActiveCity(city.id);
    notifyListeners();
  }

  /// Проверить, относится ли пуш к активному городу
  bool isActiveCity(String? cityId) {
    if (cityId == null || cityId.isEmpty) return true; // нет тега — показываем всем
    return cityId == activeCity.id;
  }
}
