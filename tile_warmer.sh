#!/bin/bash
# Tile warmer: prefetches city tiles (NV bbox) into nginx proxy cache.
# NV center: 60.9344, 76.5531. Bbox ~ [60.90..60.97] lat, [76.48..76.62] lng
# Zooms 11..15 cover city overview -> street level.
# Runs forever: warms once at start, then every 6h refreshes eviction-prone tiles.
set -u
BASE="http://localhost:8000"  # not used; direct nginx
NGINX="http://127.0.0.1"

# lat/lng -> tile x/y at zoom
tile_xy() {
  lat=$1; lng=$2; z=$3
  lat_rad=$(python3 -c "import math; print(math.radians($lat))")
  n=$(python3 -c "print(2**$z)")
  x=$(python3 -c "print(int(($lng+180.0)/360.0*$n))")
  y=$(python3 -c "import math; print(int((1.0-math.asinh(math.tan($lat_rad))/math.pi)/2.0*$n))")
  echo "$x $y"
}

warm_zoom() {
  z=$1
  read x1 y1 <<< $(tile_xy 60.9700 76.4800 $z)  # NW corner
  read x2 y2 <<< $(tile_xy 60.9000 76.6200 $z)  # SE corner
  count=0
  for style in day night voyager; do
    for ((x=x1; x<=x2; x++)); do
      for ((y=y1; y<=y2; y++)); do
        curl -s -o /dev/null --max-time 10 "$NGINX/tiles/$style/$z/$x/$y.png" &
        # limit parallelism to 8
        while [ "$(jobs -r | wc -l)" -ge 8 ]; do wait -n; done
        count=$((count+1))
      done
    done
  done
  wait
  echo "$(date) warmed z$z: $count tiles"
}

while true; do
  for z in 11 12 13 14; do
    warm_zoom $z
  done
  # z15 только day+night (voyager тяжёлый)
  z=15
  read x1 y1 <<< $(tile_xy 60.9700 76.4800 $z)
  read x2 y2 <<< $(tile_xy 60.9000 76.6200 $z)
  for style in day night; do
    for ((x=x1; x<=x2; x++)); do
      for ((y=y1; y<=y2; y++)); do
        curl -s -o /dev/null --max-time 10 "$NGINX/tiles/$style/$z/$x/$y.png" &
        while [ "$(jobs -r | wc -l)" -ge 8 ]; do wait -n; done
      done
    done
  done
  wait
  echo "$(date) warmed z15 (day+night)"
  sleep 21600  # 6h
done
