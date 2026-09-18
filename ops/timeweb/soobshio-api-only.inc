# API-only subset of soobshio-locations.inc for the plain-HTTP server block
# (no `location /` here — the HTTP block keeps its own catch-all redirect).
# `resolver` is required because nginx resolves the docker DNS name at request
# time when set via a variable.

resolver 127.0.0.11 ipv6=off valid=30s;

# Реальные фото города для онбординга (отдаются и по HTTP)
location ~ ^/(onboard_city_[0-9]+\.jpg|twin_hero\.jpg)$ {
    root /usr/share/nginx/html;
    expires 1d;
    add_header Cache-Control "public, max-age=86400";
}

location /static/uploads/ {
    alias /var/www/soobshio/uploads/;
    expires 7d;
    add_header Cache-Control "public, max-age=604800";
}

location ~ ^/(api|health|config|storage|complaints|categories|ai|map|infographic|cameras|vip-search|city-dashboard|digital-twin|3d|telegram|osint|opendata|payments|vlm|viptask|profile|prize-fund|agent|runtime|reports|dispatcher|daily-digest)(/|$) {
    set $backend_upstream http://backend:8000;
    proxy_pass $backend_upstream;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_read_timeout 300s;
}
