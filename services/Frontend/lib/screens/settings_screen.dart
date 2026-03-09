import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Экран настроек приложения «Пульс Города»
/// - Выбор категорий push-уведомлений
/// - Управление уведомлениями
/// - О приложении
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  // Категории уведомлений
  final Map<String, _CategoryConfig> _categories = {
    'Дороги': _CategoryConfig(icon: Icons.directions_car, color: const Color(0xFFFF3D00), enabled: true),
    'ЖКХ': _CategoryConfig(icon: Icons.apartment, color: const Color(0xFF00E5FF), enabled: true),
    'Безопасность': _CategoryConfig(icon: Icons.shield_outlined, color: const Color(0xFFFFC107), enabled: true),
    'Экология': _CategoryConfig(icon: Icons.eco_outlined, color: const Color(0xFF10B981), enabled: true),
    'Благоустройство': _CategoryConfig(icon: Icons.park_outlined, color: const Color(0xFF8BC34A), enabled: true),
    'Транспорт': _CategoryConfig(icon: Icons.directions_bus, color: const Color(0xFF2196F3), enabled: true),
    'Освещение': _CategoryConfig(icon: Icons.lightbulb_outline, color: const Color(0xFFFDD835), enabled: true),
    'Мусор': _CategoryConfig(icon: Icons.delete_outline, color: const Color(0xFF795548), enabled: true),
    'Вода': _CategoryConfig(icon: Icons.water_drop_outlined, color: const Color(0xFF039BE5), enabled: true),
    'Отопление': _CategoryConfig(icon: Icons.thermostat_outlined, color: const Color(0xFFFF5722), enabled: true),
    'Шум': _CategoryConfig(icon: Icons.volume_up_outlined, color: const Color(0xFF9C27B0), enabled: true),
    'Прочее': _CategoryConfig(icon: Icons.more_horiz, color: const Color(0xFF607D8B), enabled: true),
  };

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _soundEnabled = prefs.getBool('sound_enabled') ?? true;
      _vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;

      final savedCategories = prefs.getString('notification_categories');
      if (savedCategories != null) {
        final Map<String, dynamic> saved = jsonDecode(savedCategories);
        for (final entry in saved.entries) {
          if (_categories.containsKey(entry.key)) {
            _categories[entry.key]!.enabled = entry.value as bool;
          }
        }
      }
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setBool('sound_enabled', _soundEnabled);
    await prefs.setBool('vibration_enabled', _vibrationEnabled);

    final categoriesMap = <String, bool>{};
    for (final entry in _categories.entries) {
      categoriesMap[entry.key] = entry.value.enabled;
    }
    await prefs.setString('notification_categories', jsonEncode(categoriesMap));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0d1117),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'НАСТРОЙКИ',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 3,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ── Уведомления ──
          _buildSectionHeader('УВЕДОМЛЕНИЯ', Icons.notifications_active_outlined),
          const SizedBox(height: 8),
          _buildSwitchTile(
            'Push-уведомления',
            'Получать уведомления о новых жалобах',
            Icons.notifications_outlined,
            _notificationsEnabled,
            (val) {
              setState(() => _notificationsEnabled = val);
              _saveSettings();
            },
          ),
          _buildSwitchTile(
            'Звук',
            'Звуковое сопровождение уведомлений',
            Icons.volume_up_outlined,
            _soundEnabled,
            (val) {
              setState(() => _soundEnabled = val);
              _saveSettings();
            },
          ),
          _buildSwitchTile(
            'Вибрация',
            'Тактильная обратная связь',
            Icons.vibration,
            _vibrationEnabled,
            (val) {
              setState(() => _vibrationEnabled = val);
              _saveSettings();
            },
          ),

          const SizedBox(height: 24),

          // ── Категории уведомлений ──
          _buildSectionHeader('КАТЕГОРИИ УВЕДОМЛЕНИЙ', Icons.category_outlined),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'Выберите типы проблем для отслеживания',
              style: TextStyle(
                color: Colors.white.withOpacity(0.3),
                fontSize: 11,
              ),
            ),
          ),
          _buildSelectAllRow(),
          const SizedBox(height: 8),
          ..._categories.entries.map((e) => _buildCategoryTile(e.key, e.value)),

          const SizedBox(height: 24),

          // ── О приложении ──
          _buildSectionHeader('О ПРИЛОЖЕНИИ', Icons.info_outline),
          const SizedBox(height: 8),
          _buildInfoTile('Версия', '1.0.0'),
          _buildInfoTile('Город', 'Нижневартовск'),
          _buildInfoTile('Движок', 'Flutter + Supabase'),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF00E5FF), size: 16),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF00E5FF),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0d1117),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        leading: Icon(icon, color: value ? const Color(0xFF00E5FF) : Colors.white24, size: 22),
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 10)),
        trailing: Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF00E5FF),
          activeTrackColor: const Color(0xFF00E5FF).withOpacity(0.3),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      ),
    );
  }

  Widget _buildSelectAllRow() {
    final allEnabled = _categories.values.every((c) => c.enabled);
    final noneEnabled = _categories.values.every((c) => !c.enabled);
    return Row(
      children: [
        TextButton.icon(
          icon: Icon(
            allEnabled ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: const Color(0xFF00E5FF),
          ),
          label: const Text('Все', style: TextStyle(color: Color(0xFF00E5FF), fontSize: 11)),
          onPressed: () {
            setState(() {
              for (final c in _categories.values) {
                c.enabled = true;
              }
            });
            _saveSettings();
          },
        ),
        TextButton.icon(
          icon: Icon(
            noneEnabled ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: Colors.white38,
          ),
          label: const Text('Нет', style: TextStyle(color: Colors.white38, fontSize: 11)),
          onPressed: () {
            setState(() {
              for (final c in _categories.values) {
                c.enabled = false;
              }
            });
            _saveSettings();
          },
        ),
      ],
    );
  }

  Widget _buildCategoryTile(String name, _CategoryConfig config) {
    return GestureDetector(
      onTap: () {
        setState(() => config.enabled = !config.enabled);
        _saveSettings();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: config.enabled
              ? config.color.withOpacity(0.08)
              : const Color(0xFF0d1117),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: config.enabled
                ? config.color.withOpacity(0.3)
                : Colors.white.withOpacity(0.05),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: config.color.withOpacity(config.enabled ? 0.2 : 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                config.icon,
                color: config.enabled ? config.color : Colors.white24,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  color: config.enabled ? Colors.white : Colors.white38,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: config.enabled
                  ? Icon(Icons.check_circle, key: const ValueKey('on'), color: config.color, size: 22)
                  : const Icon(Icons.circle_outlined, key: ValueKey('off'), color: Colors.white24, size: 22),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0d1117),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _CategoryConfig {
  final IconData icon;
  final Color color;
  bool enabled;

  _CategoryConfig({
    required this.icon,
    required this.color,
    required this.enabled,
  });
}
