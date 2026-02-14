"""Собирает worker.js: base + map.html + map_script.js -> MAP_HTML + info.html + info_script.js -> INFO_HTML"""
import os

DIR = os.path.dirname(os.path.abspath(__file__))

# Читаем базу worker.js (всё до MAP_HTML и INFO_HTML)
with open(os.path.join(DIR, "worker.js"), "r", encoding="utf-8") as f:
    full = f.read()

# Обрезаем старый MAP_HTML если есть
marker_map = "\n// ===== Встроенная карта"
idx_map = full.find(marker_map)
if idx_map != -1:
    base = full[:idx_map].rstrip()
else:
    # Обрезаем старый INFO_HTML если есть
    marker_info = "\n// ===== Инфографика"
    idx_info = full.find(marker_info)
    if idx_info != -1:
        base = full[:idx_info].rstrip()
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

# ═══ INFO ═══
with open(os.path.join(DIR, "info.html"), "r", encoding="utf-8") as f:
    info_html = f.read()
with open(os.path.join(DIR, "info_script.js"), "r", encoding="utf-8") as f:
    info_script = f.read()

full_info = info_html.replace("</body>", f"<script>\n{info_script}\n</script>\n</body>")
full_info_escaped = escape_for_template(full_info)

# Собираем
output = base
output += "\n\n// ===== Встроенная карта (Telegram Web App) =====\nconst MAP_HTML = `" + full_map_escaped + "`;\n"
output += "\n// ===== Инфографика — открытые данные Нижневартовска =====\nconst INFO_HTML = `" + full_info_escaped + "`;\n"

with open(os.path.join(DIR, "worker.js"), "w", encoding="utf-8") as f:
    f.write(output)

lines = output.count('\n')
print(f"worker.js: {len(output)} chars, ~{lines} lines")
