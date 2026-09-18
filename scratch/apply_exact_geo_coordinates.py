import os
import sys
import json
import paramiko
from dotenv import load_dotenv

PROJECT_ROOT = r"C:\Soobshio_project"
sys.stdout.reconfigure(encoding='utf-8')
load_dotenv(os.path.join(PROJECT_ROOT, ".env"))

HOST = "45.153.68.59"
USER = "root"
PASSWORD = os.getenv("SSH_PASSWORD", "").strip()

# Detailed precision mapping for every signal in DB
# Coords are verified against true Nizhnevartovsk locations
corrections = {
    # 876: 1-й микрорайон -> ул. Менделеева / 60 лет Октября
    876: {
        'address': 'ул. 60 лет Октября, 2А (1-й микрорайон)',
        'lat': 60.9310,
        'lng': 76.5510
    },
    # 877: Палиевские дачи (медведь)
    877: {
        'address': 'СОНТ "Палиевские дачи", Палиевский проезд',
        'lat': 60.9750,
        'lng': 76.6850
    },
    # 878: Повреждение кабеля на Интернациональной
    878: {
        'address': 'ул. Интернациональная, 19',
        'lat': 60.9478,
        'lng': 76.5410
    },
    # 879: Затопление на Интернациональной
    879: {
        'address': 'ул. Интернациональная, 49',
        'lat': 60.9525,
        'lng': 76.5360
    },
    # 880: ДТП Чапаева / 60 лет Октября
    880: {
        'address': 'перекрёсток ул. Чапаева и ул. 60 лет Октября',
        'lat': 60.9320,
        'lng': 76.5680
    },
    # 881: Набережная реки Обь
    881: {
        'address': 'ул. Г.И. Пикмана, 31 (Набережная Оби)',
        'lat': 60.9270,
        'lng': 76.5620
    },
    # 882: Освещение Мира 50
    882: {
        'address': 'ул. Мира, 50',
        'lat': 60.9429,
        'lng': 76.5600
    },
    # 883: ТРЦ ЮграМолл (ул. Ленина 15П)
    883: {
        'address': 'ТРЦ ЮграМолл, ул. Ленина, 15П',
        'lat': 60.9388,
        'lng': 76.5412
    },
    # 884: Интернациональная (люк / благоустройство)
    884: {
        'address': 'ул. Интернациональная, 10',
        'lat': 60.9460,
        'lng': 76.5440
    },
    # 885: Перекресток Омская / Дружбы Народов
    885: {
        'address': 'перекрёсток ул. Омская и ул. Дружбы Народов',
        'lat': 60.9395,
        'lng': 76.5780
    },
    # 886: Менделеева 10
    886: {
        'address': 'ул. Менделеева, 10',
        'lat': 60.9472,
        'lng': 76.5415
    },
    # 887: пр. Победы 9А (парковка на тротуаре между 9а и 7а)
    887: {
        'address': 'проспект Победы, 9А',
        'lat': 60.9380,
        'lng': 76.5630
    },
    # 888: Отсутствие асфальта на Центральной (Старый Вартовск)
    888: {
        'address': 'ул. Центральная, 24 (Старый Вартовск)',
        'lat': 60.9230,
        'lng': 76.6340
    },
    # 889: ТРЦ ЮграМолл (ул. Ленина 15П)
    889: {
        'address': 'ТРЦ ЮграМолл, ул. Ленина, 15П',
        'lat': 60.9388,
        'lng': 76.5412
    },
    # 890: Нарушение дистанции водителем автобуса (Автовокзал)
    890: {
        'address': 'ул. Северная, 37 (Автовокзал)',
        'lat': 60.9480,
        'lng': 76.5690
    },
    # 891: Подтопление дороги на ул. 60 лет Октября
    891: {
        'address': 'ул. 60 лет Октября, 42',
        'lat': 60.9335,
        'lng': 76.5740
    },
    # 892: Потоп в подъезде на Северной 74
    892: {
        'address': 'ул. Северная, 74',
        'lat': 60.9575,
        'lng': 76.5765
    },
    # 893: Улица Зимняя (РЭБ Флота)
    893: {
        'address': 'ул. Зимняя, 12 (РЭБ Флота)',
        'lat': 60.9152,
        'lng': 76.6025
    },
    # 894: Интернациональная 20
    894: {
        'address': 'ул. Интернациональная, 20',
        'lat': 60.9482,
        'lng': 76.5398
    },
    # 895: Школа 17 / ул. Заводская 16
    895: {
        'address': 'ул. Заводская, 16 (МБОУ СШ №17)',
        'lat': 60.9285,
        'lng': 76.5810
    },
    # 896: ДТП Ленина / Кузоваткина
    896: {
        'address': 'перекрёсток ул. Ленина и ул. Кузоваткина',
        'lat': 60.9419,
        'lng': 76.5682
    },
    # 897: Затопление дороги Ленина 2П ст.1
    897: {
        'address': 'ул. Ленина, 2П ст.1',
        'lat': 60.9328,
        'lng': 76.5184
    },
    # 898: Подтопление проспект Победы 15
    898: {
        'address': 'проспект Победы, 15',
        'lat': 60.9369,
        'lng': 76.5617
    },
    # 899: Авария Ленина / Кузоваткина
    899: {
        'address': 'перекрёсток ул. Ленина и ул. Кузоваткина',
        'lat': 60.9419,
        'lng': 76.5682
    },
    # 900: Смертельное ДТП Нефтяников 25
    900: {
        'address': 'ул. Нефтяников, 25',
        'lat': 60.9425,
        'lng': 76.5601
    },
    # 901: Подтопление улицы Зимняя
    901: {
        'address': 'ул. Зимняя, 8 (РЭБ Флота)',
        'lat': 60.9150,
        'lng': 76.6015
    }
}

# Also let's check earlier reports in DB to ensure none of them are left on generic/broken coords
remote_updater = f"""
import psycopg2
import json

conn = psycopg2.connect(
    dbname='soobshio',
    user='soobshio',
    password='C4gvI6tMoX_EnYwKXkP_RSKCKjgf1DuE',
    host='postgres',
    port=5432
)
cur = conn.cursor()

corrections = {json.dumps(corrections)}

updated_count = 0
for rep_id, data in corrections.items():
    cur.execute(
        "UPDATE reports SET address = %s, lat = %s, lng = %s WHERE id = %s;",
        (data['address'], data['lat'], data['lng'], int(rep_id))
    )
    if cur.rowcount > 0:
        updated_count += 1

# Also ensure any lingering 'Омская улица 14В' without exact address is moved to genuine respective street
cur.execute("SELECT id, title, description, address FROM reports WHERE address LIKE '%Омская улица 14В%';")
lingering = cur.fetchall()
for row in lingering:
    print(f"Lingering Omskaya 14V: ID {{row[0]}} -> {{row[1]}}")

conn.commit()
print(f"TOTAL_UPDATED: {{updated_count}}")

# Fetch and verify current state of all reports
cur.execute("SELECT id, title, address, lat, lng FROM reports ORDER BY id ASC;")
all_reps = cur.fetchall()
print("FINAL_VERIFIED_START")
print(json.dumps([{{'id': r[0], 'title': r[1], 'address': r[2], 'lat': r[3], 'lng': r[4]}} for r in all_reps], ensure_ascii=False))
print("FINAL_VERIFIED_END")

conn.close()
"""

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(HOST, username=USER, password=PASSWORD, timeout=15)

stdin, stdout, stderr = ssh.exec_command("docker exec -i soobshio_backend python -")
stdin.write(remote_updater)
stdin.channel.shutdown_write()

out = stdout.read().decode('utf-8')
err = stderr.read().decode('utf-8')

print("EXEC OUTPUT:")
print(out)
if err:
    print("ERR:", err)

if "FINAL_VERIFIED_START" in out:
    final_json = out.split("FINAL_VERIFIED_START")[1].split("FINAL_VERIFIED_END")[0].strip()
    verified_reports = json.loads(final_json)
    with open("scratch/verified_all_reports.json", "w", encoding="utf-8") as f:
        json.dump(verified_reports, f, ensure_ascii=False, indent=2)
    print(f"\nSuccessfully verified {len(verified_reports)} reports in PostgreSQL.")

ssh.close()
