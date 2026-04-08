// services/Frontend/lib/screens/mesh_screen.dart
/// Mesh-сеть — автономная связь для чрезвычайных ситуаций.
/// Работает через P2P (BLE / Wi-Fi Direct) без интернета.
library;


import 'package:flutter/material.dart';

import '../theme/pulse_colors.dart';
import '../widgets/app_ui.dart';
import '../services/mesh_network_service.dart';

class MeshScreen extends StatefulWidget {
  const MeshScreen({super.key});

  @override
  State<MeshScreen> createState() => _MeshScreenState();
}

class _MeshScreenState extends State<MeshScreen> {
  bool _meshActive = false;
  int _peersCount = 0;

  @override
  void initState() {
    super.initState();
    _startMesh();
  }

  Future<void> _startMesh() async {
    try {
      MeshNetworkService().startMesh();
      if (mounted) {
        setState(() {
          _meshActive = true;
          _peersCount = 0; // Will be updated by mesh discovery
        });
      }
    } catch (e) {
      debugPrint('Mesh init error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
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
                _buildStatusCard(),
                const SizedBox(height: AppSpacing.xxl),
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
                _buildNetworkInfo(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusCard() {
    return AppPanel(
      child: Row(
        children: [
          Icon(
            _meshActive ? Icons.hub_rounded : Icons.hub_outlined,
            color: _meshActive ? PulseColors.success : PulseColors.textTertiary,
            size: 32,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _meshActive ? 'MESH-СЕТЬ АКТИВНА' : 'MESH-СЕТЬ ЗАПУСКАЕТСЯ',
                  style: AppTextStyles.cardTitle,
                ),
                Text(
                  'Автономная P2P-связь для города',
                  style: AppTextStyles.bodyMuted.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
          AppStatusBadge(
            label: _meshActive ? 'ONLINE' : 'INIT',
            color: _meshActive ? PulseColors.success : PulseColors.warning,
          ),
        ],
      ),
    );
  }

  Widget _buildNetworkInfo() {
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Статус', _meshActive ? 'Активна' : 'Инициализация',
              color: _meshActive ? PulseColors.success : PulseColors.warning),
          _buildInfoRow('Соседние узлы', '$_peersCount'),
          _buildInfoRow('Протокол', 'BLE + Wi-Fi Direct'),
          _buildInfoRow('Шифрование', 'AES-256'),
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
