import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../map/map_config.dart';

class JkhHouseStatus {
  final String status; // "normal" | "planned" | "emergency"
  final String statusCode; // "GREEN" | "YELLOW" | "RED"
  final String colorHex;
  final String auraColor;
  final String statusTitle;
  final String statusDescription;
  final String primaryTimer;
  final List<JkhOutageItem> outages;

  JkhHouseStatus({
    required this.status,
    required this.statusCode,
    required this.colorHex,
    required this.auraColor,
    required this.statusTitle,
    required this.statusDescription,
    required this.primaryTimer,
    required this.outages,
  });

  factory JkhHouseStatus.fromJson(Map<String, dynamic> json) {
    final rawOutages = (json['outages'] as List<dynamic>? ?? []);
    return JkhHouseStatus(
      status: json['status']?.toString() ?? 'normal',
      statusCode: json['status_code']?.toString() ?? 'GREEN',
      colorHex: json['color_hex']?.toString() ?? '#22C55E',
      auraColor: json['aura_color']?.toString() ?? '#22C55E',
      statusTitle: json['status_title']?.toString() ?? 'Всё в норме',
      statusDescription: json['status_description']?.toString() ?? 'Отключений не зафиксировано.',
      primaryTimer: json['primary_timer']?.toString() ?? '',
      outages: rawOutages.map((e) => JkhOutageItem.fromJson(e as Map<String, dynamic>)).toList(),
    );
  }

  factory JkhHouseStatus.fallbackNormal() {
    return JkhHouseStatus(
      status: 'normal',
      statusCode: 'GREEN',
      colorHex: '#22C55E',
      auraColor: '#22C55E',
      statusTitle: 'Всё в норме',
      statusDescription: 'Коммунальные службы работают в штатном режиме.',
      primaryTimer: '',
      outages: [],
    );
  }
}

class JkhOutageItem {
  final int id;
  final String title;
  final String? description;
  final String? address;
  final String incidentType;
  final String typeTitle;
  final String shortName;
  final String icon;
  final String colorHex;
  final int remainingSeconds;
  final String remainingText;
  final String displayTimer;

  JkhOutageItem({
    required this.id,
    required this.title,
    this.description,
    this.address,
    required this.incidentType,
    required this.typeTitle,
    required this.shortName,
    required this.icon,
    required this.colorHex,
    required this.remainingSeconds,
    required this.remainingText,
    required this.displayTimer,
  });

  factory JkhOutageItem.fromJson(Map<String, dynamic> json) {
    return JkhOutageItem(
      id: json['id'] as int? ?? 0,
      title: json['title']?.toString() ?? 'Отключение',
      description: json['description']?.toString(),
      address: json['address']?.toString(),
      incidentType: json['incident_type']?.toString() ?? 'water',
      typeTitle: json['type_title']?.toString() ?? 'Водоснабжение',
      shortName: json['short_name']?.toString() ?? 'Вода',
      icon: json['icon']?.toString() ?? 'water_drop',
      colorHex: json['color_hex']?.toString() ?? '#3B82F6',
      remainingSeconds: json['remaining_seconds'] as int? ?? 0,
      remainingText: json['remaining_text']?.toString() ?? '',
      displayTimer: json['display_timer']?.toString() ?? '',
    );
  }
}

class JkhOutageService extends ChangeNotifier {
  static final JkhOutageService instance = JkhOutageService._internal();

  factory JkhOutageService() => instance;

  JkhOutageService._internal();

  JkhHouseStatus? _currentStatus;
  List<JkhOutageItem> _allIncidents = [];
  bool _isLoading = false;

  JkhHouseStatus get currentStatus => _currentStatus ?? JkhHouseStatus.fallbackNormal();
  List<JkhOutageItem> get allIncidents => _allIncidents;
  bool get isLoading => _isLoading;

  Future<void> fetchHouseStatus({String? address, double? lat, double? lng}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final queryParams = <String, String>{};
      if (address != null && address.isNotEmpty) queryParams['address'] = address;
      if (lat != null) queryParams['lat'] = lat.toString();
      if (lng != null) queryParams['lng'] = lng.toString();

      final uri = Uri.parse('${MapConfig.backendApiBaseUrl}/api/v1/jkh/house-status').replace(queryParameters: queryParams);
      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        _currentStatus = JkhHouseStatus.fromJson(data);
      } else {
        _currentStatus = JkhHouseStatus.fallbackNormal();
      }
    } catch (e) {
      debugPrint('JkhOutageService fetch error: $e');
      _currentStatus = JkhHouseStatus.fallbackNormal();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<JkhOutageItem>> fetchAllIncidents() async {
    try {
      final uri = Uri.parse('${MapConfig.backendApiBaseUrl}/api/v1/jkh/incidents');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final rawList = data['incidents'] as List<dynamic>? ?? [];
        _allIncidents = rawList.map((e) => JkhOutageItem.fromJson(e as Map<String, dynamic>)).toList();
        notifyListeners();
        return _allIncidents;
      }
    } catch (e) {
      debugPrint('JkhOutageService fetchAllIncidents error: $e');
    }
    return [];
  }
}
