import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapViewModel extends ChangeNotifier {
  final MapController mapController = MapController();
  
  LatLng currentCenter = const LatLng(60.9385, 76.5589); // Nizhnevartovsk default
  double currentZoom = 13.5;
  bool isSatellite = false;
  bool isNightMode = true;
  String selectedCategory = 'all';
  List<dynamic> markers = [];
  bool isLoading = false;

  void toggleSatellite() {
    isSatellite = !isSatellite;
    notifyListeners();
  }

  void toggleNightMode() {
    isNightMode = !isNightMode;
    notifyListeners();
  }

  void setCategory(String category) {
    selectedCategory = category;
    notifyListeners();
  }

  void updatePosition(LatLng center, double zoom) {
    currentCenter = center;
    currentZoom = zoom;
    notifyListeners();
  }
}
