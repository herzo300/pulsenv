import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class DeepLinkService {
  DeepLinkService._();
  
  static final _referralStreamController = StreamController<String>.broadcast();
  static Stream<String> get referralStream => _referralStreamController.stream;

  /// Process referral codes and award local bonus points
  static Future<bool> handleReferral(String refCode) async {
    final cleanRef = refCode.trim();
    if (cleanRef.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    final String key = 'processed_ref_$cleanRef';
    
    // Prevent double processing the same referral link
    if (prefs.getBool(key) ?? false) {
      return false;
    }

    // Save that we processed it
    await prefs.setBool(key, true);

    // Save referrer name/code for history
    final List<String> history = prefs.getStringList('referral_history') ?? [];
    if (!history.contains(cleanRef)) {
      history.add(cleanRef);
      await prefs.setStringList('referral_history', history);
    }

    // Award +500 local points
    final currentPoints = prefs.getInt('local_custom_points') ?? 0;
    await prefs.setInt('local_custom_points', currentPoints + 500);

    // Broadcast referral event for overlay popup
    _referralStreamController.add(cleanRef);
    return true;
  }

  /// Get total custom points (base points + referral bonuses)
  static Future<int> getLocalCustomPoints() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('local_custom_points') ?? 0;
  }

  /// Get referral history (who invited the user)
  static Future<List<String>> getReferralHistory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList('referral_history') ?? [];
  }
}
