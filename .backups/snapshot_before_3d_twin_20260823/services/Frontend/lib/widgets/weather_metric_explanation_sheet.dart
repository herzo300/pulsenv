// lib/widgets/weather_metric_explanation_sheet.dart
//
// Интерактивное всплывающее окно с детальными объяснениями,
// точными нормами и отклонениями от нормы для всех параметров погоды и экологии.

import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum MetricStatus {
  normal,
  aboveNormal,
  belowNormal,
  caution,
  ideal,
}

class WeatherMetricInfo {
  final String key;
  final String title;
  final String category;
  final IconData icon;
  final Color accentColor;
  final String unit;
  final String normRange;
  final String whatIsIt;
  final String whenBelow;
  final String whenAbove;
  final String recommendations;
  final MetricStatus Function(num? value) statusResolver;
  final String Function(num? value) statusLabelResolver;

  const WeatherMetricInfo({
    required this.key,
    required this.title,
    required this.category,
    required this.icon,
    required this.accentColor,
    required this.unit,
    required this.normRange,
    required this.whatIsIt,
    required this.whenBelow,
    required this.whenAbove,
    required this.recommendations,
    required this.statusResolver,
    required this.statusLabelResolver,
  });
}

class WeatherMetricsCatalog {
  static final Map<String, WeatherMetricInfo> metrics = {
    'temperature': WeatherMetricInfo(
      key: 'temperature',
      title: 'Температура воздуха',
      category: 'Метеорология',
      icon: Icons.thermostat_rounded,
      accentColor: const Color(0xFF00E5FF),
      unit: '°C',
      normRange: 'Комфорт для человека: от +18°C до +24°C. Климатическая норма Нижневартовска летом: +16...+22°C, зимой: -18...-28°C.',
      whatIsIt: 'Степень нагретости атмосферного воздуха, измеряемая в тени на высоте 2 метров от поверхности земли.',
      whenBelow: 'Ниже нормы: Переохлаждение организма, спазм сосудов, рост риска ОРВИ и обморожений. В школах ХМАО вводятся актированные дни (от -24°C до -36°C).',
      whenAbove: 'Выше нормы (жара выше +27°C): Нагрузка на сердечно-сосудистую систему, тепловой стресс, обезвоживание, сонливость.',
      recommendations: 'Одевайтесь многослойно по сезону («принцип луковицы»). Зимой защищайте лицо от ветра, летом пейте чистую воду и носите головные уборы.',
      statusResolver: (val) {
        if (val == null) return MetricStatus.normal;
        if (val < -25 || val > 30) return MetricStatus.caution;
        if (val >= 15 && val <= 25) return MetricStatus.ideal;
        return MetricStatus.normal;
      },
      statusLabelResolver: (val) {
        if (val == null) return 'В норме';
        if (val < -25) return 'Сильный мороз';
        if (val < 0) return 'Умеренный мороз';
        if (val > 28) return 'Жаркая погода';
        if (val >= 16 && val <= 24) return 'Идеальный комфорт';
        return 'Сезонная норма';
      },
    ),

    'feels_like': WeatherMetricInfo(
      key: 'feels_like',
      title: 'Ощущаемая температура',
      category: 'Биометеорология',
      icon: Icons.person_outline_rounded,
      accentColor: const Color(0xFF38BDF8),
      unit: '°C',
      normRange: 'Близка к фактической температуре при слабом ветре (до 3 м/с) и умеренной влажности (40-60%).',
      whatIsIt: 'Субъективное тепловое ощущение тела человека, рассчитанное по формуле ветро-холодового индекса (Wind Chill) и индекса жары (Heat Index) с учетом влажности и ветра.',
      whenBelow: 'Ниже фактической: Сильный северный/западный ветер ускоряет отдачу тепла кожей в 2-4 раза. При -15°C и ветре 10 м/с ощущается как -26°C.',
      whenAbove: 'Выше фактической: Высокая влажность затрудняет испарение пота, создавая эффект парника и духоты.',
      recommendations: 'При выходе на улицу всегда ориентируйтесь именно на «Ощущается», а не на сухой термометр. Надевайте ветрозащитную куртку (мембрана/ветровка).',
      statusResolver: (val) => MetricStatus.normal,
      statusLabelResolver: (val) => 'Оценка теплоотдачи тела',
    ),

    'humidity': WeatherMetricInfo(
      key: 'humidity',
      title: 'Относительная влажность',
      category: 'Атмосфера',
      icon: Icons.water_drop_rounded,
      accentColor: const Color(0xFF00E5FF),
      unit: '%',
      normRange: 'Норма комфорта для человека: 40% – 60%. Допустимо на открытом воздухе: 30% – 75%.',
      whatIsIt: 'Отношение текущего количества водяного пара в воздухе к максимально возможному при данной температуре.',
      whenBelow: 'Ниже нормы (< 30%): Сухость слизистых оболочек носа и глаз, першение в горле, снижение барьерной защиты от вирусов, стянутость кожи.',
      whenAbove: 'Выше нормы (> 80%): Ощущение сырости, духота в теплую погоду или пронизывающий холод зимой, затруднение дыхания при астме.',
      recommendations: 'Зимой в квартирах используйте увлажнители воздуха. При высокой уличной влажности чаще проветривайте помещения.',
      statusResolver: (val) {
        if (val == null) return MetricStatus.normal;
        if (val < 30) return MetricStatus.belowNormal;
        if (val > 85) return MetricStatus.aboveNormal;
        if (val >= 40 && val <= 65) return MetricStatus.ideal;
        return MetricStatus.normal;
      },
      statusLabelResolver: (val) {
        if (val == null) return 'В норме';
        if (val < 30) return 'Сухой воздух';
        if (val > 85) return 'Высокая влажность';
        if (val >= 40 && val <= 65) return 'Оптимально (Норма)';
        return 'Умеренная влажность';
      },
    ),

    'wind': WeatherMetricInfo(
      key: 'wind',
      title: 'Скорость и порывы ветра',
      category: 'Атмосферная динамика',
      icon: Icons.air_rounded,
      accentColor: const Color(0xFFF59E0B),
      unit: 'м/с',
      normRange: 'Штиль и легкий бриз: 0.5 – 5.0 м/с (комфортно). Умеренный: 5.1 – 8.0 м/с. Сильный: 8.1 – 14.0 м/с.',
      whatIsIt: 'Горизонтальное движение воздушных масс из областей высокого давления в области низкого давления.',
      whenBelow: 'Штиль (< 1.5 м/с): Благоприятно для прогулок, однако зимой в безветрие в низинах города могут скапливаться выхлопные газы.',
      whenAbove: 'Штормовой ветер (> 15 м/с): Опасность падения веток, обрыва проводов, раскачивания баннеров. Сильное выдувание тепла из зданий.',
      recommendations: 'При порывах свыше 12 м/с не паркуйте автомобили под старыми деревьями и рекламными щитами. В ветреную погоду берегите уши и шею.',
      statusResolver: (val) {
        if (val == null) return MetricStatus.normal;
        if (val > 14) return MetricStatus.caution;
        if (val > 8) return MetricStatus.aboveNormal;
        return MetricStatus.normal;
      },
      statusLabelResolver: (val) {
        if (val == null) return 'Норма';
        if (val > 15) return 'Штормовые порывы';
        if (val > 8) return 'Повышенный ветер';
        if (val <= 4) return 'Слабый комфортный';
        return 'Умеренный ветер';
      },
    ),

    'wind_gusts': WeatherMetricInfo(
      key: 'wind_gusts',
      title: 'Порывы ветра',
      category: 'Атмосферная динамика',
      icon: Icons.air_outlined,
      accentColor: const Color(0xFFEC4899),
      unit: 'м/с',
      normRange: 'Безопасные порывы: до 8.0 м/с. Требуют осторожности: 9.0 – 14.0 м/с. Штормовые: 15.0+ м/с.',
      whatIsIt: 'Кратковременные (в течение нескольких секунд) резкие усиления скорости ветра, вызванные турбулентностью атмосферных слоев.',
      whenBelow: 'Ровный мягкий поток воздуха без резких толчков.',
      whenAbove: 'Порывы свыше 12 м/с могут вырывать из рук зонты, захлопывать двери и создавать боковой снос автомобилей на трассах.',
      recommendations: 'Крепко держите руль при выезде из лесополосы на открытые участки трассы. Закрывайте балконные окна при штормовом предупреждении.',
      statusResolver: (val) => (val != null && val > 12) ? MetricStatus.caution : MetricStatus.normal,
      statusLabelResolver: (val) => (val != null && val > 12) ? 'Сильные порывы' : 'В норме',
    ),

    'pressure': WeatherMetricInfo(
      key: 'pressure',
      title: 'Атмосферное давление',
      category: 'Барометрия',
      icon: Icons.compress_rounded,
      accentColor: const Color(0xFF10B981),
      unit: 'мм рт. ст.',
      normRange: 'Норма для Нижневартовска (высота ~45 м над уровнем моря): 755 – 762 мм рт. ст. (стандарт 758 мм).',
      whatIsIt: 'Сила, с которой столб атмосферного воздуха давит на земную поверхность и все находящиеся на ней тела.',
      whenBelow: 'Циклон (ниже 748 мм): Снижение артериального давления у гипотоников, сонливость, головокружение, нехватка кислорода.',
      whenAbove: 'Антициклон (выше 768 мм): Повышение артериального давления у гипертоников, головные боли, напряжение в сосудах, приступ мигрени.',
      recommendations: 'При резких перепадах давления (>5 мм за сутки) метеочувствительным людям стоит ограничить тяжелые физические нагрузки, высыпаться и контролировать давление.',
      statusResolver: (val) {
        if (val == null) return MetricStatus.normal;
        if (val < 748) return MetricStatus.belowNormal;
        if (val > 768) return MetricStatus.aboveNormal;
        return MetricStatus.normal;
      },
      statusLabelResolver: (val) {
        if (val == null) return 'Норма 758 мм';
        if (val < 748) return 'Низкое (Циклон)';
        if (val > 768) return 'Высокое (Антициклон)';
        return 'Идеальная норма (758 мм)';
      },
    ),

    'uv_index': WeatherMetricInfo(
      key: 'uv_index',
      title: 'Ультрафиолетовый индекс (УФИ)',
      category: 'Солнечная радиация',
      icon: Icons.wb_sunny_rounded,
      accentColor: const Color(0xFFFFB300),
      unit: 'баллов',
      normRange: 'Безопасный уровень: 0 – 2 балла. Умеренный: 3 – 5 баллов. Высокий: 6 – 7 баллов. Экстремальный: 8+ баллов.',
      whatIsIt: 'Международный показатель уровня ультрафиолетового излучения Солнца, вызывающего загар, синтез витамина D или солнечный ожог.',
      whenBelow: 'Низкий (0-2): Солнце безопасно, защита не требуется даже для младенцев. Зимой в ХМАО индекс часто равен 0-1.',
      whenAbove: 'Высокий (6+): Опасность ожога сетчатки глаз и кожи уже через 20-30 минут пребывания под прямыми лучами без защиты.',
      recommendations: 'При УФ-индексе от 3 баллов надевайте солнцезащитные очки с UV-фильтром 400 и наносите крем с фактором SPF 15-30+ в полуденные часы (12:00-16:00).',
      statusResolver: (val) {
        if (val == null) return MetricStatus.normal;
        if (val >= 6) return MetricStatus.caution;
        if (val >= 3) return MetricStatus.aboveNormal;
        return MetricStatus.normal;
      },
      statusLabelResolver: (val) {
        if (val == null) return '0-2 (Низкий)';
        if (val >= 8) return 'Опасный УФ (8+)';
        if (val >= 6) return 'Высокий УФ (6-7)';
        if (val >= 3) return 'Умеренный (3-5)';
        return 'Безопасный (0-2)';
      },
    ),

    'visibility': WeatherMetricInfo(
      key: 'visibility',
      title: 'Метеорологическая видимость',
      category: 'Прозрачность атмосферы',
      icon: Icons.visibility_rounded,
      accentColor: const Color(0xFF818CF8),
      unit: 'км',
      normRange: 'Идеальная видимость: 10.0+ км. Удовлетворительная: 4.0 – 9.9 км. Ограниченная: менее 2.0 км.',
      whatIsIt: 'Максимальное расстояние, на котором в светлое время суток человеческий глаз отчетливо различает силуэт темного объекта на фоне неба.',
      whenBelow: 'Сниженная видимость (< 1.0 км): Туман, сильный снегопад, метель или дымка. Резко возрастает тормозной путь и опасность ДТП.',
      whenAbove: 'Отличная (10+ км): Чистейший таежный сибирский воздух без взвесей и пыли.',
      recommendations: 'Водителям при видимости ниже 2 км включать противотуманные фары, соблюдать увеличенную дистанцию и снижать скорость.',
      statusResolver: (val) {
        if (val == null) return MetricStatus.normal;
        if (val < 2.0) return MetricStatus.caution;
        if (val < 5.0) return MetricStatus.belowNormal;
        return MetricStatus.ideal;
      },
      statusLabelResolver: (val) {
        if (val == null) return '10 км (Чисто)';
        if (val < 1.0) return 'Густой туман (<1 км)';
        if (val < 4.0) return 'Ограниченная';
        return 'Отличная видимость (10 км)';
      },
    ),

    'aqi': WeatherMetricInfo(
      key: 'aqi',
      title: 'Индекс качества воздуха (AQI)',
      category: 'Экология и Воздух',
      icon: Icons.eco_rounded,
      accentColor: const Color(0xFF00E676),
      unit: 'AQI',
      normRange: 'Европейский индекс: 0 – 20 (Отличное), 21 – 40 (Хорошее). Допустимо: до 50. Загрязненный воздух: 51+.',
      whatIsIt: 'Комплексный интегральный индекс чистоты атмосферного воздуха, объединяющий замеры PM2.5, PM10, диоксида азота, озона, угарного газа и серы.',
      whenBelow: 'Отлично (0-20): Воздух идеально чист, полезен для пробежек, прогулок с детьми и глубокого дыхания.',
      whenAbove: 'Неблагополучно (50+): Скопление пыли, гари или промышленных газов. Чувствительным людям может быть тяжело дышать.',
      recommendations: 'В Нижневартовске качество воздуха большую часть года находится на уровне «Отличное» (AQI 12-25) благодаря окружающим хвойным лесам и пойме Оби.',
      statusResolver: (val) {
        if (val == null) return MetricStatus.ideal;
        if (val > 60) return MetricStatus.caution;
        if (val > 35) return MetricStatus.normal;
        return MetricStatus.ideal;
      },
      statusLabelResolver: (val) {
        if (val == null) return 'Отличное (AQI 18)';
        if (val > 60) return 'Повышенное загрязнение';
        if (val > 35) return 'Умеренное';
        return 'Идеальное таежное качество';
      },
    ),

    'pm25': WeatherMetricInfo(
      key: 'pm25',
      title: 'Микрочастицы пыли PM2.5',
      category: 'Экология и Воздух',
      icon: Icons.blur_on_rounded,
      accentColor: const Color(0xFF2DD4BF),
      unit: 'мкг/м³',
      normRange: 'Норма ВОЗ (среднесуточная): до 15.0 мкг/м³. Идеальный чистый воздух: до 10.0 мкг/м³.',
      whatIsIt: 'Тонкодисперсные частицы размером менее 2.5 микрометра (пыль, сажа, пыльца, минералы), способные проникать глубоко в легкие.',
      whenBelow: 'Низкая концентрация (< 8 мкг/м³): Воздух кристально прозрачный, легкие работают без балластной нагрузки.',
      whenAbove: 'Превышение (> 25 мкг/м³): Раздражение бронхов, обострение аллергий, кашель, снижение концентрации внимания.',
      recommendations: 'Поддерживайте чистоту в квартире влажной уборкой. При превышении концентрации PM2.5 не открывайте окна со стороны оживленных магистралей.',
      statusResolver: (val) {
        if (val == null) return MetricStatus.ideal;
        if (val > 25) return MetricStatus.caution;
        if (val > 15) return MetricStatus.aboveNormal;
        return MetricStatus.ideal;
      },
      statusLabelResolver: (val) {
        if (val == null) return 'В норме (до 10 мкг)';
        if (val > 25) return 'Выше нормы ВОЗ';
        if (val > 15) return 'Умеренно';
        return 'Идеально чисто (Норма)';
      },
    ),

    'pm10': WeatherMetricInfo(
      key: 'pm10',
      title: 'Взвешенные частицы PM10',
      category: 'Экология и Воздух',
      icon: Icons.grain_rounded,
      accentColor: const Color(0xFF34D399),
      unit: 'мкг/м³',
      normRange: 'Норма ВОЗ: до 45.0 мкг/м³. Идеальный воздух: до 20.0 мкг/м³.',
      whatIsIt: 'Крупная фракция взвешенных частиц (песок, дорожная пыль, фрагменты почвы, споры растений).',
      whenBelow: 'Чисто: Нет пылевого налета на автомобилях и окнах, легкое дыхание.',
      whenAbove: 'Запыленность: Скрип песка на зубах, запыление глаз и носоглотки в ветреную сухую погоду.',
      recommendations: 'При сильном ветре в межсезонье надевайте солнцезащитные очки для защиты слизистой глаз от песчинок.',
      statusResolver: (val) => (val != null && val > 45) ? MetricStatus.aboveNormal : MetricStatus.ideal,
      statusLabelResolver: (val) => (val != null && val > 45) ? 'Пылевой фон' : 'Норма (Чисто)',
    ),

    'no2': WeatherMetricInfo(
      key: 'no2',
      title: 'Диоксид азота (NO₂)',
      category: 'Газовый состав воздуха',
      icon: Icons.cloud_circle_rounded,
      accentColor: const Color(0xFF60A5FA),
      unit: 'мкг/м³',
      normRange: 'ПДК среднесуточная: до 40.0 мкг/м³. Фоновое значение в Нижневартовске: 8 – 16 мкг/м³.',
      whatIsIt: 'Газ, образующийся при сгорании автомобильного топлива и работе ТЭЦ / котельных.',
      whenBelow: 'Безопасно: Полное отсутствие запаха гари и раздражения гортани.',
      whenAbove: 'Превышение: Кислый привкус во рту, обострение астматических реакций.',
      recommendations: 'Не стойте длительное время возле заведенных двигателей грузовиков и автобусов на остановках.',
      statusResolver: (val) => (val != null && val > 40) ? MetricStatus.caution : MetricStatus.ideal,
      statusLabelResolver: (val) => 'В норме (Безопасно)',
    ),

    'o3': WeatherMetricInfo(
      key: 'o3',
      title: 'Приземный озон (O₃)',
      category: 'Газовый состав воздуха',
      icon: Icons.wb_iridescent_rounded,
      accentColor: const Color(0xFFA78BFA),
      unit: 'мкг/м³',
      normRange: 'Норма: до 100.0 мкг/м³. Фоновый уровень в хвойных лесах Югры: 30 – 60 мкг/м³.',
      whatIsIt: 'Газ с характерным запахом свежести после грозы, образующийся при фотохимических реакциях на солнце и ионизации молниями.',
      whenBelow: 'Нормально для пасмурной погоды и зимы.',
      whenAbove: 'При экстремальной жаре выше 120 мкг/м³ может вызывать сухость в горле.',
      recommendations: 'Приятная свежесть после грозы обусловлена умеренным озоном — идеальное время для прогулок.',
      statusResolver: (val) => MetricStatus.ideal,
      statusLabelResolver: (val) => 'Свежий воздух (Норма)',
    ),

    'so2': WeatherMetricInfo(
      key: 'so2',
      title: 'Диоксид серы (SO₂)',
      category: 'Газовый состав воздуха',
      icon: Icons.blur_linear_rounded,
      accentColor: const Color(0xFFFBBF24),
      unit: 'мкг/м³',
      normRange: 'Норма: до 50.0 мкг/м³. В Нижневартовске: 3 – 8 мкг/м³ (очень чисто).',
      whatIsIt: 'Сернистый ангидрид, образующийся при сжигании угля и тяжелых нефтепродуктов.',
      whenBelow: 'Абсолютно безопасная экологическая обстановка.',
      whenAbove: 'Резкий запах, раздражение глаз и дыхательных путей.',
      recommendations: 'В Югре используется природный газ, поэтому содержание диоксида серы в воздухе минимально.',
      statusResolver: (val) => MetricStatus.ideal,
      statusLabelResolver: (val) => 'В норме (Идеально)',
    ),

    'co': WeatherMetricInfo(
      key: 'co',
      title: 'Оксид углерода (CO, Угарный газ)',
      category: 'Газовый состав воздуха',
      icon: Icons.filter_drama_rounded,
      accentColor: const Color(0xFFF87171),
      unit: 'мкг/м³',
      normRange: 'Норма на открытом воздухе: до 4000 мкг/м³ (4 мг/м³). Фоновый уровень: 180 – 350 мкг/м³.',
      whatIsIt: 'Газ без цвета и запаха, продукт неполного сгорания углеводородов (выхлопные газы, печи, тлеющие торфяники).',
      whenBelow: 'Отличная вентилируемость городского пространства.',
      whenAbove: 'Головная боль, слабость, кислородное голодание тканей.',
      recommendations: 'При прогреве автомобиля на парковке переключайте забор воздуха на рециркуляцию.',
      statusResolver: (val) => MetricStatus.ideal,
      statusLabelResolver: (val) => 'В норме (Безопасно)',
    ),

    'schumann': WeatherMetricInfo(
      key: 'schumann',
      title: 'Резонанс Шумана',
      category: 'Электромагнитное поле Земли',
      icon: Icons.graphic_eq_rounded,
      accentColor: const Color(0xFFA855F7),
      unit: 'Гц',
      normRange: 'Фундаментальная гармоника: 7.83 Гц. Вторичные моды: 14.3 Гц, 20.8 Гц, 27.3 Гц.',
      whatIsIt: 'Стоячие электромагнитные волны сверхнизкой частоты, циркулирующие в волноводе «поверхность Земли — ионосфера». Их частота совпадает с альфа-ритмами мозга человека в состоянии покоя.',
      whenBelow: 'Снижение частоты бывает редко, субъективно ощущается как легкая вялость.',
      whenAbove: 'Всплески амплитуды (Power Spike) во время мощных глобальных гроз и вспышек на Солнце: повышение мозговой активности, творческий подъем или эмоциональная возбудимость.',
      recommendations: 'При всплесках мощности резонанса полезны практики релаксации, прогулки на природе, дыхательные упражнения.',
      statusResolver: (val) => MetricStatus.ideal,
      statusLabelResolver: (val) => 'Базовая частота 7.83 Гц (Норма)',
    ),

    'kp_index': WeatherMetricInfo(
      key: 'kp_index',
      title: 'Геомагнитная активность (Kp-индекс)',
      category: 'Космическая погода',
      icon: Icons.shield_outlined,
      accentColor: const Color(0xFFEC4899),
      unit: 'Kp',
      normRange: 'Спокойная магнитосфера: 0 – 2 балла. Неустойчивая: 3 – 4 балла. Магнитная буря (G1-G5): 5+ баллов.',
      whatIsIt: 'Планетарный индекс возмущения магнитного поля Земли под воздействием порывов солнечного ветра и корональных выбросов массы.',
      whenBelow: '0-2 балла: Магнитосфера абсолютно спокойна, метеопатические риски минимальны.',
      whenAbove: 'Буря 5+ баллов: У метеочувствительных людей возможны головные боли, скачки артериального давления, быстрая утомляемость, нарушения сна. В северных широтах (Нижневартовск) видно полярное сияние!',
      recommendations: 'В дни сильных магнитных бурь (Kp 5+) пейте травяной чай с мятой, снизьте употребление кофеина, не перегружайте нервную систему и избегайте стресса.',
      statusResolver: (val) {
        if (val == null) return MetricStatus.normal;
        if (val >= 5) return MetricStatus.caution;
        if (val >= 4) return MetricStatus.aboveNormal;
        return MetricStatus.ideal;
      },
      statusLabelResolver: (val) {
        if (val == null) return 'Спокойно (0-2 Kp)';
        if (val >= 5) return 'Магнитная буря (G1+)';
        if (val >= 4) return 'Слабые возмущения';
        return 'Магнитосфера спокойна (Норма)';
      },
    ),

    'ob_river': WeatherMetricInfo(
      key: 'ob_river',
      title: 'Уровень воды в реке Обь',
      category: 'Гидрология Нижневартовска',
      icon: Icons.waves_rounded,
      accentColor: const Color(0xFF0284C7),
      unit: 'см',
      normRange: 'Межень (зима/осень): 150 – 400 см. Летний уровень: 450 – 800 см. Неблагоприятный: 890 см. Опасный: 940 – 980 см.',
      whatIsIt: 'Высота водной глади реки Обь относительно нулевой отметки водомерного гидропоста Нижневартовска.',
      whenBelow: 'Низкий уровень: Обнажение песчаных кос и островов, ограничение осадки для речного грузового флота.',
      whenAbove: 'Паводок выше 900 см: Подтопление дачных участков в районе РЭБ Флота, Палиевских дач и Старого Вартовска.',
      recommendations: 'В период весенне-летнего половодья следите за ежедневными гидрологическими сводками МЧС в приложении City Pulse.',
      statusResolver: (val) {
        if (val == null) return MetricStatus.normal;
        if (val >= 940) return MetricStatus.caution;
        if (val >= 890) return MetricStatus.aboveNormal;
        return MetricStatus.ideal;
      },
      statusLabelResolver: (val) {
        if (val == null) return 'В русле (Норма)';
        if (val >= 940) return 'Опасный паводок';
        if (val >= 890) return 'Высокий уровень воды';
        return 'Безопасный уровень русла';
      },
    ),

    'moon_phase': WeatherMetricInfo(
      key: 'moon_phase',
      title: 'Фаза Луны и лунный цикл',
      category: 'Астрономия',
      icon: Icons.nightlight_round,
      accentColor: const Color(0xFF818CF8),
      unit: '%',
      normRange: 'Цикл длится 29.53 суток: Новолуние (0%), Первая четверть (50%), Полнолуние (100%), Последняя четверть (50%).',
      whatIsIt: 'Степень освещенности видимого диска Луны солнечными лучами с точки зрения земного наблюдателя.',
      whenBelow: 'Новолуние: Спад биоритмической активности, идеальное время для планирования, разгрузочных дней и очищения организма.',
      whenAbove: 'Полнолуние: Пик эмоциональной и творческой энергии, возможна кратковременная бессонница или чуткий сон.',
      recommendations: 'При чувствительности к полнолунию зашторивайте окна плотными шторами блэкаут и избегайте гаджетов за час до сна.',
      statusResolver: (val) => MetricStatus.ideal,
      statusLabelResolver: (val) => 'Лунный ритм',
    ),

    'radiation': WeatherMetricInfo(
      key: 'radiation',
      title: 'Радиационный гамма-фон',
      category: 'Радиоэкология',
      icon: Icons.radar_rounded,
      accentColor: const Color(0xFF10B981),
      unit: 'мкЗв/ч',
      normRange: 'Естественный природный фон: 0.08 – 0.20 мкЗв/ч (микрозиверт в час). Допустимо: до 0.30 мкЗв/ч.',
      whatIsIt: 'Уровень естественного ионизирующего излучения от космических лучей и природных радионуклидов в почве и воздухе.',
      whenBelow: 'Норма 0.09-0.14 мкЗв/ч: Полная безопасность для человека.',
      whenAbove: 'Превышение (> 0.50 мкЗв/ч): Техногенная аномалия, требующая проверки службами ГО и ЧС.',
      recommendations: 'Радиационный фон в Нижневартовске и ХМАО стабильно находится на идеальном природном уровне 0.09–0.12 мкЗв/ч.',
      statusResolver: (val) => (val != null && val > 0.3) ? MetricStatus.caution : MetricStatus.ideal,
      statusLabelResolver: (val) => 'Идеальный природный фон (0.11 мкЗв/ч)',
    ),

    'seismic': WeatherMetricInfo(
      key: 'seismic',
      title: 'Сейсмическая стабильность',
      category: 'Геофизика',
      icon: Icons.public_rounded,
      accentColor: const Color(0xFF14B8A6),
      unit: 'M',
      normRange: 'Фоновый микросейсмический шум Западно-Сибирской платформы: 0.0 – 1.2 M (абсолютный покой).',
      whatIsIt: 'Мониторинг колебаний земной коры в районе Самотлорского месторождения и бассейна Средней Оби.',
      whenBelow: 'Полный тектонический покой кристаллического фундамента плиты.',
      whenAbove: 'Микротолчки техногенного или тектонического происхождения (>3.5 M) в регионе фиксируются крайне редко.',
      recommendations: 'Нижневартовск расположен на стабильной древней платформе — сейсмическая угроза отсутствует.',
      statusResolver: (val) => MetricStatus.ideal,
      statusLabelResolver: (val) => 'Платформа стабильна (0.0 M)',
    ),

    'aktirovka': WeatherMetricInfo(
      key: 'aktirovka',
      title: 'Актированные дни в школах ХМАО',
      category: 'Безопасность детей',
      icon: Icons.school_rounded,
      accentColor: const Color(0xFF00E5FF),
      unit: 'классы',
      normRange: 'Занятия проводятся для всех классов (1-11) при комфортной зимней температуре или летом.',
      whatIsIt: 'Официальный регламент Департамента образования ХМАО-Югры об отмене очных занятий в школах из-за сильного мороза и ветра.',
      whenBelow: 'Отмена занятий: 1-4 классы (при -29°C без ветра или -24°C с ветром >10 м/с); 1-8 классы (при -32°C или -27°C с ветром); 1-11 классы (при -36°C или -31°C с ветром).',
      whenAbove: 'Занятия в школах идут в штатном режиме.',
      recommendations: 'При объявлении актировки школьники обучаются с применением дистанционных технологий через платформу ЭПОС.',
      statusResolver: (val) => MetricStatus.ideal,
      statusLabelResolver: (val) => 'Регламент ХМАО',
    ),

    'eclipse': WeatherMetricInfo(
      key: 'eclipse',
      title: 'Атлас солнечных и лунных затмений',
      category: 'Астрономия и Небесная механика',
      icon: Icons.wb_twilight_rounded,
      accentColor: const Color(0xFF00E5FF),
      unit: '%',
      normRange: 'Периодичность затмений подчиняется циклу Сароса (~18 лет 11 дней 8 часов). В Нижневартовске ближайшее солнечное затмение — 1 июня 2030 г. (73.8%).',
      whatIsIt: 'Астрономическое явление, при котором Луна закрывает диск Солнца (солнечное затмение) или входит в тень Земли (лунное затмение). Расчёты выполнены для координат Нижневартовска на основе атласа eclipses.bogachev.fr и канона NASA.',
      whenBelow: 'Частная фаза: Освещенность мягко тускнеет, тени от листвы деревьев принимают форму полумесяцев.',
      whenAbove: 'Глубокая фаза (80%+): Заметное падение температуры воздуха на 2-4°C, птицы замолкают, на небе проявляются яркие планеты (Венера, Юпитер).',
      recommendations: 'Категорически запрещено смотреть на Солнце без специализированных фильтров ISO 12312-2. Обычные темные очки не защищают сетчатку от невидимого инфракрасного и ультрафиолетового ожога.',
      statusResolver: (val) => MetricStatus.ideal,
      statusLabelResolver: (val) => 'Канон NASA & Bogachev',
    ),
  };

  static WeatherMetricInfo get(String key) {
    return metrics[key] ?? metrics['temperature']!;
  }
}

/// Показывает премиальное всплывающее окно с объяснением нормы
void showWeatherMetricExplanationSheet({
  required BuildContext context,
  required String metricKey,
  dynamic currentValue,
}) {
  HapticFeedback.mediumImpact();
  final info = WeatherMetricsCatalog.get(metricKey);
  final num? numVal = currentValue is num
      ? currentValue
      : (currentValue != null ? num.tryParse(currentValue.toString().replaceAll(RegExp(r'[^\d\.\-]'), '')) : null);

  final status = info.statusResolver(numVal);
  final statusLabel = info.statusLabelResolver(numVal);

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.65),
    builder: (ctx) {
      return BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF0B132B).withOpacity(0.92),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: info.accentColor.withOpacity(0.4),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: info.accentColor.withOpacity(0.25),
                blurRadius: 30,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),

              // Header with Icon, Title and Close button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: info.accentColor.withOpacity(0.18),
                        border: Border.all(color: info.accentColor.withOpacity(0.5)),
                        boxShadow: [
                          BoxShadow(
                            color: info.accentColor.withOpacity(0.3),
                            blurRadius: 12,
                          ),
                        ],
                      ),
                      child: Icon(info.icon, color: info.accentColor, size: 26),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            info.category.toUpperCase(),
                            style: TextStyle(
                              color: info.accentColor,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            info.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Value & Status Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ТЕКУЩЕЕ ЗНАЧЕНИЕ',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.55),
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            currentValue != null ? '$currentValue' : 'Измерено online',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: _getStatusBadgeColor(status).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _getStatusBadgeColor(status).withOpacity(0.6)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getStatusIcon(status),
                              color: _getStatusBadgeColor(status),
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              statusLabel,
                              style: TextStyle(
                                color: _getStatusBadgeColor(status),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Scrollable Content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    // 1. Норма
                    _buildSectionBlock(
                      icon: Icons.verified_rounded,
                      iconColor: const Color(0xFF10B981),
                      title: 'НОРМА И ОПТИМАЛЬНЫЙ ДИАПАЗОН',
                      content: info.normRange,
                      bgColor: const Color(0xFF10B981).withOpacity(0.1),
                      borderColor: const Color(0xFF10B981).withOpacity(0.3),
                    ),
                    const SizedBox(height: 12),

                    // 2. Что это такое
                    _buildSectionBlock(
                      icon: Icons.info_outline_rounded,
                      iconColor: const Color(0xFF38BDF8),
                      title: 'ЧТО ОЗНАЧАЕТ ЭТОТ ПОКАЗАТЕЛЬ?',
                      content: info.whatIsIt,
                      bgColor: Colors.white.withOpacity(0.04),
                      borderColor: Colors.white.withOpacity(0.1),
                    ),
                    const SizedBox(height: 12),

                    // 3. Отклонения: Ниже нормы & Выше нормы
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.compare_arrows_rounded, color: Color(0xFFF59E0B), size: 18),
                              SizedBox(width: 8),
                              Text(
                                'ЧТО ЗНАЧАТ ОТКЛОНЕНИЯ ОТ НОРМЫ',
                                style: TextStyle(
                                  color: Color(0xFFF59E0B),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('📉 ', style: TextStyle(fontSize: 14)),
                              Expanded(
                                child: Text(
                                  info.whenBelow,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.85),
                                    fontSize: 12.5,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('📈 ', style: TextStyle(fontSize: 14)),
                              Expanded(
                                child: Text(
                                  info.whenAbove,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.85),
                                    fontSize: 12.5,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 4. Рекомендации для жителей
                    _buildSectionBlock(
                      icon: Icons.lightbulb_outline_rounded,
                      iconColor: const Color(0xFFFFD54F),
                      title: 'РЕКОМЕНДАЦИИ ДЛЯ ЖИТЕЛЕЙ НИЖНЕВАРТОВСКА',
                      content: info.recommendations,
                      bgColor: const Color(0xFFFFD54F).withOpacity(0.08),
                      borderColor: const Color(0xFFFFD54F).withOpacity(0.3),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _buildSectionBlock({
  required IconData icon,
  required Color iconColor,
  required String title,
  required String content,
  required Color bgColor,
  required Color borderColor,
}) {
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: bgColor,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: iconColor, size: 17),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: iconColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            height: 1.45,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    ),
  );
}

Color _getStatusBadgeColor(MetricStatus status) {
  switch (status) {
    case MetricStatus.ideal:
    case MetricStatus.normal:
      return const Color(0xFF10B981);
    case MetricStatus.aboveNormal:
    case MetricStatus.belowNormal:
      return const Color(0xFFF59E0B);
    case MetricStatus.caution:
      return const Color(0xFFEF4444);
  }
}

IconData _getStatusIcon(MetricStatus status) {
  switch (status) {
    case MetricStatus.ideal:
    case MetricStatus.normal:
      return Icons.check_circle_rounded;
    case MetricStatus.aboveNormal:
      return Icons.arrow_upward_rounded;
    case MetricStatus.belowNormal:
      return Icons.arrow_downward_rounded;
    case MetricStatus.caution:
      return Icons.warning_amber_rounded;
  }
}
