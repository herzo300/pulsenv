import json

f = open('opendata_full.json', 'r', encoding='utf-8')
d = json.load(f)

# averagesalary
sal = d['averagesalary']['rows']
years = sorted(set(r.get('YEAR', '') for r in sal))
print('=== ЗАРПЛАТЫ ===')
print(f'Years: {years}')
print(f'Sample: {sal[0]}')
print(f'Total rows: {len(sal)}')
# Уникальные должности
titles = set(r.get('TITLE', '') for r in sal)
print(f'Unique orgs: {len(titles)}')
for r in sal[:3]:
    print(f'  {r["YEAR"]} | {r["TITLE"]} | {r["POST"]} | {r["SALARY"]}')

# roadgasstationprice
gas = d['roadgasstationprice']['rows']
print(f'\n=== БЕНЗИН ({len(gas)} rows) ===')
print(f'Sample: {gas[0]}')
dates = sorted(set(r.get('DAT', '') for r in gas))
print(f'Dates: {dates[:3]}...{dates[-3:]}')

# topnameboys/girls
boys = d['topnameboys']['rows']
girls = d['topnamegirls']['rows']
print(f'\n=== ИМЕНА ===')
top_boys = sorted(boys, key=lambda x: int(x.get('CNT', 0)), reverse=True)[:5]
top_girls = sorted(girls, key=lambda x: int(x.get('CNT', 0)), reverse=True)[:5]
for b in top_boys:
    print(f'  Boy: {b["TITLE"]} ({b["CNT"]})')
for g in top_girls:
    print(f'  Girl: {g["TITLE"]} ({g["CNT"]})')

# buildlist
builds = d['buildlist']['rows']
print(f'\n=== СТРОЙКИ ({len(builds)} rows) ===')
for b in builds[:3]:
    print(f'  {b["TITLE"]} | {b["ADDRESS"]}')

# wastecollection
waste = d['wastecollection']['rows']
groups = set(r.get('GROUP', '') for r in waste)
print(f'\n=== МУСОР ({len(waste)} rows) ===')
print(f'Groups: {groups}')

# uchdou, uchou
dou = d['uchdou']['rows']
ou = d['uchou']['rows']
print(f'\n=== ОБРАЗОВАНИЕ ===')
print(f'Детсады: {len(dou)}, Школы: {len(ou)}')

# uchculture, uchsport
cult = d['uchculture']['rows']
sport = d['uchsport']['rows']
sections = d['uchsportsection']['rows']
print(f'Культура: {len(cult)}, Спорт: {len(sport)}, Секции: {len(sections)}')

# mspsupport
msp = d['mspsupport']['rows']
print(f'\n=== МСП ПОДДЕРЖКА ({len(msp)} rows) ===')
for m in msp[:2]:
    print(f'  {m.get("NAIMENOVANIE_MERY_PODDERZHKI", "")[:80]}')

# placespk, placessg
pk = d['placespk']['rows']
sg = d['placessg']['rows']
print(f'\n=== МЕСТА ===')
print(f'МФЦ/ПК: {len(pk)}, Спортзалы: {len(sg)}')

# agphonedir
phones = d['agphonedir']['rows']
print(f'\n=== ТЕЛЕФОННЫЙ СПРАВОЧНИК ({len(phones)} rows) ===')

# listoumd
uk = d['listoumd']['rows']
total_houses = sum(int(u.get('CNT', 0)) for u in uk)
print(f'\n=== УК ({len(uk)} компаний, {total_houses} домов) ===')

# uchgkhservices
gkh = d['uchgkhservices']['rows']
print(f'\n=== ЖКХ УСЛУГИ ({len(gkh)} rows) ===')
for g in gkh:
    print(f'  {g["TITLE"]} | {g.get("TEL", "")}')

# tarif
tar = d['tarif']['rows']
print(f'\n=== ТАРИФЫ ({len(tar)} rows) ===')
for t in tar:
    print(f'  {t["TITLE"]}')
