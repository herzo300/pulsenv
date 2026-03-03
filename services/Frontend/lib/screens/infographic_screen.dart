import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;


/// Экран инфографики — открытые данные Нижневартовска.
/// Данные: Worker /infographic-data или бэкенд /opendata/summary.
class InfographicScreen extends StatefulWidget {
  const InfographicScreen({super.key});

  @override
  State<InfographicScreen> createState() => _InfographicScreenState();
}

class _InfographicScreenState extends State<InfographicScreen> {
  static const Color _bg = Color(0xFF0F0F23);
  static const Color _card = Color(0xFF1A1A2E);
  static const Color _accent = Color(0xFF00D9FF);
  static const Color _primary = Color(0xFF2196F3);

  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  static const Duration _timeout = Duration(seconds: 20);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _data = null;
    });

    // 1. Сначала пытаемся загрузить из локального assets
    try {
      final jsonStr = await rootBundle.loadString('assets/infographic_data.json');
      final localData = jsonDecode(jsonStr) as Map<String, dynamic>;
      if (localData.isNotEmpty) {
        setState(() {
          _data = Map<String, dynamic>.from(localData);
          _data!['source'] = 'local';
          _loading = false;
        });
        debugPrint('Infographic loaded from local assets');
        return;
      }
    } catch (e) {
      debugPrint('Infographic local load error: $e');
    }

    // 2. Fallback на Supabase
    const supabaseUrl = 'https://xpainxohbdoruakcijyq.supabase.co/rest/v1/infographic_data?select=*';
    const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhwYWlueG9oYmRvcnVha2NpanlxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE3OTg2NjUsImV4cCI6MjA4NzM3NDY2NX0.hTBTRflUGR9LDXASS15u1IHBZOv9pMt_4CGXqevr0tc';

    try {
      final r = await http.get(
        Uri.parse(supabaseUrl),
        headers: {
          'apikey': supabaseKey,
          'Authorization': 'Bearer $supabaseKey',
          'Content-Type': 'application/json',
        }
      ).timeout(_timeout);
      
      if (r.statusCode == 200) {
        final List<dynamic> data = jsonDecode(r.body);
        if (data.isNotEmpty) {
          final summaryData = data.firstWhere(
            (item) => item['data_type'] == 'summary', 
            orElse: () => data.first
          );
          
          final realData = summaryData['data'] as Map<String, dynamic>? ?? {};
          setState(() {
            _data = Map<String, dynamic>.from(realData);
            _data!['source'] = 'supabase';
            _loading = false;
          });
          return;
        }
      }
    } catch (e) {
      debugPrint('Infographic supabase error: $e');
    }

    setState(() {
      _error = 'Не удалось загрузить данные. Проверьте соединение.';
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text(
          'Инфографика',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _accent),
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.white54),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Повторить'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: _accent,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: _buildSections(),
                  ),
                ),
    );
  }

  List<Widget> _buildSections() {
    if (_data == null) return [];

    final list = <Widget>[];
    final updated = _data!['updated_at']?.toString() ?? '';
    if (updated.isNotEmpty) {
      list.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            'Обновлено: $updated',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
      );
    }

    if (_data!['source'] == 'backend') {
      final ds = _data!['datasets_summary'] as Map<String, dynamic>? ?? {};
      list.add(_sectionTitle('Открытые данные (датасеты)'));
      for (final e in ds.entries) {
        final v = e.value as Map<String, dynamic>? ?? {};
        list.add(_cardTile(
          v['name']?.toString() ?? e.key,
          'Записей: ${v['total_rows'] ?? '—'}',
          Icons.table_chart,
        ));
      }
      return list;
    }

    if (_data!['fuel'] != null) {
      final f = _data!['fuel'] as Map<String, dynamic>;
      list.add(_sectionTitle('Топливо'));
      list.add(_cardTile(
        'АЗС: ${f['stations'] ?? 0}',
        'Дата: ${f['date'] ?? '—'}',
        Icons.local_gas_station,
      ));
      final prices = f['prices'] as Map<String, dynamic>?;
      if (prices != null && prices.isNotEmpty) {
        for (final e in prices.entries) {
          final p = e.value is Map ? (e.value as Map).cast<String, dynamic>() : null;
          if (p != null && p['avg'] != null) {
            list.add(_cardTile(e.key, 'Средняя: ${p['avg']} ₽', Icons.attach_money));
          }
        }
      }
    }

    if (_data!['transport'] != null) {
      final t = _data!['transport'] as Map<String, dynamic>;
      list.add(_sectionTitle('Транспорт'));
      list.add(_cardTile(
        'Маршрутов: ${t['routes'] ?? 0}, Остановок: ${t['stops'] ?? 0}',
        'Мун.: ${t['municipal'] ?? 0}, Ком.: ${t['commercial'] ?? 0}',
        Icons.directions_bus,
      ));
    }

    if (_data!['education'] != null) {
      final e = _data!['education'] as Map<String, dynamic>;
      list.add(_sectionTitle('Образование'));
      list.add(_cardTile(
        'Детсады: ${e['kindergartens'] ?? 0}, Школы: ${e['schools'] ?? 0}',
        'Секции: ${e['sections'] ?? 0} (беспл.: ${e['sections_free'] ?? 0})',
        Icons.school,
      ));
    }

    if (_data!['uk'] != null) {
      final uk = _data!['uk'] as Map<String, dynamic>;
      list.add(_sectionTitle('Управляющие компании'));
      list.add(_cardTile(
        'УК: ${uk['total'] ?? 0}, Домов: ${uk['houses'] ?? 0}',
        '',
        Icons.business,
      ));
    }

    if (_data!['waste'] != null) {
      final w = _data!['waste'] as Map<String, dynamic>;
      list.add(_sectionTitle('Вывоз мусора'));
      list.add(_cardTile('Площадок: ${w['total'] ?? 0}', '', Icons.delete_outline));
    }

    // Блок бюджета и контрактов (на основе данных портала бюджета и договоров)
    if (_data!['agreements'] != null || _data!['budget_analysis'] != null) {
      final agreements = _data!['agreements'] as Map<String, dynamic>? ?? {};
      final analysis = _data!['budget_analysis'] as Map<String, dynamic>? ?? {};

      final totalAgreements = agreements['total'] ?? 0;
      final totalSumm = agreements['total_summ'] ?? 0;
      final invRatio = analysis['inv_ratio'] ?? 0;
      final gosRatio = analysis['gos_ratio'] ?? 0;
      final growthPct = analysis['growth_pct'] ?? 0;
      final maxYear = analysis['max_year'];

      list.add(_sectionTitle('Бюджет и контракты'));

      list.add(_cardTile(
        'Контрактов: $totalAgreements',
        'Сумма по контрактам: $totalSumm',
        Icons.account_balance,
      ));

      if (analysis.isNotEmpty) {
        final subtitle = StringBuffer();
        if (growthPct != 0) {
          subtitle.write('Рост совокупных расходов за период: $growthPct%');
        }
        if (invRatio != 0 || gosRatio != 0) {
          if (subtitle.isNotEmpty) subtitle.write(' · ');
          subtitle.write('Инвестиции: $invRatio%, госрасходы: $gosRatio%');
        }
        if (maxYear != null) {
          if (subtitle.isNotEmpty) subtitle.write(' · ');
          subtitle.write('Пик расходов: $maxYear г.');
        }
        if (subtitle.isNotEmpty) {
          list.add(_cardTile(
            'Анализ динамики бюджета',
            subtitle.toString(),
            Icons.trending_up,
          ));
        }
      }

      final bb = _data!['budget_bulletins'] as Map<String, dynamic>? ?? {};
      final bi = _data!['budget_info'] as Map<String, dynamic>? ?? {};
      final bbItems = (bb['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
      final biItems = (bi['items'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

      if (bbItems.isNotEmpty) {
        list.add(_cardTile(
          'Бюджетные бюллетени',
          'Выпусков: ${bb['total'] ?? bbItems.length}, последние: ${bbItems.take(3).map((e) => e['title']).join(', ')}',
          Icons.description,
        ));
      }
      if (biItems.isNotEmpty) {
        list.add(_cardTile(
          'Сведения о бюджете по годам',
          'Период: ${biItems.last['title']}–${biItems.first['title']}',
          Icons.calendar_month,
        ));
      }
    }

    if (list.length <= 1) {
      list.add(_sectionTitle('Данные'));
      list.add(_cardTile('Загружено секций: ${_data!.length}', '', Icons.info_outline));
    }

    return list;
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: _accent,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _cardTile(String title, String subtitle, IconData icon) {
    return Card(
      color: _card,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: _primary),
        title: Text(title, style: const TextStyle(color: Colors.white)),
        subtitle: subtitle.isEmpty ? null : Text(subtitle, style: TextStyle(color: Colors.white70, fontSize: 12)),
      ),
    );
  }
}
