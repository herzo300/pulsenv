import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

class AbTestService {
  AbTestService._();

  static final AbTestService instance = AbTestService._();
  static const String reportCtaExperiment = 'report_cta_v1';

  Future<String> variant(String experiment) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'ab_variant_$experiment';
    final existing = prefs.getString(key);
    if (existing == 'control' || existing == 'action_label') {
      return existing!;
    }
    final assigned = math.Random().nextBool() ? 'control' : 'action_label';
    await prefs.setString(key, assigned);
    return assigned;
  }
}
