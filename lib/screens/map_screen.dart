// lib/screens/map_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../models/cluster.dart';

class ComplaintMapScreen extends StatefulWidget {
  const ComplaintMapScreen({super.key});

  @override
  State<ComplaintMapScreen> createState() => _ComplaintMapScreenState();
}

class _ComplaintMapScreenState extends State<ComplaintMapScreen> {
  Set<Marker> _markers = {};
  bool _isLoading = true;

  // Вставь сюда адрес своего backend
  final String backendUrl = 'http://ТВОЙ_IP:8000';

  @override
  void initState() {
    super.initState();
    _loadClusters();
  }

  Future<void> _loadClusters() async {
    try {
      final resp = await http.get(Uri.parse('$backendUrl/complaints/clusters'));
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body) as List<dynamic>?;
        if (data == null) {
          debugPrint('Некорректный формат ответа');
          return;
        }
        final clusters = data.map((e) => Cluster.fromJson(e as Map<String, dynamic>)).toList();
        _createMarkers(clusters);
      }
    } catch (e) {
      debugPrint('Ошибка загрузки кластеров: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _createMarkers(List<Cluster> clusters) {
    final Set<Marker> markers = clusters.map((cluster) {
      return Marker(
        markerId: MarkerId('cluster_${cluster.id}'),
        position: LatLng(cluster.lat, cluster.lon),
        infoWindow: InfoWindow(
          title: 'Кластер #${cluster.id}',
          snippet: 'Жалоб: ${cluster.complaintsCount}. Нажми для Street View',
          onTap: () => _openStreetView(cluster.lat, cluster.lon),
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      );
    }).toSet();

    setState(() => _markers = markers);
  }

  Future<void> _openStreetView(double lat, double lon) async {
    final url = 'https://www.google.com/maps/@?api=1&map_action=pano&viewpoint=$lat,$lon';
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Не удалось открыть Street View')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Карта жалоб Нижневартовска'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: const CameraPosition(
                target: LatLng(60.9444, 76.5781),
                zoom: 12,
              ),
              markers: _markers,
            ),
    );
  }
}
