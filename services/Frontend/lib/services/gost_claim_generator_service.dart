import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Сервис генерации официальных обращений и заявлений по стандарту ГОСТ Р 7.0.97-2016
/// Для отправки в Управляющие компании, Администрацию г. Нижневартовска, Жилстройнадзор Югры и ЕДДС.
class GostClaimGeneratorService {
  static final GostClaimGeneratorService _instance = GostClaimGeneratorService._internal();
  factory GostClaimGeneratorService() => _instance;
  GostClaimGeneratorService._internal();

  /// Генерация полного официального юридического текста обращения
  String generateOfficialDocument({
    required String residentName,
    required String residentPhone,
    required String address,
    required String apartment,
    required String recipientOrganization,
    required String category,
    required String problemDescription,
    String? preferredResponseEmail,
  }) {
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}.${now.month.toString().padLeft(2, '0')}.${now.year}';
    final regNumber = 'NV-${now.year}-${now.millisecondsSinceEpoch.toString().substring(7)}';

    final lawReference = _getLawReference(category);
    final deadlineDays = _getNormativeDeadlineDays(category);

    return '''
ИСХ. № $regNumber от $dateStr г.

В: $recipientOrganization
Кому: Руководителю организации / Диспетчерская служба

ОТ ЗАЯВИТЕЛЯ:
ФИО: ${residentName.isNotEmpty ? residentName : "Житель г. Нижневартовска"}
Адрес: $address${apartment.isNotEmpty ? ", кв. $apartment" : ""}
Телефон для связи: ${residentPhone.isNotEmpty ? residentPhone : "Не указан"}
${preferredResponseEmail != null && preferredResponseEmail.isNotEmpty ? "E-mail: $preferredResponseEmail" : ""}


ПРЕТЕНЗИЯ / ОФИЦИАЛЬНОЕ ЗАЯВЛЕНИЕ
о ненадлежащем оказании коммунальных услуг и содержании общего имущества

Настоящим уведомляю, что по адресу: $address зафиксирован факт нарушения правил содержания общего имущества и предоставления коммунальных услуг по категории «$category».

СУТЬ ОБРАЩЕНИЯ:
$problemDescription

ПРАВОВОЕ ОБОСНОВАНИЕ:
$lawReference
В соответствии с Постановлением Правительства РФ № 354 «О предоставлении коммунальных услуг собственникам и пользователям помещений в многоквартирных домах и жилых домов» и Постановлением Правительства РФ № 290, исполнитель обязан предоставлять услуги надлежащего качества и незамедлительно устранять выявленные неисправности.

ТРЕБОВАНИЯ:
1. Зарегистрировать настоящее обращение в установленном законом порядке под присвоенным входящим номером.
2. Провести комиссионное обследование и устранить выявленные нарушения в нормативный срок (не более $deadlineDays рабочих дней).
3. При наличии оснований произвести перерасчет платы за ненадлежащее качество коммунальных услуг.
4. Направить письменный ответ о принятых мерах заявителю.

В случае непринятия мер настоящее заявление будет направлено в Службу жилищного и строительного надзора Ханты-Мансийского автономного округа – Югры (Жилстройнадзор Югры) и Прокуратуру г. Нижневартовска.

Дата: $dateStr г.
Заявитель: _________________ / ${residentName.isNotEmpty ? residentName : "Житель"} /
Сформировано через ИИ-диспетчер платформы «Пульс города»
''';
  }

  String _getLawReference(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('вод') || cat.contains('гвс') || cat.contains('хвс')) {
      return 'Нарушение требований СанПиН 1.2.3685-21 и Правил предоставления коммунальных услуг № 354 в части бесперебойного и качественного водоснабжения.';
    } else if (cat.contains('тепло') || cat.contains('отоплен')) {
      return 'Нарушение ГОСТ Р 51617-2014 и СанПиН по температурному режиму в жилых помещениях (не ниже +20°C в жилых комнатах для районов Крайнего Севера и приравненных местностей).';
    } else if (cat.contains('снег') || cat.contains('дор') || cat.contains('лед')) {
      return 'Нарушение требований ГОСТ Р 50597-2017 «Дороги автомобильные и улицы. Требования к эксплуатационному состоянию» и Правил благоустройства территории г. Нижневартовска.';
    } else if (cat.contains('мусор') || cat.contains('тко')) {
      return 'Нарушение СанПиН 2.1.3684-21 и Федерального закона № 89-ФЗ «Об отходах производства и потребления» по периодичности вывоза ТКО.';
    } else {
      return 'Нарушение Правил и норм технической эксплуатации жилищного фонда, утвержденных Постановлением Госстроя РФ от 27.09.2003 № 170.';
    }
  }

  int _getNormativeDeadlineDays(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('авар') || cat.contains('прорыв') || cat.contains('течь')) {
      return 1; // 1 день при авариях
    } else if (cat.contains('снег') || cat.contains('лед') || cat.contains('гололед')) {
      return 2; // 2 дня на очистку
    } else if (cat.contains('мусор')) {
      return 1;
    }
    return 5; // 5 дней для стандартных обращений
  }

  /// Генерация и сохранение коллективного обращения (10+ подписей) в нормальный PDF с ГОСТ-оформлением
  Future<String> generatePetitionPdf({
    required String title,
    required String address,
    required String category,
    required String description,
    required int supportersCount,
  }) async {
    final docText = generateOfficialDocument(
      residentName: "Коллектив жителей ($supportersCount подписей)",
      residentPhone: "Реестр зарегистрированных подписей Пульс Города",
      address: address,
      apartment: "МКД",
      recipientOrganization: "Прокуратура ХМАО-Югры и Жилстройнадзор Югры",
      category: category,
      problemDescription: "$title. $description\n\nПодписано коллективно: $supportersCount жителями дома.",
    );

    try {
      final pdf = pw.Document();
      final font = await PdfGoogleFonts.robotoRegular();
      final fontBold = await PdfGoogleFonts.robotoBold();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: font, bold: fontBold),
          build: (pw.Context context) {
            return pw.Padding(
              padding: const pw.EdgeInsets.all(36),
              child: pw.Text(
                docText,
                style: const pw.TextStyle(fontSize: 11),
              ),
            );
          },
        ),
      );

      final dir = await getApplicationDocumentsDirectory();
      final filename = 'collective_petition_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(await pdf.save());
      return file.path;
    } catch (e) {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/collective_petition.txt');
      await file.writeAsString(docText);
      return file.path;
    }
  }
}
