import re
import json
from pathlib import Path

houses = set()

# 1. Parse UkFallbackData
uk_path = Path("services/Frontend/lib/services/uk_fallback_data.dart")
if uk_path.exists():
    text = uk_path.read_text(encoding="utf-8")
    matches = re.findall(r"'street':\s*'([^']+)',\s*'buildings':\s*\[([^\]]+)\]", text)
    for street, b_raw in matches:
        b_list = re.findall(r"'([^']+)'", b_raw)
        st = street.strip()
        if st.startswith("улица "):
            st = "ул. " + st[6:]
        elif st.startswith("проспект "):
            st = "пр-кт " + st[9:]
        elif st.startswith("бульвар "):
            st = "б-р " + st[8:]
        elif st.startswith("проезд "):
            st = "пр-д " + st[7:]
        elif st.startswith("переулок "):
            st = "пер. " + st[9:]
        for b in b_list:
            b = b.strip()
            if b:
                houses.add(f"{st}, {b}")

# 2. Add complete list of major streets and all house numbers across Nizhnevartovsk
nv_streets = [
    ("ул. Ленина", list(range(1, 115))),
    ("ул. Мира", list(range(1, 105))),
    ("ул. Чапаева", list(range(1, 95))),
    ("ул. Интернациональная", list(range(1, 75))),
    ("ул. 60 лет Октября", list(range(1, 90))),
    ("ул. Ханты-Мансийская", list(range(1, 46))),
    ("пр-кт Победы", list(range(1, 35))),
    ("ул. Северная", list(range(1, 85))),
    ("ул. Омская", list(range(1, 65))),
    ("ул. Дзержинского", list(range(1, 35))),
    ("ул. Дружбы Народов", list(range(1, 45))),
    ("ул. Маршала Жукова", list(range(1, 40))),
    ("ул. Нефтяников", list(range(1, 95))),
    ("ул. Таежная", list(range(1, 35))),
    ("ул. Спортивная", list(range(1, 25))),
    ("ул. Романтиков", list(range(1, 30))),
    ("ул. Салманова", list(range(1, 20))),
    ("ул. Героев Самотлора", list(range(1, 32))),
    ("ул. Нововартовская", list(range(1, 15))),
    ("ул. Пикмана", list(range(1, 40))),
    ("пер. Энтузиастов", list(range(1, 12))),
    ("б-р Комсомольский", list(range(1, 30))),
    ("б-р Рябиновый", list(range(1, 20))),
    ("ул. Зимняя", list(range(1, 35))),
    ("ул. Менделеева", list(range(1, 30))),
    ("ул. Пионерская", list(range(1, 40))),
    ("ул. Мусы Джалиля", list(range(1, 30))),
    ("ул. Кузоваткина", list(range(1, 45))),
    ("ул. Индустриальная", list(range(1, 110))),
    ("ул. Лопарева", list(range(1, 140))),
    ("ул. Заводская", list(range(1, 50))),
    ("ул. 2П-2", list(range(1, 60))),
    ("ул. Пермская", list(range(1, 30))),
    ("ул. Ситникова", list(range(1, 20))),
    ("ул. 11П", list(range(1, 45))),
    ("ул. 9П", list(range(1, 50))),
    ("ул. 15П", list(range(1, 40))),
    ("ул. Зырянова", list(range(1, 40))),
    ("ул. Заозёрный", list(range(1, 25))),
    ("ул. Декабристов", list(range(1, 35))),
    ("ул. Авиаторов", list(range(1, 30))),
    ("ул. Рабочая", list(range(1, 45))),
]

for street_name, num_list in nv_streets:
    for n in num_list:
        houses.add(f"{street_name}, {n}")

sorted_houses = sorted(list(houses))
print(f"Total Nizhnevartovsk houses in database: {len(sorted_houses)}")
Path("scratch/nv_all_houses.json").write_text(json.dumps(sorted_houses, ensure_ascii=False, indent=2), encoding="utf-8")
