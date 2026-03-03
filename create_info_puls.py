import os

HTML_PATH = "c:/Soobshio_project/public/info.html"
JS_PATH = "c:/Soobshio_project/public/info_script_v2.js"
FUNC_DIR = "c:/Soobshio_project/supabase/functions/info-puls"

os.makedirs(FUNC_DIR, exist_ok=True)

with open(HTML_PATH, "r", encoding="utf-8") as f:
    html_content = f.read()

with open(JS_PATH, "r", encoding="utf-8") as f:
    js_content = f.read()

# Inline JS
html_content = html_content.replace('<script defer src="info_script_v2.js"></script>', f'<script>{js_content}</script>')
html_escaped = html_content.replace("`", "\\`").replace("${", "\\${")

# We use a very standard Deno.serve to avoid any header conflicts
ts_content = f"""
Deno.serve(async (req) => {{
  const html = `{html_escaped}`;
  
  return new Response(html, {{
    headers: {{
      "Content-Type": "text/html; charset=utf-8",
      "X-Content-Type-Options": "nosniff",
      "Cache-Control": "no-cache"
    }},
    status: 200
  }});
}});
"""

with open(os.path.join(FUNC_DIR, "index.ts"), "w", encoding="utf-8") as f:
    f.write(ts_content)

print(f"Edge function Info-Puls created at {FUNC_DIR}/index.ts")
