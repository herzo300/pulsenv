"""Собирает worker.js: base + app.html + app_script.js -> APP_HTML + map.html + map_script.js -> MAP_HTML + info.html + info_script.js -> INFO_HTML"""
import os

DIR = os.path.dirname(os.path.abspath(__file__))

# Читаем базу worker.js (всё до APP_HTML, MAP_HTML и INFO_HTML)
with open(os.path.join(DIR, "worker.js"), "r", encoding="utf-8") as f:
    full = f.read()

# Обрезаем старые HTML константы если есть
marker_app = "\n// ===== Unified Web App"
marker_map = "\n// ===== Встроенная карта"
marker_info = "\n// ===== Инфографика"

idx_app = full.find(marker_app)
idx_map = full.find(marker_map)
idx_info = full.find(marker_info)

# Находим первый маркер для обрезки
cut_idx = len(full)
for idx in [idx_app, idx_map, idx_info]:
    if idx != -1 and idx < cut_idx:
        cut_idx = idx

if cut_idx < len(full):
    base = full[:cut_idx].rstrip()
else:
    base = full.rstrip()

# ═══ MAP ═══
with open(os.path.join(DIR, "map.html"), "r", encoding="utf-8") as f:
    map_html = f.read()
with open(os.path.join(DIR, "map_script.js"), "r", encoding="utf-8") as f:
    map_script = f.read()

# Вставляем скрипт перед </body>
full_map = map_html.replace("</body>", f"<script>\n{map_script}\n</script>\n</body>")

# Экранируем для JS template literal
def escape_for_template(s):
    s = s.replace("\\", "\\\\")
    s = s.replace("`", "\\`")
    s = s.replace("${", "\\${")
    s = s.replace("</script>", "<\\/script>")
    return s

full_map_escaped = escape_for_template(full_map)

# ═══ APP ═══
with open(os.path.join(DIR, "app.html"), "r", encoding="utf-8") as f:
    app_html = f.read()
with open(os.path.join(DIR, "app_script.js"), "r", encoding="utf-8") as f:
    app_script = f.read()

# Вставляем скрипт перед </body>
full_app = app_html.replace("</body>", f"<script>\n{app_script}\n</script>\n</body>")
full_app_escaped = escape_for_template(full_app)

# ═══ INFO ═══
with open(os.path.join(DIR, "info.html"), "r", encoding="utf-8") as f:
    info_html = f.read()
with open(os.path.join(DIR, "info_script.js"), "r", encoding="utf-8") as f:
    info_script = f.read()

full_info = info_html.replace("</body>", f"<script>\n{info_script}\n</script>\n</body>")
full_info_escaped = escape_for_template(full_info)

# Собираем
output = base
output += "\n\n// ===== Unified Web App (Telegram Web App) =====\nconst APP_HTML = `" + full_app_escaped + "`;\n"
output += "\n// ===== Встроенная карта (Telegram Web App) =====\nconst MAP_HTML = `" + full_map_escaped + "`;\n"
output += "\n// ===== Инфографика — открытые данные Нижневартовска =====\nconst INFO_HTML = `" + full_info_escaped + "`;\n"

# ═══ INFOGRAPHIC DATA ═══
infographic_path = os.path.join(os.path.dirname(DIR), "infographic_data.json")
if os.path.exists(infographic_path):
    with open(infographic_path, "r", encoding="utf-8") as f:
        infographic_json = f.read().strip()
    output += "\n// ===== Данные инфографики (JSON) =====\nconst INFOGRAPHIC_DATA = `" + infographic_json.replace("\\", "\\\\").replace("`", "\\`").replace("${", "\\${") + "`;\n"
    print(f"infographic_data.json: {len(infographic_json)} chars")
else:
    output += "\n// ===== Данные инфографики (пусто) =====\nconst INFOGRAPHIC_DATA = '{}';\n"
    print("WARNING: infographic_data.json not found!")

with open(os.path.join(DIR, "worker.js"), "w", encoding="utf-8") as f:
    f.write(output)

lines = output.count('\n')
print(f"worker.js: {len(output)} chars, ~{lines} lines")
