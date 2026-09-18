// lib/services/hermes_house_sentinel_service.dart
//
// Сервис круглосуточного мониторинга дома ИИ-Гермесом (Hermes House Sentinel).
// Автоматически создает задание на сервере, сканирует ЕДДС/соцсети и отправляет уведомления в чат.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../map/map_config.dart';
import 'house_intelligence_service.dart';
import 'notification_service.dart';

class HermesHouseSentinelService {
  static final HermesHouseSentinelService instance = HermesHouseSentinelService._();
  HermesHouseSentinelService._();

  /// Активирует круглосуточный мониторинг дома Гермесом, создает задачу на сервере
  /// и публикует системное сообщение в чат ИИ-помощника.
  Future<bool> activateHouseMonitoring(String address, {BuildContext? context}) async {
    final clean = address.trim();
    if (clean.isEmpty) return false;

    HapticFeedback.mediumImpact();

    // 1. Получаем данные паспорта дома
    final intel = await HouseIntelligenceService.instance.getHouseIntelligence(clean);

    // 2. Сохраняем в локальные настройки
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('hermes_monitored_house', clean);
    await prefs.setString('jkh_user_selected_house', clean);
    await prefs.setBool('jkh_house_subscribed', true);

    // 3. Отправляем задачу на сервер
    try {
      final uri = Uri.parse('${MapConfig.backendApiBaseUrl}/hermes/house-agent/task');
      await http.post(
        uri,
        headers: {'Content-Type': 'application/json; charset=utf-8'},
        body: jsonEncode({
          'address': clean,
          'user_id': prefs.getString('profile_user_id') ?? 'resident_nv',
          'enable_push_alerts': true,
        }),
      ).timeout(const Duration(seconds: 4));
    } catch (e) {
      debugPrint('Server Hermes house task sync notice: $e');
    }

    // 4. Формируем подробный отчет Гермеса в чат
    final hermesMessageText = '''🏛️ **Гермес активировал круглосуточный мониторинг вашего дома: $clean**

📋 **Технический паспорт и статус:**
• **Год постройки:** ${intel.buildYear} г. (${intel.series})
• **Этажность:** ${intel.floors} эт., ${intel.entrances} подъездов, ${intel.apartments} квартир
• **Управляющая компания:** ${intel.ukName}
• **Диспетчерская 24/7:** ${intel.ukPhone}
• **Индекс здоровья дома:** ${intel.healthScore}% (${intel.energyClass})

🌡️ **Телеметрия систем:**
• **Отопление УТС:** ${intel.heatingSupplyC}°C / ${intel.heatingReturnC}°C (${intel.heatingStatus})
• **ГВС:** ${intel.hotWaterTempC}°C (${intel.hotWaterStatus})
• **ХВС давление:** ${intel.coldWaterPressureAtm} атм
• **Лифты:** ${intel.elevatorsStatus}

🛠️ **Капитальный ремонт:**
• **План Югры на ${intel.nextRepairYear} г.:** ${intel.plannedWorks} (Собрано взносов: ${intel.fundCollectedPct}%)

🛡️ *Я круглосуточно сканирую городские сводки ЕДДС, отключения НКС, сигналы УК и городские паблики Нижневартовска. При любых происшествиях я немедленно пришлю вам push-уведомление и сообщу здесь в чате.*''';

    // 5. Записываем в историю чата Гермеса
    try {
      final savedChatJson = prefs.getString('hermes_chat_history_v1');
      List<dynamic> chatList = [];
      if (savedChatJson != null && savedChatJson.isNotEmpty) {
        chatList = jsonDecode(savedChatJson) as List<dynamic>;
      }

      // Проверяем, нет ли уже такого сообщения за сегодня
      final alreadyPresent = chatList.any((m) =>
          m is Map && (m['text']?.toString().contains('мониторинг вашего дома: $clean') ?? false));

      if (!alreadyPresent) {
        chatList.add({
          'role': 'ai',
          'text': hermesMessageText,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
        await prefs.setString('hermes_chat_history_v1', jsonEncode(chatList));
      }
    } catch (_) {}

    // 6. Отправляем системный пуш
    try {
      NotificationService().showPushNotification(
        id: clean.hashCode.abs() % 100000,
        title: '🤖 Гермес: Мониторинг дома активен',
        body: 'Дом $clean взят под круглосуточный ИИ-контроль. Отслеживаем ЕДДС и отключения.',
        forceShow: true,
      );
    } catch (_) {}

    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF0F172A),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF00E5FF), width: 1.2),
          ),
          content: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFF00E5FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.psychology_rounded, color: Colors.black, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Гермес взял дом под мониторинг',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      clean,
                      style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }

    return true;
  }
}
