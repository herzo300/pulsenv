"""Собирает worker.js: base + info.html + info_script.js -> INFO_HTML"""
import os

DIR = os.path.dirname(os.path.abspath(__file__))

# Читаем базу worker.js (всё до INFO_HTML)
with open(os.path.join(DIR, "worker.js"), "r", encoding="utf-8") as f:
    full = f.read()

# Обрезаем старый INFO_HTML если есть
marker = "\n// ===== Инфографика"
idx = full.find(marker)
if idx != -1:
    base = full[:idx].rstrip()
else:
    base = full.rstrip()

# Читаем info.html
with open(os.path.join(DIR, "info.html"), "r", encoding="utf-8") as f:
    html = f.read()

# Читаем info_script.js
with open(os.path.join(DIR, "info_script.js"), "r", encoding="utf-8") as f:
    script = f.read()

# Вставляем скрипт перед </body>
full_html = html.replace("</body>", f"<script>\n{script}\n</script>\n</body>")

# Экранируем для JS template literal
full_html = full_html.replace("\\", "\\\\")
full_html = full_html.replace("`", "\\`")
full_html = full_html.replace("${", "\\${")
full_html = full_html.replace("</script>", "<\\/script>")

# Собираем
output = base + "\n\n// ===== Инфографика — открытые данные Нижневартовска =====\nconst INFO_HTML = `" + full_html + "`;\n"

with open(os.path.join(DIR, "worker.js"), "w", encoding="utf-8") as f:
    f.write(output)

lines = output.count('\n')
print(f"worker.js: {len(output)} chars, ~{lines} lines")
