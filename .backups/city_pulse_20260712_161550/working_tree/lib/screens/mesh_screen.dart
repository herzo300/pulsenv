// services/Frontend/lib/screens/mesh_screen.dart
/// Mesh-сеть — автономная связь для чрезвычайных ситуаций.
/// Работает через P2P (BLE / Wi-Fi Direct) без интернета.
library;

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../map/map_config.dart';
import '../theme/pulse_colors.dart';
import '../widgets/app_ui.dart';
import '../services/mesh_network_service.dart';

class MeshScreen extends StatefulWidget {
  const MeshScreen({super.key});

  @override
  State<MeshScreen> createState() => _MeshScreenState();
}

class _MeshScreenState extends State<MeshScreen> with SingleTickerProviderStateMixin {
  final MeshNetworkService _meshService = MeshNetworkService();
  final TextEditingController _searchController = TextEditingController();
  final MapController _mapController = MapController();
  late AnimationController _radarController;

  @override
  void initState() {
    super.initState();
    _meshService.addListener(_onServiceStateChanged);
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (_meshService.isConnected) {
      _radarController.repeat();
    }
  }

  @override
  void dispose() {
    _meshService.removeListener(_onServiceStateChanged);
    _searchController.dispose();
    _radarController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _onServiceStateChanged() {
    if (mounted) {
      setState(() {
        if (_meshService.isConnected) {
          if (!_radarController.isAnimating) {
            _radarController.repeat();
          }
        } else {
          _radarController.stop();
        }
      });
    }
  }

  Future<void> _toggleMesh() async {
    HapticFeedback.heavyImpact();
    await _meshService.toggleConnection();
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _meshService.isConnected;
    final peers = _meshService.filteredPeers;
    final totalCount = _meshService.peers.length;

    return Scaffold(
      backgroundColor: PulseColors.background,
      appBar: AppBar(
        title: const Text(
          'MESH-СЕТЬ',
          style: TextStyle(
            letterSpacing: 1.5,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: AppScreenBackground(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildRadarCard(isConnected),
                const SizedBox(height: AppSpacing.lg),
                _buildToggleButton(isConnected),
                const SizedBox(height: AppSpacing.xxl),
                if (isConnected) ...[
                  const SizedBox(height: AppSpacing.lg),
                  Text('КАРТА УЗЛОВ MESH-СЕТИ', style: AppTextStyles.overline),
                  const SizedBox(height: AppSpacing.sm),
                  _buildMeshMap(peers),
                  const SizedBox(height: AppSpacing.xl),
                  _buildSearchAndCountSection(peers.length, totalCount),
                  const SizedBox(height: AppSpacing.md),
                  _buildPeersList(peers),
                  const SizedBox(height: AppSpacing.xxl),
                ],
                Text('ВОЗМОЖНОСТИ', style: AppTextStyles.overline),
                const SizedBox(height: AppSpacing.sm),
                _buildFeatureCard(
                  title: 'P2P-СВЯЗЬ',
                  subtitle:
                      'Обмен данными через BLE / Wi-Fi Direct без интернета',
                  icon: Icons.bluetooth_connected_rounded,
                  color: PulseColors.primary,
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildFeatureCard(
                  title: 'РЕТРАНСЛЯЦИЯ',
                  subtitle:
                      'Сообщения передаются через соседние узлы к другим пользователям',
                  icon: Icons.device_hub_rounded,
                  color: PulseColors.warning,
                ),
                const SizedBox(height: AppSpacing.sm),
                _buildFeatureCard(
                  title: 'РАБОТА В ЭКСТРЕМЕ',
                  subtitle:
                      'Устойчивая связь при обрыве сотовой сети, ЧС, морозах до -40°C',
                  icon: Icons.ac_unit_rounded,
                  color: const Color(0xFF3B82F6),
                ),
                const SizedBox(height: AppSpacing.xxl),
                Text('СОСТОЯНИЕ СЕТИ', style: AppTextStyles.overline),
                const SizedBox(height: AppSpacing.sm),
                _buildNetworkInfo(isConnected, totalCount),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMeshMap(List<Map<String, dynamic>> peers) {
    final markers = <Marker>[];
    
    // Add central user marker
    markers.add(
      Marker(
        point: const LatLng(60.940, 76.570),
        width: 45,
        height: 45,
        child: Container(
          decoration: BoxDecoration(
            color: PulseColors.primary.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: PulseColors.primary, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: PulseColors.primary.withOpacity(0.6),
                    blurRadius: 8,
                    spreadRadius: 3,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    for (final peer in peers) {
      final latVal = peer['lat'];
      final lngVal = peer['lng'];
      if (latVal != null && lngVal != null) {
        final point = LatLng((latVal as num).toDouble(), (lngVal as num).toDouble());
        final signal = peer['signal'] as double? ?? 0.5;
        
        Color signalColor = PulseColors.success;
        if (signal < 0.4) {
          signalColor = PulseColors.negative;
        } else if (signal < 0.7) {
          signalColor = PulseColors.warning;
        }

        markers.add(
          Marker(
            point: point,
            width: 40,
            height: 40,
            child: Tooltip(
              message: peer['name'] ?? 'Узел',
              child: Container(
                decoration: BoxDecoration(
                  color: signalColor.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: signalColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: signalColor.withOpacity(0.4),
                          blurRadius: 6,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }

    return AppPanel(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 220,
          child: FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: LatLng(60.940, 76.570),
              initialZoom: 13.5,
              minZoom: 11,
              maxZoom: 17,
              interactionOptions: InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: MapConfig.tileUrl,
                userAgentPackageName: 'ru.soobshio.app',
              ),
              MarkerLayer(markers: markers),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRadarCard(bool isConnected) {
    return AppPanel(
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: AppRadii.md,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (isConnected)
              AnimatedBuilder(
                animation: _radarController,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: List.generate(3, (index) {
                      final progress = (_radarController.value + index / 3) % 1.0;
                      return Container(
                        width: 150 * progress,
                        height: 150 * progress,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: PulseColors.primary.withOpacity((1.0 - progress) * 0.4),
                            width: 2.0,
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isConnected ? Icons.wifi_tethering : Icons.portable_wifi_off_rounded,
                  color: isConnected ? PulseColors.primary : PulseColors.textTertiary,
                  size: 48,
                ).animate(
                  target: isConnected ? 1.0 : 0.0,
                  onPlay: (controller) => controller.repeat(reverse: true),
                ).scale(
                  begin: const Offset(1.0, 1.0),
                  end: const Offset(1.15, 1.15),
                  duration: const Duration(seconds: 2),
                  curve: Curves.easeInOut,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  isConnected ? 'ИДЕТ ПОИСК УСТРОЙСТВ' : 'MESH-СЕТЬ ВЫКЛЮЧЕНА',
                  style: AppTextStyles.cardTitle.copyWith(
                    letterSpacing: 1.2,
                    color: isConnected ? PulseColors.textPrimary : PulseColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  isConnected 
                      ? 'Обнаружение P2P узлов в радиусе 100 метров' 
                      : 'Включите mesh для автономного обмена сообщениями',
                  style: AppTextStyles.bodyMuted.copyWith(fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleButton(bool isConnected) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton.icon(
        onPressed: _toggleMesh,
        icon: Icon(
          isConnected ? Icons.power_settings_new_rounded : Icons.sensors_rounded,
          color: Colors.white,
        ),
        label: Text(
          isConnected ? 'ОТКЛЮЧИТЬ MESH-СВЯЗЬ' : 'ПОДКЛЮЧИТЬ MESH-СВЯЗЬ',
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: isConnected ? PulseColors.negative : PulseColors.primaryDeep,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: AppRadii.md),
          elevation: isConnected ? 0 : 8,
          shadowColor: PulseColors.primary.withOpacity(0.4),
        ),
      ),
    );
  }

  Widget _buildSearchAndCountSection(int filteredCount, int totalCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('ПОИСК УЧАСТНИКОВ', style: AppTextStyles.overline),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: PulseColors.primary.withOpacity(0.1),
                borderRadius: AppRadii.sm,
                border: Border.all(color: PulseColors.primary.withOpacity(0.3)),
              ),
              child: Text(
                '$totalCount в сети',
                style: TextStyle(
                  color: PulseColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _searchController,
          onChanged: _meshService.searchPeers,
          style: TextStyle(color: PulseColors.textPrimary, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Введите имя или ID участника...',
            hintStyle: TextStyle(color: PulseColors.textTertiary.withOpacity(0.7)),
            prefixIcon: Icon(Icons.search_rounded, color: PulseColors.textSecondary),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear_rounded, color: PulseColors.textSecondary),
                    onPressed: () {
                      _searchController.clear();
                      _meshService.searchPeers('');
                      FocusScope.of(context).unfocus();
                    },
                  )
                : null,
            filled: true,
            fillColor: PulseColors.surface,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadii.md,
              borderSide: BorderSide(color: PulseColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadii.md,
              borderSide: const BorderSide(color: PulseColors.primaryDeep),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPeersList(List<Map<String, dynamic>> peers) {
    if (peers.isEmpty) {
      return AppPanel(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          width: double.infinity,
          alignment: Alignment.center,
          child: Column(
            children: [
              Icon(Icons.people_outline_rounded, color: PulseColors.textTertiary, size: 36),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _searchController.text.isNotEmpty 
                    ? 'Никого не найдено по запросу' 
                    : 'Нет обнаруженных участников',
                style: AppTextStyles.bodyMuted,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: peers.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final peer = peers[index];
        final name = peer['name'] as String? ?? 'Анонимный узел';
        final role = peer['role'] as String? ?? 'Узел';
        final signal = peer['signal'] as double? ?? 0.5;
        final id = peer['id'] as String? ?? 'ID';
        
        Color signalColor = PulseColors.success;
        if (signal < 0.4) {
          signalColor = PulseColors.negative;
        } else if (signal < 0.7) {
          signalColor = PulseColors.warning;
        }

        return AppPanel(
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: PulseColors.primary.withOpacity(0.1),
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: PulseColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTextStyles.cardTitle),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          role,
                          style: TextStyle(
                            color: role.contains('Шлюз') ? PulseColors.accentViolet : PulseColors.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ID: $id',
                          style: AppTextStyles.bodyMuted.copyWith(fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Icon(Icons.signal_cellular_alt_rounded, color: signalColor, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${(signal * 100).toInt()}%',
                        style: TextStyle(
                          color: signalColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Только что',
                    style: AppTextStyles.bodyMuted.copyWith(fontSize: 9),
                  ),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0);
      },
    );
  }

  Widget _buildNetworkInfo(bool isConnected, int peersCount) {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Статус', isConnected ? 'Активна' : 'Отключена',
              color: isConnected ? PulseColors.success : PulseColors.textTertiary),
          _buildInfoRow('Участники в сети', '$peersCount чел.'),
          _buildInfoRow('Используемые каналы', 'Bluetooth P2P + Wi-Fi Direct'),
          _buildInfoRow('Защита трафика', 'AES-256 (Шифрование сквозное)'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.overline),
          Text(
            value,
            style: TextStyle(
              color: color ?? PulseColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: AppRadii.md,
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: AppRadii.sm,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  subtitle,
                  style: AppTextStyles.bodyMuted.copyWith(fontSize: 10),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
