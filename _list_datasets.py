import httpx, json

# Scrape the registry page to find all dataset identifiers
r = httpx.get('https://data.n-vartovsk.ru/opendata/', headers={'User-Agent':'Mozilla/5.0'}, timeout=15, follow_redirects=True)
print(f'Registry page: {r.status_code}, {len(r.text)} chars')

# Find all dataset links like /opendata/8603032896-XXXXX/
import re
links = re.findall(r'/opendata/(8603032896-\w+)', r.text)
unique = sorted(set(links))
print(f'Found {len(unique)} unique dataset identifiers')

# Current datasets
current = {
    "listoumd","agstruct","agphonedir","uchgkhservices","tarif","wastecollection",
    "buildlist","uchdou","uchou","uchsport","uchculture","uchsportsection",
    "topnameboys","topnamegirls","averagesalary","roadgasstationprice","mspsupport",
    "placespk","placessg","territoryplans","busroute","busstation","demography",
    "roadgasstation","roadservice","roadworks","buildpermission","dostupnayasreda",
    "uchcultureclubs","uchsporttrainers","uchoudod","publichearing","stvpgmu"
}

new_ones = []
for ident in unique:
    short = ident.replace('8603032896-','')
    is_new = short not in current
    marker = 'NEW' if is_new else '   '
    print(f'  {marker} {short:40s} {ident}')
    if is_new:
        new_ones.append(short)

print(f'\nCurrent: {len(current)}, Total found: {len(unique)}, New: {len(new_ones)}')
print('\nNew datasets to add:')
for s in new_ones:
    print(f'    "{s}": "8603032896-{s}",')
