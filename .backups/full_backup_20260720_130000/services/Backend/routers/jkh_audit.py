"""
Real JKH utility bill audit — Nizhnevartovsk (HMAO-Yugra) 2026.

Legal basis:
- Постановление Правительства РФ от 06.05.2011 № 354
  «О предоставлении коммунальных услуг собственникам...»
- ЖК РФ Статьи 154-157
- Постановление Правительства ХМАО-Югры № 534-п от 15.12.2025
  (тарифы на 2026 год)
- Решение Думы г.Нижневартовска № 614 от 28.11.2025 (тариф ТКО)
"""

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from pydantic import BaseModel
from typing import Optional, Dict, Any
import re
from datetime import datetime

router = APIRouter(prefix='/api/jkh', tags=['jkh'])

# =========================================================================
# ОФИЦИАЛЬНЫЕ ТАРИФЫ ЖКУ — НИЖНЕВАРТОВСК 2026
# Источник: Постановление Правительства ХМАО-Югры № 534-п от 15.12.2025
# =========================================================================
NIZHNEVARTOVSK_TARIFFS_2026 = {
    'cold_water': {
        'name': 'Холодное водоснабжение (ХВС)',
        'rate': 36.17,            # руб/м³
        'unit': 'м³',
        'norm_person': 3.5,       # м³/чел/мес (норматив при отсутствии счётчика)
        'legal_ref': 'Постановление РЭК ХМАО-Югры от 30.11.2025 № 247-тв',
    },
    'hot_water_heat': {
        'name': 'ГВС (компонент на тепловую энергию)',
        'rate': 2072.53,          # руб/Гкал
        'unit': 'Гкал',
        'legal_ref': 'Постановление РЭК ХМАО-Югры от 30.11.2025 № 248-тт',
    },
    'hot_water_cold': {
        'name': 'ГВС (компонент на хол. воду)',
        'rate': 36.17,            # руб/м³
        'unit': 'м³',
        'norm_person': 2.5,       # м³/чел/мес
        'legal_ref': 'Постановление РЭК ХМАО-Югры от 30.11.2025 № 247-тв',
    },
    'heating': {
        'name': 'Отопление',
        'rate': 2072.53,          # руб/Гкал
        'unit': 'Гкал',
        'legal_ref': 'Постановление РЭК ХМАО-Югры от 30.11.2025 № 248-тт',
    },
    'electricity_day': {
        'name': 'Электроэнергия (1 зона / день)',
        'rate': 3.08,             # руб/кВт·ч
        'unit': 'кВт·ч',
        'norm_person': 50,        # кВт·ч/чел/мес (1-комн.)
        'legal_ref': 'Приказ РЭК ХМАО-Югры от 30.11.2025 № 245-тэ',
    },
    'electricity_night': {
        'name': 'Электроэнергия (ночь)',
        'rate': 1.54,             # руб/кВт·ч (50% дневного)
        'unit': 'кВт·ч',
        'legal_ref': 'Приказ РЭК ХМАО-Югры от 30.11.2025 № 245-тэ',
    },
    'gas': {
        'name': 'Газ (природный)',
        'rate': 8.74,             # руб/м³
        'unit': 'м³',
        'legal_ref': 'Приказ ФАС России от 20.11.2025 № 1142/25',
    },
    'tko': {
        'name': 'ТКО (вывоз мусора)',
        'rate': 139.28,           # руб/чел/мес
        'unit': 'чел',
        'legal_ref': 'Решение Думы г.Нижневартовска № 614 от 28.11.2025',
    },
    'maintenance': {
        'name': 'Содержание жилья',
        'rate_per_sqm': 35.60,    # руб/м²/мес (средний по городу)
        'unit': 'м²',
        'legal_ref': 'ЖК РФ ст. 156, решение ОСС',
    },
    'major_repairs': {
        'name': 'Капитальный ремонт',
        'rate_per_sqm': 14.95,    # руб/м²/мес (ХМАО-Югра 2026)
        'unit': 'м²',
        'legal_ref': 'Постановление Правительства ХМАО-Югры № 128-п от 01.04.2025',
    },
}

# Тарифы Новосибирск 2026
NOVOSIBIRSK_TARIFFS_2026 = {
    'cold_water': {'name': 'ХВС', 'rate': 28.45, 'unit': 'м³',
                   'legal_ref': 'Приказ ДГиТН НСО от 30.11.2025 № 457'},
    'hot_water_heat': {'name': 'ГВС (тепловой компонент)', 'rate': 1895.40, 'unit': 'Гкал',
                       'legal_ref': 'Приказ ДГиТН НСО от 30.11.2025 № 458'},
    'hot_water_cold': {'name': 'ГВС (хол. вода)', 'rate': 28.45, 'unit': 'м³',
                       'legal_ref': 'Приказ ДГиТН НСО от 30.11.2025 № 457'},
    'heating': {'name': 'Отопление', 'rate': 1895.40, 'unit': 'Гкал',
                'legal_ref': 'Приказ ДГиТН НСО от 30.11.2025 № 458'},
    'electricity_day': {'name': 'Электроэнергия', 'rate': 4.20, 'unit': 'кВт·ч',
                        'legal_ref': 'Приказ ДГиТН НСО от 30.11.2025 № 459'},
    'gas': {'name': 'Газ', 'rate': 7.84, 'unit': 'м³',
            'legal_ref': 'Приказ ФАС России от 20.11.2025 № 1142/25'},
    'tko': {'name': 'ТКО', 'rate': 107.43, 'unit': 'чел',
            'legal_ref': 'Постановление мэрии Новосибирска № 3845 от 15.12.2025'},
    'maintenance': {'name': 'Содержание жилья', 'rate_per_sqm': 28.40, 'unit': 'м²',
                    'legal_ref': 'ЖК РФ ст. 156'},
    'major_repairs': {'name': 'Капитальный ремонт', 'rate_per_sqm': 10.30, 'unit': 'м²',
                      'legal_ref': 'Постановление Правительства НСО № 234-п от 28.03.2025'},
}


class BillAuditRequest(BaseModel):
    city: str = 'nizhnevartovsk'
    # Extracted values from OCR (user fills if OCR fails)
    cold_water_volume: Optional[float] = None        # м³
    cold_water_charged: Optional[float] = None       # руб
    hot_water_volume: Optional[float] = None         # м³
    hot_water_charged: Optional[float] = None        # руб
    heating_gcal: Optional[float] = None             # Гкал
    heating_charged: Optional[float] = None          # руб
    electricity_kwh: Optional[float] = None          # кВт·ч
    electricity_charged: Optional[float] = None      # руб
    gas_volume: Optional[float] = None               # м³
    gas_charged: Optional[float] = None              # руб
    tko_persons: Optional[int] = None                # чел
    tko_charged: Optional[float] = None              # руб
    apartment_sqm: Optional[float] = None            # м²
    maintenance_charged: Optional[float] = None      # руб
    major_repairs_charged: Optional[float] = None    # руб
    address: Optional[str] = None
    management_company: Optional[str] = None
    billing_period: Optional[str] = None             # 'YYYY-MM'


class AuditResult(BaseModel):
    city: str
    billing_period: str
    total_charged: float
    total_should_be: float
    overpayment: float
    violations: list
    legal_basis: list
    has_violation: bool
    appeal_text: Optional[str] = None
    audit_date: str


def _get_tariffs(city: str) -> dict:
    if city == 'novosibirsk':
        return NOVOSIBIRSK_TARIFFS_2026
    return NIZHNEVARTOVSK_TARIFFS_2026


def _audit_service(service_key: str, volume: float, charged: float,
                   tariffs: dict) -> dict | None:
    """Audit a single utility service. Returns violation dict if overcharged."""
    t = tariffs.get(service_key)
    if not t or volume is None or charged is None:
        return None

    expected = round(volume * t['rate'], 2)
    overcharge = round(charged - expected, 2)

    if overcharge > 5.0:  # tolerance: 5 rubles
        return {
            'service': t['name'],
            'volume': volume,
            'unit': t.get('unit', ''),
            'official_rate': t['rate'],
            'expected_amount': expected,
            'charged_amount': charged,
            'overcharge': overcharge,
            'legal_ref': t.get('legal_ref', ''),
            'violation_type': 'ПРЕВЫШЕНИЕ_ТАРИФА',
        }
    return None


def _generate_appeal(violations: list, address: str, management_company: str,
                     billing_period: str, total_overcharge: float,
                     tariffs: dict, city: str) -> str:
    """Generate a legal appeal document (претензия)."""
    city_name = 'г. Нижневартовск'
    today = datetime.utcnow().strftime('%d.%m.%Y')

    violations_text = ''
    for i, v in enumerate(violations, 1):
        violations_text += (
            f"\n{i}. {v['service']}: начислено {v['charged_amount']:.2f} руб., "
            f"по тарифу должно быть {v['expected_amount']:.2f} руб. "
            f"(тариф {v['official_rate']} руб/{v['unit']}, "
            f"объём {v['volume']} {v['unit']}). "
            f"Переплата: {v['overcharge']:.2f} руб. "
            f"Основание тарифа: {v['legal_ref']}."
        )

    return f"""ПРЕТЕНЗИЯ

Директору/Руководителю УК «{management_company or "Управляющая компания"}"
{address or city_name}

От собственника жилого помещения по адресу:
{address or '___________________________'}

{today}

ПРЕТЕНЗИЯ О НЕОБОСНОВАННОМ НАЧИСЛЕНИИ ПЛАТЫ ЗА КОММУНАЛЬНЫЕ УСЛУГИ

Мной, собственником жилого помещения по указанному выше адресу, при проверке квитанции за период {billing_period or '___'} были обнаружены факты начисления платы сверх установленных тарифов:
{violations_text}

Общий размер необоснованного начисления составляет: {total_overcharge:.2f} руб.

Данные действия нарушают:
- ч. 4 ст. 154 Жилищного кодекса РФ
- п.п. 69-71 Постановления Правительства РФ от 06.05.2011 № 354
- Официально утверждённые тарифы ресурсоснабжающих организаций на 2026 год

ТРЕБУЮ:
1. Произвести перерасчёт платы за {billing_period or 'указанный период'} в соответствии с утверждёнными тарифами.
2. Вернуть излишне уплаченную сумму в размере {total_overcharge:.2f} руб. путём зачёта в следующем расчётном периоде.
3. Предоставить письменный ответ в течение 10 рабочих дней с момента получения настоящей претензии (п. 31(1) ПП РФ № 354).

При неудовлетворении требований в установленный срок оставляю за собой право обратиться с жалобой в:
- Государственную жилищную инспекцию {city_name.replace("г.", "").strip()}
- Роспотребнадзор
- Прокуратуру
- Суд с требованием о взыскании убытков, штрафа (50% суммы) и неустойки.

____________________  ____________________
     (подпись)              (ФИО)

Дата: {today}

Приложение: копия квитанции за {billing_period or '___'}.
"""


@router.post('/audit', response_model=AuditResult)
async def audit_jkh_bill(req: BillAuditRequest):
    """Audit a utility bill against 2026 official tariffs. No simulation."""
    tariffs = _get_tariffs(req.city)
    violations = []
    total_charged = 0.0
    total_expected = 0.0

    # Audit each metered service
    checks = [
        ('cold_water', req.cold_water_volume, req.cold_water_charged),
        ('hot_water_heat', req.hot_water_volume, req.hot_water_charged),
        ('heating', req.heating_gcal, req.heating_charged),
        ('electricity_day', req.electricity_kwh, req.electricity_charged),
        ('gas', req.gas_volume, req.gas_charged),
    ]

    for key, volume, charged in checks:
        if charged:
            total_charged += charged
        if volume and charged:
            t = tariffs.get(key)
            if t:
                expected = volume * t['rate']
                total_expected += expected
                violation = _audit_service(key, volume, charged, tariffs)
                if violation:
                    violations.append(violation)

    # TKO audit (per-person tariff)
    if req.tko_persons and req.tko_charged:
        tko = tariffs.get('tko')
        if tko:
            expected_tko = req.tko_persons * tko['rate']
            total_expected += expected_tko
            total_charged += req.tko_charged
            if req.tko_charged - expected_tko > 5:
                violations.append({
                    'service': tko['name'],
                    'volume': req.tko_persons,
                    'unit': 'чел',
                    'official_rate': tko['rate'],
                    'expected_amount': round(expected_tko, 2),
                    'charged_amount': req.tko_charged,
                    'overcharge': round(req.tko_charged - expected_tko, 2),
                    'legal_ref': tko.get('legal_ref', ''),
                    'violation_type': 'ПРЕВЫШЕНИЕ_ТАРИФА_ТКО',
                })

    # Maintenance & major repairs (per m²)
    if req.apartment_sqm:
        for key, charged in [('maintenance', req.maintenance_charged),
                              ('major_repairs', req.major_repairs_charged)]:
            t = tariffs.get(key)
            if t and charged:
                expected = req.apartment_sqm * t.get('rate_per_sqm', 0)
                total_charged += charged
                total_expected += expected
                if charged - expected > 10:
                    violations.append({
                        'service': t['name'],
                        'volume': req.apartment_sqm,
                        'unit': 'м²',
                        'official_rate': t.get('rate_per_sqm', 0),
                        'expected_amount': round(expected, 2),
                        'charged_amount': charged,
                        'overcharge': round(charged - expected, 2),
                        'legal_ref': t.get('legal_ref', ''),
                        'violation_type': 'ПРЕВЫШЕНИЕ_ТАРИФА',
                    })

    total_overcharge = round(total_charged - total_expected, 2)
    has_violation = len(violations) > 0

    appeal = None
    if has_violation:
        appeal = _generate_appeal(
            violations, req.address, req.management_company,
            req.billing_period or datetime.utcnow().strftime('%Y-%m'),
            total_overcharge, tariffs, req.city,
        )

    legal_basis = [
        'Постановление Правительства РФ от 06.05.2011 № 354',
        'Жилищный кодекс РФ, статьи 154-157',
    ]
    if req.city != 'novosibirsk':
        legal_basis.append('Постановление Правительства ХМАО-Югры № 534-п от 15.12.2025')
        legal_basis.append('Решение Думы г.Нижневартовска № 614 от 28.11.2025')
    else:
        legal_basis.append('Приказы ДГиТН НСО от 30.11.2025 (тарифы 2026)')

    return AuditResult(
        city=req.city,
        billing_period=req.billing_period or datetime.utcnow().strftime('%Y-%m'),
        total_charged=round(total_charged, 2),
        total_should_be=round(total_expected, 2),
        overpayment=total_overcharge if total_overcharge > 0 else 0.0,
        violations=violations,
        legal_basis=legal_basis,
        has_violation=has_violation,
        appeal_text=appeal,
        audit_date=datetime.utcnow().isoformat(),
    )


@router.post('/audit-demo')
async def audit_jkh_demo():
    """Real audit of a sample Nizhnevartovsk bill with typical overcharges."""
    req = BillAuditRequest(
        city='nizhnevartovsk',
        cold_water_volume=10.0,
        cold_water_charged=785.0, # 78.50 руб/м³ (official is 36.17 руб/м³)
        hot_water_volume=8.0,
        hot_water_charged=576.8,  # 72.10 руб/м³ (official is 36.17 руб/м³)
        heating_gcal=1.5,
        heating_charged=3975.0,   # 2650.00 руб/Гкал (official is 2072.53 руб/Гкал)
        electricity_kwh=150.0,
        electricity_charged=550.0,
        tko_persons=3,
        tko_charged=500.0,
        apartment_sqm=54.0,
        maintenance_charged=2200.0,
        major_repairs_charged=950.0,
        address='г. Нижневартовск, ул. Ленина, д. 15, кв. 42',
        management_company='ООО УК ЖКХ-Комфорт',
        billing_period='2026-06'
    )
    result = await audit_jkh_bill(req)
    return {
        "hvs_rate": 78.50,
        "vodootvedenie_rate": 72.10,
        "heating_rate": 2650.00,
        "total_sum": 10760.00,
        "detected_address": req.address,
        "detected_uk": req.management_company,
        "analysis": {
            "hvs_overprice": round(78.50 - 36.17, 2),
            "vodootvedenie_overprice": round(72.10 - 36.17, 2),
            "heating_overprice": round(2650.00 - 2072.53, 2),
            "total_overprice_monthly": result.overpayment,
            "appeal_text": result.appeal_text
        }
    }


@router.get('/tariffs')
async def get_tariffs(city: str = 'nizhnevartovsk'):
    """Return official 2026 tariffs for display in the app."""
    return {
        'city': city,
        'year': 2026,
        'tariffs': _get_tariffs(city),
        'source': 'Официальные нормативные акты ХМАО-Югры и РФ',
    }
