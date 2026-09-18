import 'dart:math' as math;
import 'dart:io';

/// Результат биометрического анализа потерянного животного (Vision AI Pet Biometrics).
class PetBiometricsResult {
  final String species; // 'Собака' | 'Кошка' | 'Другое'
  final String estimatedBreed; // Порода
  final String primaryColor; // Основной окрас
  final String distinguishingMarks; // Приметы (белое пятно на груди, ошейник и т.д.)
  final double confidence; // Точность распознавания (0.0 - 1.0)
  final List<PetMatchCandidate> topMatches;

  PetBiometricsResult({
    required this.species,
    required this.estimatedBreed,
    required this.primaryColor,
    required this.distinguishingMarks,
    required this.confidence,
    required this.topMatches,
  });
}

class PetMatchCandidate {
  final String reportId;
  final String petName;
  final String lastSeenAddress;
  final double matchPercentage;
  final String photoUrl;
  final String contactPhone;

  PetMatchCandidate({
    required this.reportId,
    required this.petName,
    required this.lastSeenAddress,
    required this.matchPercentage,
    required this.photoUrl,
    required this.contactPhone,
  });
}

/// Сервис биометрического сравнения и идентификации животных
class PetBiometricsService {
  static final PetBiometricsService _instance = PetBiometricsService._internal();
  factory PetBiometricsService() => _instance;
  PetBiometricsService._internal();

  /// Анализ фото животного и сравнение с базой потеряшек
  Future<PetBiometricsResult> analyzePetPhoto(File photo, {String? userDescription}) async {
    // Имитация высокоточного Vision AI инференса
    await Future.delayed(const Duration(milliseconds: 1400));

    final desc = userDescription?.toLowerCase() ?? '';
    final isCat = desc.contains('кот') || desc.contains('кош') || desc.contains('кошак');

    if (isCat) {
      return PetBiometricsResult(
        species: 'Кошка / Кот',
        estimatedBreed: 'Шотландская вислоухая / Британская короткошёрстная',
        primaryColor: 'Серый / Пепельный табби',
        distinguishingMarks: 'Янтарные глаза, закруглённые уши, темные полосы на хвосте',
        confidence: 0.94,
        topMatches: [
          PetMatchCandidate(
            reportId: 'lost_pet_cat_1',
            petName: 'Барсик',
            lastSeenAddress: 'ул. Чапаева, 49',
            matchPercentage: 96.4,
            photoUrl: 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=400',
            contactPhone: '+7 (922) 400-11-22',
          ),
          PetMatchCandidate(
            reportId: 'lost_pet_cat_2',
            petName: 'Дымка',
            lastSeenAddress: 'ул. Интернациональная, 12',
            matchPercentage: 88.1,
            photoUrl: 'https://images.unsplash.com/photo-1573865526739-10659fec78a5?w=400',
            contactPhone: '+7 (922) 411-33-44',
          ),
        ],
      );
    } else {
      return PetBiometricsResult(
        species: 'Собака',
        estimatedBreed: 'Сибирский хаски / Метис',
        primaryColor: 'Черно-белый / Серебристый',
        distinguishingMarks: 'Гетерохромия (разноцветные глаза), маска на морде, тканевый ошейник',
        confidence: 0.96,
        topMatches: [
          PetMatchCandidate(
            reportId: 'lost_pet_dog_1',
            petName: 'Арчи',
            lastSeenAddress: 'проспект Победы, 19',
            matchPercentage: 97.8,
            photoUrl: 'https://images.unsplash.com/photo-1537151625747-768eb6cf92b2?w=400',
            contactPhone: '+7 (922) 444-55-66',
          ),
          PetMatchCandidate(
            reportId: 'lost_pet_dog_2',
            petName: 'Норд',
            lastSeenAddress: 'ул. 60 лет Октября, 4',
            matchPercentage: 84.5,
            photoUrl: 'https://images.unsplash.com/photo-1543466835-00a7907e9de1?w=400',
            contactPhone: '+7 (922) 455-77-88',
          ),
        ],
      );
    }
  }
}
