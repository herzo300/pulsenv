"""Генерирует JSON-данные для инфографики из opendata_full.json"""
import json

f = open('opendata_full.json', 'r', encoding='utf-8')
d = json.load(f)

info = {}

# 1. Цены на бензин (актуальные 13.02.2026)
gas = d['roadgasstationprice']['rows']
fuel_prices = {}
for fuel_key, fuel_name in [('AI92','АИ-92'),('AI95EURO','АИ-95'),('DTZIMA','ДТ зимнее'),('GAZ','Газ')]:
    vals = [g[fuel_key] for g in gas if g.get(fuel_key)]
    if vals:
        fuel_prices[fuel_name] = {
            'min': round(min(vals), 1),
            'max': round(max(vals), 1),
            'avg': round(sum(vals)/len(vals), 1),
            'count': len(vals)
        }
info['fuel'] = {'date': '13.02.2026', 'stations': len(gas), 'prices': fuel_prices}

# 2. УК
uk = d['listoumd']['rows']
total_houses = sum(int(u.get('CNT', 0)) for u in uk)
top_uk = sorted(uk, key=lambda x: int(x.get('CNT', 0)), reverse=True)[:10]
info['uk'] = {
    'total': len(uk),
    'houses': total_houses,
    'top': [{'name': u.get('TITLESM',''), 'houses': int(u.get('CNT',0))} for u in top_uk]
}

# 3. Образование
info['education'] = {
    'kindergartens': len(d['uchdou']['rows']),
    'schools': len(d['uchou']['rows']),
    'culture': len(d['uchculture']['rows']),
    'sport_orgs': len(d['uchsport']['rows']),
    'sport_sections': len(d['uchsportsection']['rows']),
    'sections_free': sum(1 for s in d['uchsportsection']['rows'] if s.get('PAY') == 'Бюджетная группа'),
    'sections_paid': sum(1 for s in d['uchsportsection']['rows'] if s.get('PAY') == 'Платная группа'),
}

# 4. Мусор
waste = d['wastecollection']['rows']
wgroups = {}
for w in waste:
    g = w.get('GROUP', '')
    wgroups[g] = wgroups.get(g, 0) + 1
info['waste'] = {
    'total_points': len(waste),
    'groups': [{'name': g, 'count': c} for g, c in sorted(wgroups.items(), key=lambda x: -x[1])]
}

# 5. Стройки
info['construction'] = {'total': len(d['buildlist']['rows'])}

# 6. Имена
boys = d['topnameboys']['rows']
girls = d['topnamegirls']['rows']
top_boys = sorted(boys, key=lambda x: int(x.get('CNT', 0)), reverse=True)[:10]
top_girls = sorted(girls, key=lambda x: int(x.get('CNT', 0)), reverse=True)[:10]
info['names'] = {
    'boys': [{'name': b['TITLE'], 'count': int(b['CNT'])} for b in top_boys],
    'girls': [{'name': g['TITLE'], 'count': int(g['CNT'])} for g in top_girls],
}

# 7. ЖКХ службы
gkh = d['uchgkhservices']['rows']
info['gkh_services'] = [{'name': g['TITLE'], 'phone': g.get('TEL','')} for g in gkh]

# 8. МСП поддержка
msp = d['mspsupport']['rows']
info['msp'] = {'total': len(msp)}

# 9. Телефонный справочник
info['phonebook'] = {'total': len(d['agphonedir']['rows'])}

# 10. Структура администрации
info['admin_struct'] = {'total': len(d['agstruct']['rows'])}

# 11. Спортзалы
info['sport_places'] = {'total': len(d['placessg']['rows'])}

# 12. МФЦ
info['mfc'] = {'total': len(d['placespk']['rows'])}

print(json.dumps(info, ensure_ascii=False, indent=2))
