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
    final robotoFont = await PdfGoogleFonts.robotoRegular();
    final robotoBoldFont = await PdfGoogleFonts.robotoBold();

    final pdf = pw.Document();

    final dateStr = '${DateTime.now().day.toString().padLeft(2, '0')}.${DateTime.now().month.toString().padLeft(2, '0')}.${DateTime.now().year}';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(
          base: robotoFont,
          bold: robotoBoldFont,
        ),
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
                // ─── Шапка официального обращения (ФЗ-59) ───
                pw.Text(
                  'В Администрацию города Нижневартовска',
                  style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  '(копия: Управляющая организация по адресу объекта)',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  'от жителя города Нижневартовска',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  'пользователя системы «Пульс города» (ID CP-${reportId.toString().padLeft(6, '0')})',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 14),

                // ─── Заголовок ───
                pw.Center(
                  child: pw.Text(
                    'ОБРАЩЕНИЕ',
                    style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
                  ),
                ),
                pw.Center(
                  child: pw.Text(
                    '(в порядке Федерального закона от 02.05.2006 № 59-ФЗ «О порядке рассмотрения обращений граждан РФ»)',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ),
                pw.SizedBox(height: 12),

                // ─── Суть обращения ───
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
                        '1. Суть нарушения:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'По адресу: $address выявлена проблема категории «$category».',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        description.isNotEmpty ? description : title,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        '2. Правовое обоснование:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        'В соответствии со ст. 8 Федерального закона № 59-ФЗ обращение подлежит '
                        'обязательной регистрации в течение 3 дней и рассмотрению в течение 30 дней '
                        'со дня регистрации. Неисполнение сроков влечёт ответственность по ст. 5.59 КоАП РФ.',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.SizedBox(height: 10),
                      pw.Text(
                        '3. Прошу:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Text(
                        '1) провести обследование указанного объекта;'
                        '2) устранить выявленное нарушение в установленные законом сроки;'
                        '3) направить мотивированный письменный ответ о принятых мерах в мой адрес '
                        'в течение 30 дней с момента регистрации настоящего обращения.',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 12),

                // ─── Приложения ───
                pw.Text(
                  'Приложение: фотофиксация из системы «Пульс города» (при наличии).',
                  style: const pw.TextStyle(fontSize: 9),
                ),
                pw.SizedBox(height: 20),

                // ─── Подпись ───
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Дата: $dateStr', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(
                      'Подпись: ______________',
                      style: const pw.TextStyle(fontSize: 10),
                    ),
                  ],
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
