#!/bin/sh
echo "=== core/ data layer ==="
ls /app/core/ | head -10
echo "=== models with visual/vip ==="
grep -rln "VisualSearchLog\|VipSubscription" /app/models/ /app/core/ 2>/dev/null | head -5
echo "=== how other routers import db ==="
grep -rn "SessionLocal" /app/services/Backend/routers/cameras.py | head -3
