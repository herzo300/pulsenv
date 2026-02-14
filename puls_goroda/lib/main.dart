import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import 'screens/pulse_splash_screen.dart';

void main() {
  runApp(PulsGorodaApp());
}

class PulsGorodaApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Пульс Города',
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color(0xFF7C3AED),
          brightness: Brightness.dark,
        ),
        textTheme: GoogleFonts.interTextTheme(
          applyBodyTypography: true,
        ).copyWith(
          headlineSmall: GoogleFonts.inter(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      home: HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  late final AnimationController _sheetController;
  late final Animation<double> _sheetAnimation;
  bool _showSplash = true;

  // Мок данные жалоб (Нижневартовск)
  final List<Report> reports = [
    Report('Яма на Мира 12', 'Дороги', LatLng(61.267, 76.583), 'high'),
    Report('Нет света Омская 45', 'Освещение', LatLng(61.265, 76.585), 'medium'),
    Report('Мусор у ТЦ Ладуга', 'ЖКХ', LatLng(61.270, 76.580), 'low'),
    Report('Светофор сломан', 'Дороги', LatLng(61.268, 76.582), 'high'),
    // Добавь больше...
  ];

  @override
  void initState() {
    super.initState();
    _sheetController = AnimationController(vsync: this, duration: Duration(milliseconds: 300));
    _sheetAnimation = CurvedAnimation(parent: _sheetController, curve: Curves.easeOutCubic);
    _sheetController.forward();
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) {
      return PulseSplashScreen(
        totalComplaints: reports.length,
        openComplaints: reports.where((r) => r.urgency == 'high').length,
        resolvedComplaints: reports.where((r) => r.urgency == 'low').length,
        onComplete: () => setState(() => _showSplash = false),
      );
    }
    return Scaffold(
      body: Stack(
        children: [
          // Фон градиент
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF1E3A8A),
                  Color(0xFF312E81),
                  Color(0xFF7C3AED),
                ],
              ),
            ),
          ),
          
          // Карта
          Positioned.fill(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: LatLng(61.267, 76.583), // Нижневартовск
                initialZoom: 13.0,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.app',
                ),
                MarkerClusterLayerWidget(
                  options: MarkerClusterLayerWidgetOptions(
                    maxClusterRadius: 45,
                    size: Size(60, 60),
                    markers: reports.map((report) => report.toMarker()).toList(),
                    builder: (context, markers) {
                      return Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Colors.purple, Colors.blue],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.purple.withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '${markers.length}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Верхняя панель
          SafeArea(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        'Пульс Города',
                        style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Spacer(),
                      GestureDetector(
                        onTap: () => _sheetController.isDismissed
                            ? _sheetController.forward()
                            : _sheetController.reverse(),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.tune, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Фильтры',
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Нижневартовск • ${reports.length} жалоб',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Нижняя кнопка "Создать жалобу"
          Positioned(
            bottom: 32,
            right: 16,
            child: GestureDetector(
              onTap: () {
                // Navigator.push(ReportFormScreen());
                print('Открыть форму жалобы');
              },
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.white, Colors.grey.shade200],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.add,
                  size: 32,
                  color: Color(0xFF1E3A8A),
                ),
              ),
            ),
          ),

          // Фильтры Sheet
          Positioned(
            top: 0,
            right: 0,
            child: AnimatedBuilder(
              animation: _sheetAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(
                    MediaQuery.of(context).size.width * (1 - _sheetAnimation.value * 0.85),
                    0,
                  ),
                  child: Container(
                    width: MediaQuery.of(context).size.width * 0.85,
                    height: MediaQuery.of(context).size.height,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.95),
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 30,
                          spreadRadius: -10,
                        ),
                      ],
                    ),
                    child: SafeArea(
                      child: Column(
                        children: [
                          Padding(
                            padding: EdgeInsets.all(24),
                            child: Row(
                              children: [
                                Text(
                                  'Фильтры',
                                  style: GoogleFonts.inter(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                Spacer(),
                                GestureDetector(
                                  onTap: () => _sheetController.reverse(),
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView(
                              padding: EdgeInsets.symmetric(horizontal: 24),
                              children: [
                                _buildFilterChip('Дороги', 12, true),
                                _buildFilterChip('Освещение', 8, false),
                                _buildFilterChip('ЖКХ', 15, false),
                                _buildFilterChip('Безопасность', 5, false),
                                SizedBox(height: 24),
                                _buildFilterChip('Критично', 3, false),
                                _buildFilterChip('Срочно', 7, true),
                                _buildFilterChip('Обычное', 30, false),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int count, bool selected) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: selected
            ? Colors.white.withOpacity(0.15)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(selected ? 0.5 : 0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// Модель жалобы
class Report {
  final String title;
  final String category;
  final LatLng position;
  final String urgency;

  Report(this.title, this.category, this.position, this.urgency);

  Marker toMarker() {
    Color color;
    switch (urgency) {
      case 'high':
        color = Colors.red;
        break;
      case 'medium':
        color = Colors.orange;
        break;
      default:
        color = Colors.green;
    }

    return Marker(
      width: 40,
      height: 40,
      point: position,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.5),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          Icons.location_on,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }
}
