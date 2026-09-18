import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../map/map_config.dart';

class CollectivePetitionItem {
  final int id;
  final String title;
  final String targetAuthority;
  final String category;
  final String address;
  final double? lat;
  final double? lng;
  final String description;
  final String legalBasis;
  final int signaturesCount;
  final int requiredSignatures;
  final String status;
  final String creatorName;
  final String? createdAt;
  final bool isReadyForSubmission;

  CollectivePetitionItem({
    required this.id,
    required this.title,
    required this.targetAuthority,
    required this.category,
    required this.address,
    this.lat,
    this.lng,
    required this.description,
    required this.legalBasis,
    required this.signaturesCount,
    required this.requiredSignatures,
    required this.status,
    required this.creatorName,
    this.createdAt,
    required this.isReadyForSubmission,
  });

  factory CollectivePetitionItem.fromJson(Map<String, dynamic> json) {
    return CollectivePetitionItem(
      id: json['id'] as int? ?? 0,
      title: json['title']?.toString() ?? 'Коллективный иск',
      targetAuthority: json['target_authority']?.toString() ?? 'Прокуратура',
      category: json['category']?.toString() ?? 'ЖКХ',
      address: json['address']?.toString() ?? 'Нижневартовск',
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      description: json['description']?.toString() ?? '',
      legalBasis: json['legal_basis']?.toString() ?? '',
      signaturesCount: json['signatures_count'] as int? ?? 1,
      requiredSignatures: json['required_signatures'] as int? ?? 10,
      status: json['status']?.toString() ?? 'active',
      creatorName: json['creator_name']?.toString() ?? 'Жители дома',
      createdAt: json['created_at']?.toString(),
      isReadyForSubmission: json['is_ready_for_submission'] as bool? ?? false,
    );
  }
}

class PetitionService extends ChangeNotifier {
  static final PetitionService instance = PetitionService._internal();
  factory PetitionService() => instance;
  PetitionService._internal();

  List<CollectivePetitionItem> _petitions = [];
  bool _isLoading = false;

  List<CollectivePetitionItem> get petitions => _petitions;
  bool get isLoading => _isLoading;

  Future<List<CollectivePetitionItem>> fetchPetitions({String? address}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final queryParams = <String, String>{};
      if (address != null && address.isNotEmpty) queryParams['address'] = address;
      final uri = Uri.parse('${MapConfig.backendApiBaseUrl}/api/v1/petitions/list').replace(queryParameters: queryParams);
      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final rawList = data['petitions'] as List<dynamic>? ?? [];
        _petitions = rawList.map((e) => CollectivePetitionItem.fromJson(e as Map<String, dynamic>)).toList();
        notifyListeners();
        return _petitions;
      }
    } catch (e) {
      debugPrint('PetitionService fetch error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return [];
  }

  Future<bool> signPetition(int petitionId, {required String userName, String? flatNumber}) async {
    try {
      final uri = Uri.parse('${MapConfig.backendApiBaseUrl}/api/v1/petitions/$petitionId/sign');
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_name': userName,
          'flat_number': flatNumber ?? 'кв. —',
        }),
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        await fetchPetitions();
        return true;
      }
    } catch (e) {
      debugPrint('PetitionService sign error: $e');
    }
    return false;
  }
}
