import os

HTML_PATH = "c:/Soobshio_project/public/map.html"
JS_PATH = "c:/Soobshio_project/public/map_script.js"
FUNC_DIR = "c:/Soobshio_project/supabase/functions/map-app"

os.makedirs(FUNC_DIR, exist_ok=True)

with open(HTML_PATH, "r", encoding="utf-8") as f:
    html_content = f.read()

with open(JS_PATH, "r", encoding="utf-8") as f:
    js_content = f.read()

# Трюк: вставляем JS прямо в HTML
html_content = html_content.replace('<script defer src="map_script.js"></script>', f'<script>{js_content}</script>')

# Экранирование для TypeScript
html_escaped = html_content.replace("`", "\\`").replace("${", "\\${")

ts_content = f"""
Deno.serve(async (req) => {{
  // Принудительно возвращаем HTML с правильными заголовками
  return new Response(`{html_escaped}`, {{
    headers: {{
      "Content-Type": "text/html; charset=utf-8",
      "Access-Control-Allow-Origin": "*",
      "X-Content-Type-Options": "nosniff",
      "Cache-Control": "no-cache, no-store, must-revalidate"
    }},
    status: 200
  }});
}});
"""

with open(os.path.join(FUNC_DIR, "index.ts"), "w", encoding="utf-8") as f:
    f.write(ts_content)

print(f"Edge function for Map FIXED at {FUNC_DIR}/index.ts")
