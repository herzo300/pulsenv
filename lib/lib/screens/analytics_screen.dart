// lib/screens/analytics_screen.dart
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../models/complaint.dart';

/// Экран аналитики и отчетов
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({Key? key}) : super(key: key);
  
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, dynamic> _stats = {};
  List<Complaint> _complaints = [];
  bool _isLoading = true;
  int _selectedTimeRange = 7; // дней
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    try {
      final stats = await ApiService.getStats();
      final complaints = await ApiService.getComplaints(limit: 1000);
      
      setState(() {
        _stats = stats;
        _complaints = complaints.map((c) => Complaint.fromJson(c)).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Аналитика'),
        actions: [
          PopupMenuButton<int>(
            onSelected: (value) {
              setState(() => _selectedTimeRange = value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 7, child: Text('7 дней')),
              const PopupMenuItem(value: 30, child: Text('30 дней')),
              const PopupMenuItem(value: 90, child: Text('90 дней')),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Общая статистика
            _buildSummaryCards(),
            const SizedBox(height: 24),
            
            // График по категориям
            _buildCategoryChart(),
            const SizedBox(height: 24),
            
            // Heat map (временная шкала)
            _buildTimelineChart(),
            const SizedBox(height: 24),
            
            // Статистика по районам
            _buildDistrictStats(),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSummaryCards() {
    final total = _stats['total'] ?? 0;
    final resolved = _stats['resolved'] ?? 0;
    final pending = _stats['pending'] ?? 0;
    final resolutionRate = total > 0 ? (resolved / total * 100).toStringAsFixed(1) : '0';
    
    return Row(
      children: [
        Expanded(child: _StatCard(
          title: 'Всего',
          value: total.toString(),
          icon: Icons.format_list_numbered,
          color: Colors.blue,
        )),
        Expanded(child: _StatCard(
          title: 'Решено',
          value: resolved.toString(),
          icon: Icons.check_circle,
          color: Colors.green,
        )),
        Expanded(child: _StatCard(
          title: 'В работе',
          value: pending.toString(),
          icon: Icons.pending,
          color: Colors.orange,
        )),
        Expanded(child: _StatCard(
          title: '% решения',
          value: '$resolutionRate%',
          icon: Icons.trending_up,
          color: Colors.purple,
        )),
      ],
    );
  }
  
  Widget _buildCategoryChart() {
    final categories = _stats['by_category'] ?? {};
    final entries = categories.entries.toList()
      ..sort((a, b) => (b.value as int).compareTo(a.value as int));
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Жалобы по категориям',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: entries.isEmpty ? 10 : (entries.first.value * 1.2).toDouble(),
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() < entries.length) {
                            return Text(
                              entries[value.toInt()].key.toString().substring(0, 3),
                              style: const TextStyle(fontSize: 10),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 30),
                    ),
                    topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  barGroups: entries.asMap().entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: (entry.value.value as int).toDouble(),
                          color: Colors.primaries[entry.key % Colors.primaries.length],
                          width: 16,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildTimelineChart() {
    // Группировка по дням
    final dateMap = <String, int>{};
    for (var complaint in _complaints) {
      if (complaint.createdAt != null) {
        final date = DateTime.parse(complaint.createdAt!).toString().substring(0, 10);
        dateMap[date] = (dateMap[date] ?? 0) + 1;
      }
    }
    
    final sortedDates = dateMap.keys.toList()..sort();
    final spots = sortedDates.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), dateMap[e.value]!.toDouble());
    }).toList();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Динамика жалоб',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 30),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 3,
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDistrictStats() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Среднее время решения',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            // TODO: Добавить реальные данные
            const ListTile(
              leading: Icon(Icons.timer, color: Colors.green),
              title: Text('ЖКХ'),
              trailing: Text('2.3 дня'),
            ),
            const ListTile(
              leading: Icon(Icons.timer, color: Colors.orange),
              title: Text('Дороги'),
              trailing: Text('4.1 дня'),
            ),
            const ListTile(
              leading: Icon(Icons.timer, color: Colors.red),
              title: Text('Благоустройство'),
              trailing: Text('6.8 дней'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });
  
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
