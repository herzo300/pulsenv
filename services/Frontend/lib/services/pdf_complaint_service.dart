import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../map/map_config.dart';

class PdfComplaintService {
  PdfComplaintService._();
  static final PdfComplaintService instance = PdfComplaintService._();

  static const String _subKey = 'user_house_subscriptions';

  /// Generates an official PDF complaint document for city administration/utilities.
  Future<void> generateAndPrintOfficialPdf({
    required BuildContext context,
    required dynamic reportId,
    required String title,
    required String category,
    required String address,
    required String description,
    String? imageUrl,
  }) async {
    final pdf = pw.Document();

    final dateStr = '${DateTime.now().day.toString().padLeft(2, '0')}.${DateTime.now().month.toString().padLeft(2, '0')}.${DateTime.now().year}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Header(
                  level: 0,
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'ОФИЦИАЛЬНОЕ ОБРАЩЕНИЕ В АДМИНИСТРАЦИЮ / ЖКХ',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        dateStr,
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Text(
                  'Регистрационный номер: №CP-${reportId.toString().padLeft(6, '0')}',
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 8),
                pw.Text('Категория проблемы: $category', style: const pw.TextStyle(fontSize: 11)),
                pw.SizedBox(height: 4),
                pw.Text('Адрес объекта: $address', style: const pw.TextStyle(fontSize: 11)),
                pw.SizedBox(height: 16),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'Суть обращения:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        description.isNotEmpty ? description : title,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 24),
                pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.blue, width: 1.5),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text(
                    'Документ сформирован автоматически в системе муниципального мониторинга «Пульс города».',
                    style: pw.TextStyle(fontSize: 9, color: PdfColors.blue800),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Официальное_обращение_CP-$reportId.pdf',
    );
  }

  /// Get subscribed houses list
  Future<List<String>> getSubscribedHouses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_subKey) ?? [];
    } catch (_) {
      return [];
    }
  }

  /// Toggle subscription status for a house address
  Future<bool> toggleHouseSubscription(String address) async {
    final clean = address.trim();
    if (clean.isEmpty) return false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_subKey) ?? [];
      bool isSubscribed;
      if (list.contains(clean)) {
        list.remove(clean);
        isSubscribed = false;
      } else {
        list.add(clean);
        isSubscribed = true;
      }
      await prefs.setStringList(_subKey, list);

      // Notify backend as well
      try {
        final uri = Uri.parse('${MapConfig.backendApiBaseUrl}/house-subscribe');
        await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'address': clean}),
        );
      } catch (_) {}

      return isSubscribed;
    } catch (_) {
      return false;
    }
  }
}
