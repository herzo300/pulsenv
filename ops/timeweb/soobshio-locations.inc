# Shared location blocks for Soobshio nginx (HTTP + HTTPS)

location = /healthz {
    access_log off;
    default_type text/plain;
    return 200 "ok\n";
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

location / {
    try_files $uri $uri/ /index.html;
}
