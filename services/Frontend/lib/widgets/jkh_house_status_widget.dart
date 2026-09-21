import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import '../services/device_location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;
import '../data/nizhnevartovsk_houses.dart';
import '../services/jkh_outage_service.dart';
import '../services/neighbor_community_websocket_service.dart';
import '../services/reports_repository.dart';
import '../services/uk_fallback_data.dart';
import '../screens/uk_companies_screen.dart';
import '../screens/complaint_form_screen.dart';
import '../theme/pulse_colors.dart';
import 'app_ui.dart';
import 'report_detail_sheet.dart';
import 'package:http/http.dart' as http;
import '../map/map_config.dart';
import '../screens/smart_meter_scanner_screen.dart';
import '../screens/jkh_digital_twin_screen.dart';
import 'house_passport_bento_grid.dart';
import '../services/hermes_house_sentinel_service.dart';

class JkhHouseStatusWidget extends StatefulWidget {
  final String? address;
  final double? lat;
  final double? lng;
  final List<Map<String, dynamic>>? nearbySignals;
  final List<Map<String, dynamic>>? houseNews;

  const JkhHouseStatusWidget({
    super.key,
    this.address,
    this.lat,
    this.lng,
    this.nearbySignals,
    this.houseNews,
  });

  @override
  State<JkhHouseStatusWidget> createState() => _JkhHouseStatusWidgetState();
}

class _JkhHouseStatusWidgetState extends State<JkhHouseStatusWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _auraController;
  Timer? _countdownTimer;

  String _selectedAddress = 'проспект Победы, 3';
  bool _isSubscribedToHouse = true;

  // Сигналы и жалобы по выбранному дому
  List<Map<String, dynamic>> _houseSignals = [];
  bool _loadingSignals = false;

  // Соседские просьбы о взаимопомощи
  List<Map<String, dynamic>> _communityPosts = [];

  bool get _isWinterSeason {
    final m = DateTime.now().month;
    return m == 11 || m == 12 || m == 1 || m == 2 || m == 3 || m == 4;
  }

  @override
  void initState() {
    super.initState();
    if (widget.address != null && widget.address!.isNotEmpty) {
      _selectedAddress = widget.address!;
    }
    _loadSavedAddress();
    _loadCommunityPosts();
    _loadHouseSignals(_selectedAddress);
    _auraController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadSavedAddress() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('jkh_user_selected_house');
    final sub = prefs.getBool('jkh_house_subscribed') ?? true;
    if (saved != null && saved.isNotEmpty && mounted) {
      setState(() {
        _selectedAddress = saved;
        _isSubscribedToHouse = sub;
      });
      _fetchForAddress(saved);
    }
  }

  Future<void> _saveAddress(String address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jkh_user_selected_house', address);
    _fetchForAddress(address);
    HermesHouseSentinelService.instance.activateHouseMonitoring(address, context: context);
  }

  Future<void> _toggleSubscription() async {
    final prefs = await SharedPreferences.getInstance();
    final next = !_isSubscribedToHouse;
    await prefs.setBool('jkh_house_subscribed', next);
    if (mounted) {
      setState(() {
        _isSubscribedToHouse = next;
      });
    }
    if (next) {
      HermesHouseSentinelService.instance.activateHouseMonitoring(_selectedAddress, context: context);
    }
  }

  void _fetchForAddress(String address) {
    JkhOutageService.instance.fetchHouseStatus(address: address);
    _loadHouseSignals(address);
    _fetchRealHousePresence(address);
  }

  Set<String> _supportedSignalIds = {};

  Future<void> _loadSupportedSignals() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'jkh_supported_signals_${_selectedAddress.hashCode}';
      final list = prefs.getStringList(key) ?? [];
      _supportedSignalIds = list.toSet();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _supportSignal(String sigId, Map<String, dynamic> sig) async {
    if (_supportedSignalIds.contains(sigId)) return;
    HapticFeedback.heavyImpact();
    final prefs = await SharedPreferences.getInstance();
    final key = 'jkh_supported_signals_${_selectedAddress.hashCode}';
    _supportedSignalIds.add(sigId);
    await prefs.setStringList(key, _supportedSignalIds.toList());
    final currentLikes = (sig['likes'] as int?) ?? 5;
    sig['likes'] = currentLikes + 1;
    if (mounted) setState(() {});
  }

  Future<void> _loadHouseSignals(String address) async {
    if (mounted) {
      setState(() {
        _loadingSignals = true;
      });
    }
    await _loadSupportedSignals();
    try {
      final allReports = await ReportsRepository.instance.fetchReports(limit: 150);
      
      // Strict address normalization: extract street keywords and specific house number
      final normalizedTarget = address.toLowerCase().replaceAll('ё', 'е');
      final houseNumMatch = RegExp(r'(\d+[\s\-/]?[а-яa-z\d]*)').firstMatch(normalizedTarget);
      final targetHouseNum = houseNumMatch?.group(1)?.replaceAll(RegExp(r'\s+'), '').trim();

      // Clean street name (remove prefixes like ул., проспект, etc.)
      final cleanStreet = normalizedTarget
          .replaceAll(RegExp(r'(проспект|улица|ул\.|проезд|пер\.|переулок|дом|д\.|мкр|микрорайон|квартал)'), '')
          .replaceAll(RegExp(r'(\d+[\s\-/]?[а-яa-z\d]*)'), '')
          .replaceAll(RegExp(r'[,\.\-]'), ' ')
          .trim();
      final streetWords = cleanStreet.split(RegExp(r'\s+')).where((s) => s.length >= 3).toList();

      final seenKeys = <String>{};
      // Семантический дедуп: одинаковые title у одного дома часто приходят
      // из разных источников (TG-ретро-краул + VK + LLM-пересказ) —
      // показываем одну карточку, а не 5 копий (запрос пользователя).
      final seenTitleKeys = <String>{};
      final filtered = <Map<String, dynamic>>[];

      for (final r in allReports) {
        final rId = (r['id'] ?? '').toString();
        final rTitle = (r['title'] ?? '').toString();
        final dedupeKey = rId.isNotEmpty ? rId : '$rTitle|${r['address']}';
        if (seenKeys.contains(dedupeKey)) continue;
        final semanticKey = rTitle.toLowerCase().trim();
        if (semanticKey.length > 10 && seenTitleKeys.contains(semanticKey)) continue;

        final rAddr = (r['address'] ?? r['location_address'] ?? '').toString().toLowerCase().replaceAll('ё', 'е');
        final rDesc = (r['description'] ?? r['title'] ?? '').toString().toLowerCase().replaceAll('ё', 'е');

        bool isExactMatch = false;
        if (rAddr.isNotEmpty && rAddr == normalizedTarget) {
          isExactMatch = true;
        } else if (rAddr.contains(normalizedTarget)) {
          isExactMatch = true;
        } else if (streetWords.isNotEmpty && targetHouseNum != null && targetHouseNum.isNotEmpty) {
          // Check that report address contains the street AND the specific house number
          final hasStreet = streetWords.any((w) => rAddr.contains(w) || rDesc.contains(w));
          final rHouseMatch = RegExp(r'(\d+[\s\-/]?[а-яa-z\d]*)').firstMatch(rAddr);
          final rHouseNum = rHouseMatch?.group(1)?.replaceAll(RegExp(r'\s+'), '').trim();
          
          if (hasStreet && (rHouseNum == targetHouseNum || rAddr.contains(targetHouseNum))) {
            isExactMatch = true;
          }
        }

        if (isExactMatch) {
          seenKeys.add(dedupeKey);
          if (semanticKey.length > 10) seenTitleKeys.add(semanticKey);
          filtered.add(r);
        }
      }

      if (mounted) {
        setState(() {
          _houseSignals = filtered;
          _loadingSignals = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading house signals: $e');
      if (mounted) {
        setState(() {
          _houseSignals = [];
          _loadingSignals = false;
        });
      }
    }
  }

  Future<void> _loadCommunityPosts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'jkh_mutual_aid_posts_${_selectedAddress.hashCode}';
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        final list = jsonDecode(raw) as List;
        _communityPosts = list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      } else {
        _communityPosts = [];
      }
    } catch (_) {
      _communityPosts = [];
    }
    if (mounted) setState(() {});
  }

  Future<void> _saveCommunityPosts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'jkh_mutual_aid_posts_${_selectedAddress.hashCode}';
      await prefs.setString(key, jsonEncode(_communityPosts));
    } catch (_) {}
  }

  int _realTotalResidents = 1;
  int _realOnlineCount = 1;

  Future<void> _fetchRealHousePresence(String address) async {
    if (address.isEmpty) return;
    try {
      final uri = Uri.parse('${MapConfig.backendApiBaseUrl}/jkh/house-presence?address=${Uri.encodeComponent(address)}');
      final res = await http.get(uri).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        if (data is Map<String, dynamic> && data['success'] == true) {
          if (mounted) {
            setState(() {
              _realTotalResidents = (data['total_residents_in_app'] as num?)?.toInt() ?? 1;
              _realOnlineCount = (data['online_now'] as num?)?.toInt() ?? 1;
            });
          }
        }
      }
    } catch (_) {}
  }

  (int, int) _getHouseResidentCounts(String address) {
    if (address.isEmpty) return (0, 0);
    return (_realOnlineCount, _realTotalResidents);
  }

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF00E5FF);
    }
  }

  Map<String, dynamic>? _findUkForAddress(String address) {
    // Единая логика сопоставления дом→УК живёт в UkFallbackData.getUkForAddress
    // (та же семантика, что на бэкенде). Локальный дубликат с фолбэком
    // «первая УК» выдавал ЖТ №1 как управляющую компанию любого дома.
    return UkFallbackData.getUkForAddress(address);
  }

  /// Точное определение дома по GPS / координатам
  Future<void> _detectHouseByGps(BuildContext context, {StateSetter? setModalState}) async {
    HapticFeedback.mediumImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFF1E293B),
        duration: const Duration(milliseconds: 1800),
        content: const Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF)),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                '📍 Определение вашего точного дома по GPS...',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );

    // DeviceLocationService: повторный запрос разрешения + авто-открытие
    // настроек при deniedForever (починено «GPS не включается»)
    Position? pos;
    try {
      final result = await DeviceLocationService.instance.resolve(forceCurrentGPS: true);
      if (result.isSuccess) {
        pos = result.position;
      } else if (result.failure != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFF59E0B),
            content: Text(result.failure!.userMessage),
          ),
        );
        await DeviceLocationService.instance.openFailureSettings(result.failure!);
      }
    } catch (_) {}

    if (pos == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFFEF4444),
            content: Row(
              children: [
                Icon(Icons.location_off_rounded, color: Colors.white),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Не удалось получить координаты GPS. Включите геолокацию на устройстве.',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return;
    }

    String? detectedHouse;

    // 1. Multi-tier Reverse Geocoding: Backend Geocoder + OpenStreetMap
    try {
      final backendUrl = Uri.parse('${MapConfig.backendApiBaseUrl}/api/geo/reverse?lat=${pos.latitude}&lon=${pos.longitude}');
      final res = await http.get(backendUrl, headers: {'Accept': 'application/json'}).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final data = json.decode(utf8.decode(res.bodyBytes));
        final addr = data['address'] as String?;
        if (addr != null && addr.isNotEmpty && !addr.startsWith('GPS:')) {
          // Match against registry
          final matched = NizhnevartovskHousesData.allHouses.firstWhere(
            (h) => (h['address'] as String).toLowerCase() == addr.toLowerCase() ||
                   (h['address'] as String).toLowerCase().contains(addr.toLowerCase()),
            orElse: () => <String, dynamic>{},
          );
          if (matched.isNotEmpty) {
            detectedHouse = matched['address'] as String;
          } else {
            detectedHouse = addr;
          }
        }
      }
    } catch (_) {}

    if (detectedHouse == null) {
      try {
        final osmUrl = Uri.parse('https://nominatim.openstreetmap.org/reverse?lat=${pos.latitude}&lon=${pos.longitude}&format=json&accept-language=ru');
        final res = await http.get(osmUrl, headers: {'User-Agent': 'CityPulseNV/2.0'}).timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) {
          final data = json.decode(utf8.decode(res.bodyBytes));
          final addressObj = data['address'] as Map<String, dynamic>?;
          if (addressObj != null) {
            final road = (addressObj['road'] ?? addressObj['street'] ?? addressObj['pedestrian'] ?? addressObj['suburb'] ?? '').toString();
            final houseNumber = (addressObj['house_number'] ?? addressObj['building'] ?? '').toString();
            if (road.isNotEmpty && houseNumber.isNotEmpty) {
              final candidate = '$road, $houseNumber';
              final matched = NizhnevartovskHousesData.allHouses.firstWhere(
                (h) => (h['address'] as String).toLowerCase().contains(road.toLowerCase()) &&
                       (h['address'] as String).toLowerCase().contains(houseNumber.toLowerCase()),
                orElse: () => <String, dynamic>{},
              );
              detectedHouse = matched.isNotEmpty ? (matched['address'] as String) : candidate;
            } else if (road.isNotEmpty) {
              final matched = NizhnevartovskHousesData.allHouses.firstWhere(
                (h) => (h['address'] as String).toLowerCase().contains(road.toLowerCase()),
                orElse: () => <String, dynamic>{},
              );
              if (matched.isNotEmpty) detectedHouse = matched['address'] as String;
            }
          }
        }
      } catch (_) {}
    }

    // 2. Fallback to Nearest Registered House by Haversine
    if (detectedHouse == null) {
      final nearest = NizhnevartovskHousesData.findNearestHouse(pos.latitude, pos.longitude);
      if (nearest != null) {
        detectedHouse = nearest['address'] as String;
      }
    }

    if (detectedHouse == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFFF59E0B),
            content: Row(
              children: [
                Icon(Icons.home_work_outlined, color: Colors.white),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Поблизости не найден дом из реестра. Выберите адрес из списка.',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        _selectedAddress = detectedHouse!;
      });
      if (setModalState != null) {
        setModalState(() {
          _selectedAddress = detectedHouse!;
        });
      }
      _saveAddress(detectedHouse);
      _fetchForAddress(detectedHouse);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '✅ Дом определен: $detectedHouse',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _showHouseSelectDialog(BuildContext context) {
    final searchCtrl = TextEditingController();
    List<String> filteredAddresses = NizhnevartovskHousesData.searchHouses('');

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A).withOpacity(0.96) : const Color(0xFFF8FAFC).withOpacity(0.98);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? Colors.white54 : const Color(0xFF64748B);
    final inputFill = isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
            padding: EdgeInsets.only(
              top: 20, left: 20, right: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: PulseColors.primary.withOpacity(0.4), width: 1.5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: subtextColor, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.home_work_rounded, color: PulseColors.primary, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Выбор дома и адреса ЖКХ (Нижневартовск)',
                        style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // GPS Определение дома кнопка
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF).withOpacity(0.18),
                      foregroundColor: const Color(0xFF00E5FF),
                      side: const BorderSide(color: Color(0xFF00E5FF), width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.my_location_rounded, size: 18),
                    label: const Text(
                      'ОПРЕДЕЛИТЬ МОЙ ДОМ ПО GPS 📍',
                      style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5),
                    ),
                    onPressed: () async {
                      await _detectHouseByGps(context, setModalState: setModalState);
                      Navigator.pop(ctx);
                    },
                  ),
                ),
                const SizedBox(height: 12),

                TextField(
                  controller: searchCtrl,
                  style: TextStyle(color: textColor, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Поиск по улице или номеру дома (напр. Ленина, 15)...',
                    hintStyle: TextStyle(color: subtextColor, fontSize: 12.5),
                    prefixIcon: Icon(Icons.search_rounded, color: PulseColors.primary),
                    filled: true,
                    fillColor: inputFill,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                  onChanged: (query) {
                    setModalState(() {
                      filteredAddresses = NizhnevartovskHousesData.searchHouses(query, limit: 120);
                    });
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'НАЙДЕНО ДОМОВ И СТРОЕНИЙ: ${filteredAddresses.length}',
                  style: TextStyle(color: subtextColor, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: filteredAddresses.length,
                    separatorBuilder: (_, __) => Divider(color: subtextColor.withOpacity(0.12), height: 1),
                    itemBuilder: (context, i) {
                      final addr = filteredAddresses[i];
                      final isSel = _selectedAddress == addr;
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                        leading: Icon(
                          Icons.location_on_rounded,
                          color: isSel ? const Color(0xFF00E5FF) : subtextColor,
                          size: 20,
                        ),
                        title: Text(
                          addr,
                          style: TextStyle(
                            color: isSel ? const Color(0xFF00E5FF) : textColor,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                            fontSize: 13.5,
                          ),
                        ),
                        trailing: isSel
                            ? const Icon(Icons.check_circle_rounded, color: Color(0xFF00E5FF), size: 20)
                            : Icon(Icons.chevron_right_rounded, color: subtextColor, size: 18),
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          setState(() {
                            _selectedAddress = addr;
                          });
                          _saveAddress(addr);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Apple-Style Full Details Sheet with Dedicated Tabs
  void _showDetailSheet(BuildContext context, JkhHouseStatus houseStatus) {
    int currentTab = 0; // 0 = ЖКХ и Отключения, 1 = Взаимопомощь
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    String selectedPreset = '🐕 Выгулять питомца';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final mainColor = _parseColor(houseStatus.colorHex);
        final sheetBg = isDark ? const Color(0xFF0F172A).withOpacity(0.97) : const Color(0xFFF8FAFC).withOpacity(0.98);
        final titleTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
        final tabBg = isDark ? Colors.white.withOpacity(0.08) : const Color(0xFFE2E8F0);
        final tabBorder = isDark ? Colors.white12 : const Color(0xFFCBD5E1);
        final unselectedTabText = isDark ? Colors.white70 : const Color(0xFF475569);
        final dragHandle = isDark ? Colors.white24 : const Color(0xFF94A3B8);

        return StatefulBuilder(
          builder: (context, setSheetState) => BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                border: Border.all(color: isDark ? Colors.white.withOpacity(0.12) : Colors.black12, width: 1.2),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: dragHandle,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Header with Address & GPS button
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: mainColor.withOpacity(0.2),
                          border: Border.all(color: mainColor, width: 1.5),
                        ),
                        child: Icon(
                          houseStatus.status == 'emergency'
                              ? Icons.warning_amber_rounded
                              : houseStatus.status == 'planned'
                                  ? Icons.info_outline_rounded
                                  : Icons.check_circle_outline_rounded,
                          color: mainColor,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedAddress,
                              style: TextStyle(
                                color: isDark ? const Color(0xFF00E5FF) : const Color(0xFF0284C7),
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              houseStatus.statusTitle,
                              style: TextStyle(
                                color: titleTextColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Builder(builder: (ctx) {
                              final counts = _getHouseResidentCounts(_selectedAddress);
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF10B981).withOpacity(0.35)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFF10B981),
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      '${counts.$1} онлайн · Всего ${counts.$2} жильцов в сети',
                                      style: TextStyle(
                                        color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: _isSubscribedToHouse ? 'Уведомления по дому включены' : 'Подписаться на уведомления по дому',
                        icon: Icon(
                          _isSubscribedToHouse ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
                          color: _isSubscribedToHouse ? const Color(0xFFFACC15) : (isDark ? Colors.white60 : Colors.black45),
                        ),
                        onPressed: () {
                          _showHouseNotificationSubscriptionModal(context);
                        },
                      ),
                      IconButton(
                        tooltip: 'Определить дом по GPS',
                        icon: Icon(Icons.my_location_rounded, color: isDark ? const Color(0xFF00E5FF) : const Color(0xFF0284C7)),
                        onPressed: () async {
                          await _detectHouseByGps(context);
                          setSheetState(() {});
                        },
                      ),
                      IconButton(
                        tooltip: 'Выбрать дом из списка',
                        icon: Icon(Icons.edit_location_alt_rounded, color: isDark ? Colors.cyanAccent : const Color(0xFF0369A1)),
                        onPressed: () {
                          Navigator.pop(context);
                          _showHouseSelectDialog(context);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Segmented Tabs: [ 🏢 ЖКХ | 🚨 Сигналы дома | 🤝 Соседи ]
                  Container(
                    decoration: BoxDecoration(
                      color: tabBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: tabBorder),
                    ),
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      children: [
                        // Tab 0: ЖКХ и Отключения
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setSheetState(() => currentTab = 0),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: currentTab == 0
                                    ? (isDark ? const Color(0xFF00E5FF) : Colors.white)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: currentTab == 0 && !isDark
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.06),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  '🏢 ЖКХ',
                                  style: TextStyle(
                                    color: currentTab == 0
                                        ? (isDark ? Colors.black : const Color(0xFF0284C7))
                                        : unselectedTabText,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Tab 1: Сигналы дома
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setSheetState(() => currentTab = 1),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: currentTab == 1
                                    ? (isDark ? const Color(0xFF00E5FF) : Colors.white)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: currentTab == 1 && !isDark
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.06),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  '🚨 СИГНАЛЫ (${_houseSignals.length})',
                                  style: TextStyle(
                                    color: currentTab == 1
                                        ? (isDark ? Colors.black : const Color(0xFF0284C7))
                                        : unselectedTabText,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Tab 2: Взаимопомощь соседей (возвращён по запросу)
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setSheetState(() => currentTab = 2),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: currentTab == 2
                                    ? (isDark ? const Color(0xFF00E5FF) : Colors.white)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: currentTab == 2 && !isDark
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.06),
                                          blurRadius: 4,
                                          offset: const Offset(0, 1),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Center(
                                child: Text(
                                  '🤝 СОСЕДИ',
                                  style: TextStyle(
                                    color: currentTab == 2
                                        ? (isDark ? Colors.black : const Color(0xFF0284C7))
                                        : unselectedTabText,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  Expanded(
                    child: currentTab == 0
                        ? _buildJkhTabContent(context, houseStatus, mainColor)
                        : currentTab == 1
                            ? _buildHouseSignalsTabContent(context, setSheetState, isDark, mainColor)
                            : _buildNeighborsCommunityTab(context),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Вкладка со всеми сигналами и жалобами по выбранному дому
  Widget _buildHouseSignalsTabContent(
    BuildContext context,
    StateSetter setSheetState,
    bool isDark,
    Color mainColor,
  ) {
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? Colors.white70 : const Color(0xFF475569);
    final cardBg = isDark ? Colors.white.withOpacity(0.06) : Colors.white;
    final cardBorder = isDark ? Colors.white.withOpacity(0.12) : const Color(0xFFE2E8F0);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Кнопка создания нового сигнала для данного адреса
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF00E5FF).withOpacity(0.18),
                  const Color(0xFF007AFF).withOpacity(0.12),
                ],
              ),
              border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.4)),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  final res = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ComplaintFormScreen(
                        initialCenter: null,
                      ),
                    ),
                  );
                  if (res == true) {
                    _loadHouseSignals(_selectedAddress);
                    setSheetState(() {});
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF00E5FF).withOpacity(0.25),
                          border: Border.all(color: const Color(0xFF00E5FF)),
                        ),
                        child: const Icon(Icons.add_alert_rounded, color: Color(0xFF00E5FF), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Сообщить о проблеме в доме',
                              style: TextStyle(
                                color: primaryTextColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Сигнал привяжется к адресу: $_selectedAddress',
                              style: TextStyle(
                                color: secondaryTextColor,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF00E5FF)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 2. Статистика и заголовок
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'АКТИВНЫЕ СИГНАЛЫ ПО ДОМУ (${_houseSignals.length}):',
                style: TextStyle(
                  color: secondaryTextColor,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              if (_loadingSignals)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // 3. Список сигналов
          if (_houseSignals.isEmpty && !_loadingSignals)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: cardBorder),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF10B981).withOpacity(0.15),
                      border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
                    ),
                    child: const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 36),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'По данному дому активных сигналов нет',
                    style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.bold, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Все городские и внутридомовые системы функционируют в штатном режиме.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: secondaryTextColor, fontSize: 11.5, height: 1.3),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _houseSignals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (ctx, idx) {
                final sig = _houseSignals[idx];
                final title = sig['title']?.toString() ?? 'Сигнал';
                final desc = sig['description']?.toString() ?? '';
                final status = sig['status']?.toString() ?? 'in_progress';
                final statusText = sig['status_text']?.toString() ?? (status == 'resolved' ? 'Решено' : 'В работе');
                final author = sig['author']?.toString() ?? 'Житель';
                final time = sig['time']?.toString() ?? 'Сегодня';
                final likes = sig['likes'] as int? ?? 5;
                final hasPhoto = sig['has_photo'] == true || sig['image_url'] != null;
                final imgUrl = sig['image_url']?.toString();

                final isResolved = status == 'resolved';
                final statusColor = isResolved ? const Color(0xFF10B981) : (status == 'accepted' ? const Color(0xFF38BDF8) : const Color(0xFFFFB800));

                return Container(
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: cardBorder),
                    boxShadow: isDark
                        ? null
                        : [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        showSwipeableReportDetail(
                          context: context,
                          reports: _houseSignals,
                          initialIndex: idx,
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Status & AI Verification badge
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: statusColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: statusColor.withOpacity(0.4)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        statusText,
                                        style: TextStyle(
                                          color: statusColor,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF8B5CF6).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.4)),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.auto_awesome_rounded, size: 10, color: Color(0xFFA78BFA)),
                                      SizedBox(width: 3),
                                      Text(
                                        'ИИ-контроль',
                                        style: TextStyle(
                                          color: Color(0xFFA78BFA),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  time,
                                  style: TextStyle(color: secondaryTextColor, fontSize: 10),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_forward_ios_rounded, size: 11, color: Colors.white38),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Title
                            Text(
                              title,
                              style: TextStyle(
                                color: primaryTextColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),

                            // Description
                            Text(
                              desc,
                              style: TextStyle(
                                color: secondaryTextColor,
                                fontSize: 11.5,
                                height: 1.3,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),

                            // Photo thumbnail preview (if present)
                            if (hasPhoto && imgUrl != null)
                              Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                height: 44,
                                width: 44,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: isDark ? Colors.white24 : Colors.black12),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.asset(imgUrl, fit: BoxFit.cover),
                                ),
                              ),

                            // Footer: Author & Support Button
                            Row(
                              children: [
                                Icon(Icons.person_outline_rounded, size: 13, color: secondaryTextColor),
                                const SizedBox(width: 4),
                                Text(
                                  author,
                                  style: TextStyle(color: secondaryTextColor, fontSize: 10),
                                ),
                                const Spacer(),
                                // Like/Upvote Button (1 vote per house address)
                                () {
                                  final sigId = sig['id']?.toString() ?? '${sig['title']}_${sig['address']}';
                                  final isSupported = _supportedSignalIds.contains(sigId);
                                  return GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () async {
                                      if (isSupported) return;
                                      await _supportSignal(sigId, sig);
                                      setSheetState(() {});
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: isSupported
                                            ? const Color(0xFF10B981).withOpacity(0.18)
                                            : const Color(0xFF00E5FF).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isSupported
                                              ? const Color(0xFF10B981).withOpacity(0.5)
                                              : const Color(0xFF00E5FF).withOpacity(0.3),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            isSupported ? Icons.check_circle_rounded : Icons.thumb_up_alt_rounded,
                                            size: 13,
                                            color: isSupported ? const Color(0xFF10B981) : const Color(0xFF00E5FF),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            isSupported ? 'Поддержано ($likes)' : 'Поддержать ($likes)',
                                            style: TextStyle(
                                              color: isSupported ? const Color(0xFF10B981) : const Color(0xFF00E5FF),
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }(),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildJkhTabContent(BuildContext context, JkhHouseStatus houseStatus, Color mainColor) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    final primaryTextColor = isLightTheme ? const Color(0xFF0F172A) : Colors.white;
    final secondaryTextColor = isLightTheme ? const Color(0xFF475569) : Colors.white70;
    final mutedTextColor = isLightTheme ? const Color(0xFF64748B) : Colors.white54;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Карточка-паспорт дома в стиле Bento Grid («Здоровье дома» 0–100%) ───
          HousePassportBentoGrid(
            address: _selectedAddress,
            isDark: !isLightTheme,
          ),
          const SizedBox(height: 14),

          // ─── Реестр УК города: единый экран (карта, поиск, рейтинги) ───
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _showAllUkCompaniesSheet(context),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withOpacity(isLightTheme ? 0.12 : 0.18),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.45)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF8B5CF6)),
                    ),
                    child: const Icon(Icons.apartment_rounded, color: Color(0xFF8B5CF6), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'УПРАВЛЯЮЩИЕ КОМПАНИИ ГОРОДА',
                          style: TextStyle(
                            color: primaryTextColor,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Реестр 42 УК: карта офисов, аварийные службы, рейтинги',
                          style: TextStyle(color: secondaryTextColor, fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF8B5CF6), size: 14),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // ─── Быстрое смарт-действие: Сканер счетчиков с ИИ-распознаванием ───
          InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () {
              HapticFeedback.mediumImpact();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SmartMeterScannerScreen(
                    address: _selectedAddress,
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF10B981).withOpacity(isLightTheme ? 0.18 : 0.25),
                    const Color(0xFF059669).withOpacity(isLightTheme ? 0.09 : 0.16),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.45)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF10B981)),
                    ),
                    child: const Icon(Icons.camera_enhance_rounded, color: Color(0xFF10B981), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'СКАНИРОВАТЬ СЧЕТЧИК',
                              style: TextStyle(
                                color: primaryTextColor,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text(
                                'ИИ OCR',
                                style: TextStyle(
                                  color: Color(0xFF10B981),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Показания ХВС, ГВС и 220В через камеру в 1 клик',
                          style: TextStyle(color: secondaryTextColor, fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF10B981), size: 14),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // 1. ПЛАНОВЫЕ И ТЕКУЩИЕ ОТКЛЮЧЕНИЯ
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ПЛАНОВЫЕ И АВАРИЙНЫЕ ОТКЛЮЧЕНИЯ:',
                style: TextStyle(
                  color: mutedTextColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.1,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (houseStatus.outages.isNotEmpty ? const Color(0xFFF59E0B) : const Color(0xFF10B981)).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  houseStatus.outages.isNotEmpty ? 'Ежедневный мониторинг' : 'Сегодня без отключений',
                  style: TextStyle(
                    color: houseStatus.outages.isNotEmpty ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (houseStatus.outages.isNotEmpty) ...[
            ...houseStatus.outages.map((item) {
              final itemColor = _parseColor(item.colorHex);
              final isPlanned = item.incidentType.contains('plan') || item.title.toLowerCase().contains('план');
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isLightTheme ? Colors.black.withOpacity(0.04) : Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: itemColor.withOpacity(isLightTheme ? 0.6 : 0.4), width: 1.2),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: itemColor.withOpacity(0.16),
                          ),
                          child: Icon(
                            item.incidentType == 'water'
                                ? Icons.water_drop_rounded
                                : item.incidentType == 'electricity'
                                    ? Icons.bolt_rounded
                                    : item.incidentType == 'heating'
                                        ? Icons.thermostat_rounded
                                        : Icons.build_rounded,
                            color: itemColor,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              if (item.displayTimer.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    '⏱ Ожидаемое возобновление: ${item.displayTimer}',
                                    style: TextStyle(color: itemColor, fontSize: 11, fontWeight: FontWeight.w700),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: itemColor.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            isPlanned ? 'ПЛАН' : 'РЕМОНТ',
                            style: TextStyle(color: itemColor, fontSize: 9.5, fontWeight: FontWeight.w900),
                          ),
                        ),
                      ],
                    ),
                    if (item.description != null && item.description!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.description!,
                        style: TextStyle(color: secondaryTextColor, fontSize: 11.5, height: 1.3),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF10B981).withOpacity(0.2),
                    ),
                    child: const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Плановых отключений на сегодня нет',
                          style: TextStyle(color: primaryTextColor, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Все коммунальные ресурсы (ГВС, ХВС, отопление, свет, газ) подаются в штатном режиме.',
                          style: TextStyle(color: secondaryTextColor, fontSize: 10.5, height: 1.25),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 14),

          // 2. ГРАФИК УБОРКИ ДВОРА
          Text(
            _isWinterSeason ? '🚜 ГРАФИК СНЕГОУБОРКИ И ГРЕЙДЕРОВ:' : '🧹 ЛЕТНЯЯ МЕХАНИЗИРОВАННАЯ УБОРКА:',
            style: TextStyle(color: mutedTextColor, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _isWinterSeason ? const Color(0xFFF59E0B).withOpacity(0.12) : const Color(0xFF06B6D4).withOpacity(0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isWinterSeason ? const Color(0xFFF59E0B).withOpacity(0.4) : const Color(0xFF06B6D4).withOpacity(0.4),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _isWinterSeason ? Icons.local_shipping_rounded : Icons.water_drop_rounded,
                      color: _isWinterSeason ? const Color(0xFFF59E0B) : const Color(0xFF06B6D4),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _isWinterSeason ? 'Механизированная уборка снега' : 'Вакуумная подметально-уборочная машина',
                        style: TextStyle(color: primaryTextColor, fontWeight: FontWeight.bold, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _isWinterSeason
                      ? '📅 Запланировано: завтра, с 20:00 до 04:00 (очистка двора и парковки)'
                      : '📅 График: ежедневная влажная уборка дворового проезда с 06:00 до 08:00',
                  style: TextStyle(color: secondaryTextColor, fontSize: 11),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),
        ],
      ),
    );
  }

  /// Вкладка «Соседи»: взаимопомощь и соседский чат (Tab 2).
  /// Оборачивает готовый контент _buildMutualAidTabContent с контроллерами.
  Widget _buildNeighborsCommunityTab(BuildContext context) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final contactCtrl = TextEditingController();
    String selectedPreset = '🐕 Выгулять питомца';

    return StatefulBuilder(
      builder: (context, setTabState) => _buildMutualAidTabContent(
        context,
        titleCtrl,
        descCtrl,
        contactCtrl,
        selectedPreset,
        (p) => setTabState(() => selectedPreset = p),
        () {},
      ),
    );
  }

  Widget _buildMutualAidTabContent(
    BuildContext context,
    TextEditingController titleCtrl,
    TextEditingController descCtrl,
    TextEditingController contactCtrl,
    String selectedPreset,
    Function(String) onSelectPreset,
    VoidCallback onSubmit,
  ) {
    return ListenableBuilder(
      listenable: NeighborCommunityWebSocketService.instance,
      builder: (context, _) {
        final isLightTheme = Theme.of(context).brightness == Brightness.light;
        final ws = NeighborCommunityWebSocketService.instance;
        final allPosts = <Map<String, dynamic>>[];

        // Add live WebSocket posts first
        for (final p in ws.livePosts) {
          final colorHex = p['badge_color']?.toString() ?? '#00E5FF';
          allPosts.add({
            'id': p['id'],
            'author': p['author'] ?? 'Сосед',
            'type': p['type'] ?? 'general',
            'title': p['title'] ?? '',
            'description': p['description'] ?? '',
            'phone': p['phone'] ?? '',
            'time': p['time'] ?? 'только что',
            'responses_count': p['responses_count'] ?? 0,
            'color': _parseColor(colorHex),
          });
        }

        // Add local posts if not duplicate
        for (final p in _communityPosts) {
          if (!allPosts.any((x) => x['id'] == p['id'])) {
            allPosts.add(p);
          }
        }

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ЖИВОЙ СТАТУС ОНЛАЙН ЧЕРЕЗ РЕАЛЬНУЮ БАЗУ ЖКХ И WEBSOCKET
              () {
                final effectiveOnline = _realOnlineCount > 0 ? _realOnlineCount : (ws.isConnected ? ws.onlineCount : 1);
                final totalResidents = _realTotalResidents > 0 ? _realTotalResidents : 1;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.35)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withOpacity(0.6),
                              blurRadius: 6,
                              spreadRadius: 1,
                            )
                          ],
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          '🟢 На связи: $effectiveOnline онлайн • Всего в доме: $totalResidents',
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }(),

              // МИНИ-ФОРМА СОЗДАНИЯ ПРОСЬБЫ О ПОМОЩИ
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isLightTheme ? Colors.black.withOpacity(0.03) : Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: (isLightTheme ? const Color(0xFF0284C7) : const Color(0xFF00E5FF)).withOpacity(0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.add_circle_outline_rounded, color: isLightTheme ? const Color(0xFF0284C7) : const Color(0xFF00E5FF), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'СОЗДАТЬ ПРОСЬБУ О ПОМОЩИ СОСЕДЯМ',
                          style: TextStyle(
                            color: isLightTheme ? const Color(0xFF0F172A) : Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        '🐕 Выгулять питомца',
                        '🔧 Одолжить инструмент',
                        '🚗 Подвезти',
                        '🪴 Полить цветы',
                        '📦 Бытовая помощь',
                      ].map((p) {
                        final isSel = selectedPreset == p;
                        return ActionChip(
                          backgroundColor: isSel
                              ? (isLightTheme ? const Color(0xFFE0F2FE) : const Color(0xFF00E5FF).withOpacity(0.3))
                              : (isLightTheme ? const Color(0xFFF1F5F9) : Colors.white10),
                          side: BorderSide(
                            color: isSel
                                ? (isLightTheme ? const Color(0xFF0284C7) : const Color(0xFF00E5FF))
                                : (isLightTheme ? const Color(0xFFCBD5E1) : Colors.transparent),
                          ),
                          label: Text(
                            p,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                              color: isSel
                                  ? (isLightTheme ? const Color(0xFF0284C7) : Colors.cyanAccent)
                                  : (isLightTheme ? const Color(0xFF334155) : Colors.white70),
                            ),
                          ),
                          onPressed: () {
                            onSelectPreset(p);
                            titleCtrl.text = p;
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descCtrl,
                      maxLines: 2,
                      style: TextStyle(color: isLightTheme ? const Color(0xFF0F172A) : Colors.white, fontSize: 12.5),
                      decoration: InputDecoration(
                        hintText: 'Опишите ситуацию (чем помочь, время, подробности)...',
                        hintStyle: TextStyle(color: isLightTheme ? const Color(0xFF94A3B8) : Colors.white38, fontSize: 11.5),
                        filled: true,
                        fillColor: isLightTheme ? Colors.white : Colors.white.withOpacity(0.06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: isLightTheme ? const BorderSide(color: Color(0xFFCBD5E1)) : BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: isLightTheme ? const BorderSide(color: Color(0xFFE2E8F0)) : BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: contactCtrl,
                      style: TextStyle(color: isLightTheme ? const Color(0xFF0F172A) : Colors.white, fontSize: 12.5),
                      decoration: InputDecoration(
                        hintText: 'Контакты для связи (номер телефона или номер квартиры)...',
                        hintStyle: TextStyle(color: isLightTheme ? const Color(0xFF94A3B8) : Colors.white38, fontSize: 11.5),
                        prefixIcon: Icon(Icons.contact_phone_rounded, color: isLightTheme ? const Color(0xFF0284C7) : const Color(0xFF00E5FF), size: 16),
                        filled: true,
                        fillColor: isLightTheme ? Colors.white : Colors.white.withOpacity(0.06),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: isLightTheme ? const BorderSide(color: Color(0xFFCBD5E1)) : BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: isLightTheme ? const BorderSide(color: Color(0xFFE2E8F0)) : BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isLightTheme ? const Color(0xFF0284C7) : const Color(0xFF00E5FF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.send_rounded, size: 15),
                        label: const Text('ОПУБЛИКОВАТЬ В ДОМОВОМ ЧАТЕ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
                        onPressed: () {
                          ws.sendPost(
                            author: contactCtrl.text.isNotEmpty ? 'Сосед (${contactCtrl.text.trim()})' : 'Сосед (кв. 14)',
                            title: titleCtrl.text.isNotEmpty ? titleCtrl.text.trim() : selectedPreset,
                            description: descCtrl.text.trim(),
                            type: selectedPreset,
                          );
                          onSubmit();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              Text(
                'АКТИВНЫЕ ПРОСЬБЫ ЖИТЕЛЕЙ ДОМА:',
                style: TextStyle(
                  color: isLightTheme ? const Color(0xFF64748B) : Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),

              if (allPosts.isEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                  decoration: BoxDecoration(
                    color: isLightTheme ? Colors.black.withOpacity(0.02) : Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: isLightTheme ? Colors.black12 : Colors.white10),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.volunteer_activism_outlined, size: 36, color: isLightTheme ? const Color(0xFF0284C7) : const Color(0xFF00E5FF)),
                      const SizedBox(height: 8),
                      Text(
                        'Нет активных просьб о взаимопомощи',
                        style: TextStyle(
                          color: isLightTheme ? const Color(0xFF0F172A) : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Вы можете создать просьбу выше, и соседи вашего дома увидят её в домовом чате.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: isLightTheme ? const Color(0xFF64748B) : Colors.white60,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

              // Список постов жителей
              ...allPosts.map((post) {
                final color = post['color'] as Color? ?? (isLightTheme ? const Color(0xFF0284C7) : const Color(0xFF00E5FF));
                final phone = post['phone']?.toString() ?? '';
                final responses = post['responses_count'] as int? ?? 0;
                final responders = post['responders'] as List<dynamic>? ?? [];
                final postId = post['id']?.toString() ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isLightTheme ? Colors.black.withOpacity(0.03) : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: color.withOpacity(isLightTheme ? 0.5 : 0.35), width: 1.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              post['author'] as String,
                              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ),
                          if (responses > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '🤝 $responses отклик.',
                                style: const TextStyle(color: Color(0xFF10B981), fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                          const Spacer(),
                          Text(
                            post['time'] as String,
                            style: TextStyle(color: isLightTheme ? const Color(0xFF94A3B8) : Colors.white38, fontSize: 10),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        post['title'] as String,
                        style: TextStyle(
                          color: isLightTheme ? const Color(0xFF0F172A) : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        post['description'] as String,
                        style: TextStyle(
                          color: isLightTheme ? const Color(0xFF475569) : Colors.white70,
                          fontSize: 11.5,
                          height: 1.3,
                        ),
                      ),

                      // Откликнувшиеся соседи с кнопками связи
                      if (responders.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isLightTheme ? Colors.black.withOpacity(0.02) : Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isLightTheme ? Colors.black12 : Colors.white10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.people_outline_rounded, color: Color(0xFF10B981), size: 14),
                                  SizedBox(width: 6),
                                  Text(
                                    'ОТКЛИКНУЛИСЬ НА ПОМОЩЬ:',
                                    style: TextStyle(color: Color(0xFF10B981), fontSize: 9.5, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              for (final r in responders) ...[
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 10,
                                        backgroundColor: (isLightTheme ? const Color(0xFF0284C7) : const Color(0xFF00E5FF)).withOpacity(0.2),
                                        child: Text(
                                          (r['name']?.toString() ?? 'С')[0],
                                          style: TextStyle(
                                            color: isLightTheme ? const Color(0xFF0284C7) : const Color(0xFF00E5FF),
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '${r['name']} (${r['flat']})',
                                          style: TextStyle(
                                            color: isLightTheme ? const Color(0xFF0F172A) : Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      // Связь через Telegram
                                      if (r['tg'] != null)
                                        InkWell(
                                          onTap: () => _openUrl('https://t.me/${r['tg']}'),
                                          borderRadius: BorderRadius.circular(6),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                            margin: const EdgeInsets.only(right: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF229ED9).withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.send_rounded, color: Color(0xFF229ED9), size: 10),
                                                SizedBox(width: 3),
                                                Text('TG', style: TextStyle(color: Color(0xFF229ED9), fontSize: 9, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      // Связь через VK
                                      if (r['vk'] != null)
                                        InkWell(
                                          onTap: () => _openUrl('https://vk.com/${r['vk']}'),
                                          borderRadius: BorderRadius.circular(6),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                            margin: const EdgeInsets.only(right: 4),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF0077FF).withOpacity(0.2),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF0077FF), size: 10),
                                                SizedBox(width: 3),
                                                Text('VK', style: TextStyle(color: Color(0xFF0077FF), fontSize: 9, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      // MAX Messenger
                                      InkWell(
                                        onTap: () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              backgroundColor: isLightTheme ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                                              content: Text('💬 Открыт защищенный домовой чат MAX с ${r['name']}'),
                                            ),
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(6),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF8B5CF6).withOpacity(0.2),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.forum_rounded, color: Color(0xFF8B5CF6), size: 10),
                                              SizedBox(width: 3),
                                              Text('MAX', style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 9, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (phone.isNotEmpty) ...[
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  elevation: 0,
                                ),
                                icon: const Icon(Icons.phone_in_talk_rounded, size: 14),
                                label: Text('Позвонить ($phone)', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                                onPressed: () {
                                  HapticFeedback.heavyImpact();
                                  _callDispatcher(phone);
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: color,
                                side: BorderSide(color: color),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                              ),
                              icon: const Icon(Icons.handshake_rounded, size: 14),
                              label: const Text('Откликнуться', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                if (postId.isNotEmpty) {
                                  ws.respondToPost(postId);
                                }
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: isLightTheme ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
                                    content: Text('🤝 Вы откликнулись на просьбу: ${post['author']}!'),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 12),

              // ПОЛЕЗНЫЕ КОНТАКТЫ И ДЕЖУРНЫЕ СЛУЖБЫ ДОМА (Заполненный нижний блок)
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContactRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    final isLightTheme = Theme.of(context).brightness == Brightness.light;
    final accentColor = isLightTheme ? const Color(0xFF0284C7) : const Color(0xFF00E5FF);

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: accentColor, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: isLightTheme ? const Color(0xFF0F172A) : Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: isLightTheme ? const Color(0xFF64748B) : Colors.white60,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          style: TextButton.styleFrom(
            backgroundColor: accentColor.withOpacity(0.15),
            foregroundColor: accentColor,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: onAction,
          child: Text(actionLabel, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  void _openUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await url_launcher.canLaunchUrl(uri)) {
        await url_launcher.launchUrl(uri, mode: url_launcher.LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  void _showHouseNotificationSubscriptionModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setMState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final sheetBg = isDark ? const Color(0xFF0F172A).withOpacity(0.96) : const Color(0xFFF8FAFC).withOpacity(0.98);
          final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
          final subtitleColor = isDark ? Colors.white60 : const Color(0xFF64748B);

          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: sheetBg,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: isDark ? Colors.white.withOpacity(0.15) : Colors.black12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Icon(Icons.notifications_active_rounded, color: Color(0xFFFACC15), size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Уведомления по дому: $_selectedAddress',
                        style: TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SwitchListTile(
                  title: Text('Все уведомления по дому', style: TextStyle(color: titleColor, fontSize: 13, fontWeight: FontWeight.bold)),
                  subtitle: Text('Отключения воды, тепла, уборка снега, аварии УК', style: TextStyle(color: subtitleColor, fontSize: 11)),
                  value: _isSubscribedToHouse,
                  activeColor: isDark ? const Color(0xFF00E5FF) : const Color(0xFF0284C7),
                  onChanged: (val) async {
                    await _toggleSubscription();
                    setMState(() {});
                    if (mounted) setState(() {});
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? const Color(0xFF00E5FF) : const Color(0xFF0284C7),
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('ГОТОВО', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _callDispatcher(String phone) async {
    try {
      final uri = Uri.parse('tel:$phone');
      if (await url_launcher.canLaunchUrl(uri)) {
        await url_launcher.launchUrl(uri);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _auraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0F172A).withOpacity(0.88) : const Color(0xFFF8FAFC).withOpacity(0.95);
    final descColor = isDark ? Colors.white70 : Colors.black87;
    final iconColor = isDark ? Colors.white38 : Colors.black38;

    return ListenableBuilder(
      listenable: JkhOutageService.instance,
      builder: (context, _) {
        final houseStatus = JkhOutageService.instance.currentStatus;
        final mainColor = _parseColor(houseStatus.colorHex);

        return AnimatedBuilder(
          animation: _auraController,
          builder: (context, child) {
            final auraPulse = _auraController.value;
            final glowRadius = 8.0 + (auraPulse * 8.0);

            return AppTouchBounce(
              onTap: () {
                HapticFeedback.lightImpact();
                _showDetailSheet(context, houseStatus);
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: mainColor.withOpacity(0.30 + (auraPulse * 0.15)),
                      blurRadius: glowRadius,
                      spreadRadius: 1,
                    )
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: mainColor.withOpacity(0.6), width: 1.4),
                      ),
                      child: Row(
                        children: [
                          // Статус Аура (🟢 / 🟡 / 🔴)
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: mainColor,
                              boxShadow: [
                                BoxShadow(
                                  color: mainColor.withOpacity(0.8),
                                  blurRadius: 8 + (auraPulse * 5),
                                  spreadRadius: 1,
                                )
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.home_rounded, color: isDark ? const Color(0xFF00E5FF) : const Color(0xFF0284C7), size: 12),
                                    const SizedBox(width: 4),
                                    Text(
                                      _selectedAddress,
                                      style: TextStyle(
                                        color: isDark ? const Color(0xFF00E5FF) : const Color(0xFF0284C7),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      houseStatus.statusTitle,
                                      style: TextStyle(
                                        color: mainColor,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Builder(builder: (ctx) {
                                  final counts = _getHouseResidentCounts(_selectedAddress);
                                  return Text(
                                    '🟢 ${counts.$1} онлайн • 👥 ${counts.$2} в доме · ${houseStatus.statusDescription}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: descColor,
                                      fontSize: 10.5,
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.chevron_right_rounded, color: iconColor, size: 16),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Единая точка входа к реестру УК — полноэкранный UkCompaniesScreen
  /// (карта, поиск по MKD, рейтинги, звонок/email). Дублирующий
  /// упрощённый bottom-sheet удалён.
  void _showAllUkCompaniesSheet(BuildContext context) {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const UkCompaniesScreen()),
    );
  }
}
