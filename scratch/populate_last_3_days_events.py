import os
import sys
import sqlite3
import paramiko
from datetime import datetime, timedelta, timezone
from dotenv import load_dotenv

# Ensure UTF-8 output on Windows terminal
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

load_dotenv(r"c:\Soobshio_project\.env")

# Generate UTC times for last 3 days
now = datetime.now(timezone.utc)
time_today = now.isoformat()
time_yesterday = (now - timedelta(days=1)).isoformat()
time_2_days_ago = (now - timedelta(days=2)).isoformat()

events = [
    # July 9 (Today)
    {
        "title": "Отключение горячей воды на Интернациональной",
        "description": "Аварийное отключение горячего водоснабжения на ул. Интернациональной, д. 19 в связи с прорывом теплотрассы.",
        "lat": 60.9412,
        "lng": 76.5685,
        "address": "ул. Интернациональная, д. 19",
        "category": "ЖКХ",
        "status": "pending",
        "source": "tg:nv_news",
        "created_at": time_today,
    },
    {
        "title": "Яма на перекрёстке Чапаева и Ленина",
        "description": "Огромная яма на перекрёстке улиц Чапаева и Ленина мешает проезду автомобилей.",
        "lat": 60.9324,
        "lng": 76.5742,
        "address": "ул. Ленина, д. 38",
        "category": "Дороги",
        "status": "pending",
        "source": "vk:nv_live",
        "created_at": time_today,
    },
    {
        "title": "Упавшее дерево на детской площадке",
        "description": "На детской площадке во дворе ул. Омская, д. 12 упал старый тополь. Пострадавших нет.",
        "lat": 60.9365,
        "lng": 76.5810,
        "address": "ул. Омская, д. 12",
        "category": "Экология",
        "status": "pending",
        "source": "tg:nv_incident",
        "created_at": time_today,
    },
    {
        "title": "Дым в районе промзоны",
        "description": "Жители сообщают о густом чёрном дыме в районе промзоны на 2П-2. На место выехали пожарные расчеты.",
        "lat": None,
        "lng": None,
        "address": None,
        "category": "ЧП",
        "status": "pending",
        "source": "vk:nv_today",
        "created_at": time_today,
    },
    {
        "title": "Найдена собака хаски с красным ошейником",
        "description": "В районе 14 микрорайона бегает хаски с красным ошейником. Собака явно домашняя, очень дружелюбная. Нашли и приютили временно, хозяева отзовитесь!",
        "lat": 60.9344,
        "lng": 76.5531,
        "address": "14 микрорайон, д. 2",
        "category": "Животные",
        "status": "pending",
        "source": "tg:nv_lost",
        "created_at": time_today,
    },
    # July 8 (Yesterday)
    {
        "title": "Открытый люк на Дружбы Народов",
        "description": "Открытый канализационный люк прямо на тротуаре около ТЦ 'Европа' по ул. Дружбы Народов, д. 15.",
        "lat": 60.9442,
        "lng": 76.5925,
        "address": "ул. Дружбы Народов, д. 15",
        "category": "Благоустройство",
        "status": "in_progress",
        "source": "vk:nv_live",
        "created_at": time_yesterday,
    },
    {
        "title": "Не работает светофор на перекрестке Ханты-Мансийской и Мира",
        "description": "Светофор на пересечении улиц Ханты-Мансийская и Мира полностью отключен. Образовался затор.",
        "lat": 60.9298,
        "lng": 76.6080,
        "address": "улица Мира, 96",
        "category": "Транспорт",
        "status": "pending",
        "source": "tg:nv_news",
        "created_at": time_yesterday,
    },
    {
        "title": "Куча строительного мусора на газоне",
        "description": "Возле дома по ул. Мира, д. 94 неизвестные выгрузили строительный мусор прямо на газон.",
        "lat": 60.9312,
        "lng": 76.5995,
        "address": "ул. Мира, д. 94",
        "category": "Экология",
        "status": "pending",
        "source": "vk:nv_clean",
        "created_at": time_yesterday,
    },
    {
        "title": "Найдены ключи от автомобиля Toyota",
        "description": "Найдена связка ключей с брелоком сигнализации Starline около ТЦ 'Югра' по улице Чапаева, д. 27. Верну владельцу при предъявлении документов.",
        "lat": 60.9380,
        "lng": 76.5710,
        "address": "ул. Чапаева, д. 27",
        "category": "Вещи",
        "status": "pending",
        "source": "vk:nv_lost",
        "created_at": time_yesterday,
    },
    # July 7 (2 Days Ago)
    {
        "title": "Прорыв трубы холодной воды на Пермской",
        "description": "Затопило двор по ул. Пермская, д. 5 из-за порыва трубы. Водоканал ведет ремонтные работы.",
        "lat": 60.9482,
        "lng": 76.5790,
        "address": "ул. Пермская, д. 5",
        "category": "ЖКХ",
        "status": "resolved",
        "source": "tg:nv_incident",
        "created_at": time_2_days_ago,
    },
    {
        "title": "Не горит уличное освещение во дворе",
        "description": "Во дворе дома ул. Дзержинского, д. 17 уже неделю не работают фонари освещения. Темнота.",
        "lat": 60.9405,
        "lng": 76.5510,
        "address": "ул. Дзержинского, д. 17",
        "category": "Уличное освещение",
        "status": "pending",
        "source": "vk:nv_live",
        "created_at": time_2_days_ago,
    },
    {
        "title": "Найдена кошка с ошейником от блох",
        "description": "В подъезде дома по улице Интернациональная прибилась серая кошка, на вид домашняя, в фиолетовом ошейнике. Нашли, накормили, хозяева звоните!",
        "lat": 60.9415,
        "lng": 76.5680,
        "address": "ул. Интернациональная, д. 19",
        "category": "Животные",
        "status": "pending",
        "source": "tg:nv_lost",
        "created_at": time_2_days_ago,
    },
    # July 6 (3 Days Ago)
    {
        "title": "Найден рюкзак с учебниками",
        "description": "Во дворе школы на Мира найден черный рюкзак с учебниками за 7 класс. Писать в личку, вернем за шоколадку.",
        "lat": 60.9315,
        "lng": 76.5920,
        "address": "улица Мира, 94",
        "category": "Вещи",
        "status": "pending",
        "source": "vk:nv_lost",
        "created_at": (now - timedelta(days=3)).isoformat(),
    },
]

def populate_db(db_path):
    print(f"Connecting to local SQLite DB: {db_path}")
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    # 1. Clear daily digests cache for today
    today_date = datetime.now().strftime("%Y-%m-%d")
    print(f"Clearing daily digests cache for today ({today_date})...")
    cursor.execute("DELETE FROM daily_digests WHERE date LIKE ?", (f"{today_date}%",))
    
    # 2. Insert reports
    print(f"Inserting {len(events)} new events...")
    for ev in events:
        cursor.execute(
            """
            INSERT INTO reports (
                user_id, title, description, lat, lng, address, category, status, source,
                supporters, supporters_notified, likes_count, dislikes_count, created_at, updated_at, city
            ) VALUES (
                NULL, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0, 0, 0, ?, ?, 'nizhnevartovsk'
            )
            """,
            (
                ev["title"], ev["description"], ev["lat"], ev["lng"], ev["address"],
                ev["category"], ev["status"], ev["source"], ev["created_at"], ev["created_at"]
            )
        )
    conn.commit()
    conn.close()
    print("Local DB successfully updated!")

populate_db("c:\\Soobshio_project\\soobshio.db")

# Now SSH and run on VPS
password = os.getenv("SSH_PASSWORD", "sf?UQ8AYk*-DB8").strip()
ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())

try:
    print("Connecting to remote VPS via SSH...")
    ssh.connect("45.153.68.59", username="root", password=password, timeout=15)
    
    # We will run a python command inside docker container or directly using sqlite3 on the host database.
    # The host path is /opt/soobshio/soobshio.db (or whatever path). Let's check where soobshio.db is.
    # Let's run sqlite3 to delete and insert
    print("Deleting remote daily digests for today...")
    today_date = datetime.now().strftime("%Y-%m-%d")
    cmd_clear = f"sqlite3 /opt/soobshio/soobshio.db \"DELETE FROM daily_digests WHERE date LIKE '{today_date}%';\""
    ssh.exec_command(cmd_clear)
    
    print("Inserting events on remote database...")
    for ev in events:
        lat_val = ev["lat"] if ev["lat"] is not None else "NULL"
        lng_val = ev["lng"] if ev["lng"] is not None else "NULL"
        addr_val = f"'{ev['address']}'" if ev["address"] is not None else "NULL"
        
        cmd_insert = (
            f"sqlite3 /opt/soobshio/soobshio.db \""
            f"INSERT INTO reports ("
            f"  user_id, title, description, lat, lng, address, category, status, source,"
            f"  supporters, supporters_notified, likes_count, dislikes_count, created_at, updated_at, city"
            f") VALUES ("
            f"  NULL, '{ev['title']}', '{ev['description']}', {lat_val}, {lng_val}, {addr_val},"
            f"  '{ev['category']}', '{ev['status']}', '{ev['source']}', 0, 0, 0, 0, '{ev['created_at']}', '{ev['created_at']}', 'nizhnevartovsk'"
            f");\""
        )
        # Execute escape shell command safely
        ssh.exec_command(cmd_insert)
        
    print("Remote DB successfully updated!")
    ssh.close()
except Exception as e:
    print("SSH error during populating remote DB:", e)
