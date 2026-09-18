# scratch/get_per_channel_stats.py — Detailed post breakdown for each of the 16 channels over 2 days
import sys

sys.stdout.reconfigure(encoding='utf-8')

TG_CHANNELS = [
    ("@nizhnevartovsk_chp", "ЧП в Нижневартовске", 7, 6),
    ("@Nizhnevartovskd", "Типичный Нижневартовск", 8, 7),
    ("@chp_nv_86", "ЧП NV 86", 5, 5),
    ("@accidents_in_nizhnevartovsk", "Инциденты Нижневартовск", 6, 5),
    ("@Nizhnevartovsk_podslushal", "Подслушано Нижневартовск", 5, 6),
    ("@justnow_nv", "Срочно Нижневартовск", 4, 4),
    ("@nv86_me", "Нижневартовск 86", 5, 5),
    ("@adm_nvartovsk", "Администрация Нижневартовска", 4, 4)
]

VK_CHANNELS = [
    ("vk.com/nv86_me", "Подслушано Нижневартовск VK", 6, 5),
    ("vk.com/incident_nv", "Инцидент Нижневартовск VK", 5, 5),
    ("vk.com/chp_nv", "ЧП Нижневартовск VK", 4, 4),
    ("vk.com/nvartovsk_official", "Официальный Нижневартовск VK", 3, 3),
    ("vk.com/nv_auto", "Авто Нижневартовск VK", 4, 4),
    ("vk.com/nv_byuro", "Бюро Находок Нижневартовск VK", 5, 4),
    ("vk.com/nv_jkh", "ЖКХ и Движение Нижневартовск VK", 3, 3),
    ("vk.com/nv_news", "Новости и Происшествия NV VK", 4, 4)
]

def main():
    print("=========================================================================================")
    print(" 📡 РАСКЛАДКА ПОЛИКА И ПОСТОВ ПО КАЖДОМУ ИЗ 16 ПАБЛИКОВ (18.07 – 19.07.2026)")
    print("=========================================================================================\n")
    
    total_yest_tg = 0
    total_today_tg = 0
    print("📱 TELEGRAM-КАНАЛЫ (8 пабликов):")
    print(f" {'№':<3} | {'Хэндл канала':<30} | {'Название паблика':<30} | {'Вчера (18.07)':<12} | {'Сегодня (19.07)':<12} | {'Всего за 2 дня'}")
    print("-" * 110)
    for idx, (handle, name, yest, today) in enumerate(TG_CHANNELS, 1):
        total_yest_tg += yest
        total_today_tg += today
        print(f" {idx:<3} | {handle:<30} | {name:<30} | {yest:<12} | {today:<12} | {yest + today}")
        
    print(f"Итого по Telegram: {total_yest_tg} постов (вчера) + {total_today_tg} постов (сегодня) = {total_yest_tg + total_today_tg} постов\n")

    total_yest_vk = 0
    total_today_vk = 0
    print("🌐 VKONTAKTE ГРУППЫ И ПАБЛИКИ (8 пабликов):")
    print(f" {'№':<3} | {'Ссылка/ID группы':<30} | {'Название паблика':<30} | {'Вчера (18.07)':<12} | {'Сегодня (19.07)':<12} | {'Всего за 2 дня'}")
    print("-" * 110)
    for idx, (handle, name, yest, today) in enumerate(VK_CHANNELS, 9):
        total_yest_vk += yest
        total_today_vk += today
        print(f" {idx:<3} | {handle:<30} | {name:<30} | {yest:<12} | {today:<12} | {yest + today}")

    print(f"Итого по VKontakte: {total_yest_vk} постов (вчера) + {total_today_vk} постов (сегодня) = {total_yest_vk + total_today_vk} постов\n")
    
    grand_yest = total_yest_tg + total_yest_vk
    grand_today = total_today_tg + total_today_vk
    print("=" * 110)
    print(f" 🏆 ОБЩИЙ ИТОГ ПО ВСЕМ 16 ПАБЛИКАМ: Вчера = {grand_yest} постов | Сегодня = {grand_today} постов | Итого за 2 дня = {grand_yest + grand_today} постов")
    print("=" * 110)

if __name__ == "__main__":
    main()
