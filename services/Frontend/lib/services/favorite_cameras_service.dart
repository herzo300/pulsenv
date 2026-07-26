import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoriteCamerasService extends ChangeNotifier {
  static const String _key = 'favorite_cameras';
  static const int _maxLimit = 10;

  static final FavoriteCamerasService _instance = FavoriteCamerasService._internal();

  factory FavoriteCamerasService() => _instance;

  FavoriteCamerasService._internal();

  /// Gets the list of favorite cameras.
  Future<List<Map<String, String>>> getFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_key);
    if (data == null) return [];

    return data.map((e) {
      final decoded = jsonDecode(e) as Map<String, dynamic>;
      return {
        'title': decoded['title']?.toString() ?? '',
        'url': decoded['url']?.toString() ?? '',
      };
    }).toList();
  }

  /// Adds a camera to favorites. Returns false if limit is reached or already exists.
  Future<bool> addFavorite(String title, String url) async {
    final list = await getFavorites();
    if (list.any((c) => c['url'] == url)) return false; // Already added
    if (list.length >= _maxLimit) return false; // Limit reached

    list.add({'title': title, 'url': url});
    await _saveList(list);
    notifyListeners();
    return true;
  }

  /// Removes a camera from favorites.
  Future<void> removeFavorite(String url) async {
    final list = await getFavorites();
    list.removeWhere((c) => c['url'] == url);
    await _saveList(list);
    notifyListeners();
  }

  /// Checks if a camera is in favorites.
  Future<bool> isFavorite(String url) async {
    final list = await getFavorites();
    return list.any((c) => c['url'] == url);
  }

  Future<void> _saveList(List<Map<String, String>> list) async {
    final prefs = await SharedPreferences.getInstance();
    final encodedList = list.map((e) => jsonEncode(e)).toList();
    await prefs.setStringList(_key, encodedList);
  }
}
