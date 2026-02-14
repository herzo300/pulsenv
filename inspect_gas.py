import json

f = open('opendata_full.json', 'r', encoding='utf-8')
d = json.load(f)
gas = d['roadgasstationprice']['rows']

for g in gas[:15]:
    prices = []
    for k in ['AI80','AI92','AI95','AI95EURO','GDRIVEAI95','AI98','DTLETO','DTZIMA','DTARTIK','GAZ','ECTO100']:
        if g.get(k):
            prices.append(f'{k}={g[k]}')
    azs_id = g.get('AZS', '')
    dat = g.get('DAT', '')
    sep = ' | '
    print(f'AZS {azs_id} ({dat}): {sep.join(prices)}')

# Спортивные секции - подробнее
sections = d['uchsportsection']['rows']
pay_types = {}
for s in sections:
    pay = s.get('PAY', 'unknown')
    pay_types[pay] = pay_types.get(pay, 0) + 1
print(f'\nСекции по оплате: {pay_types}')

ages = {}
for s in sections:
    age = s.get('AGE', 'unknown')
    ages[age] = ages.get(age, 0) + 1
print(f'Секции по возрасту (top): {sorted(ages.items(), key=lambda x: -x[1])[:10]}')

# Мусор - группы с количеством
waste = d['wastecollection']['rows']
wgroups = {}
for w in waste:
    g = w.get('GROUP', '')
    wgroups[g] = wgroups.get(g, 0) + 1
for g, c in sorted(wgroups.items(), key=lambda x: -x[1]):
    print(f'  {g}: {c} точек')

# Тарифы - описания
tar = d['tarif']['rows']
print('\nТарифы:')
for t in tar:
    desc = (t.get('DESCRIPTION') or '')[:120]
    links = t.get('LINKS', [])
    print(f'  {t["TITLE"]}: {desc}... links={len(links) if isinstance(links, list) else "?"}')
