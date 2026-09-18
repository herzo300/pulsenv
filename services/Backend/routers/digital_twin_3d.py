"""
services/Backend/routers/digital_twin_3d.py — FastAPI Router for Next-Gen 3D/4D Digital Twin of Nizhnevartovsk
Exposes 3D building extrusions, landmarks, camera FOV frustums, Ob flood simulation,
solar shadow simulator, snow drift intelligence, Samotlor flares, and 4D timeline.
"""
from typing import Optional
from fastapi import APIRouter, Query
from services.Backend.services.geo.twin_3d_engine import (
    NV_BBOX,
    NV_CENTER,
    NV_LANDMARKS,
    generate_nizhnevartovsk_3d_buildings_geojson,
    simulate_ob_flood_layer,
    get_3d_camera_frustums,
    calculate_sun_and_shadows,
    get_snow_intelligence_layers,
    get_samotlor_flares_and_fire_ring,
    get_4d_timeline_snapshots,
)

router = APIRouter(prefix="/api/v1/3d-twin", tags=["3D Digital Twin"])


@router.get("/buildings")
async def get_3d_buildings(
    min_lat: Optional[float] = Query(None, description="Bounding box min latitude"),
    min_lng: Optional[float] = Query(None, description="Bounding box min longitude"),
    max_lat: Optional[float] = Query(None, description="Bounding box max latitude"),
    max_lng: Optional[float] = Query(None, description="Bounding box max longitude"),
):
    """
    Returns 3D Extrusion GeoJSON for Nizhnevartovsk buildings with imputed heights and levels.
    """
    bbox = None
    if min_lat is not None and min_lng is not None and max_lat is not None and max_lng is not None:
        bbox = {
            "min_lat": float(min_lat),
            "min_lng": float(min_lng),
            "max_lat": float(max_lat),
            "max_lng": float(max_lng),
        }
    geojson_data = generate_nizhnevartovsk_3d_buildings_geojson(bbox=bbox)
    return geojson_data


@router.get("/landmarks")
async def get_3d_landmarks():
    """
    Returns high-fidelity 3D landmark architectural objects in Nizhnevartovsk.
    """
    return {
        "status": "ok",
        "count": len(NV_LANDMARKS),
        "items": NV_LANDMARKS,
    }


@router.get("/cameras-3d")
async def get_3d_cameras():
    """
    Returns 3D viewing cones (FOV frustums) for city monitoring cameras.
    """
    cameras = get_3d_camera_frustums()
    return {
        "status": "ok",
        "count": len(cameras),
        "items": cameras,
    }


@router.get("/flood-simulation")
async def get_flood_simulation(
    water_level_cm: float = Query(850.0, ge=500.0, le=1100.0, description="Ob river water gauge level in cm")
):
    """
    Simulates Ob River flood extent, affected СОНТ/districts, and evacuation corridors.
    """
    result = simulate_ob_flood_layer(water_level_cm=water_level_cm)
    return {
        "status": "ok",
        "data": result,
    }


@router.get("/solar-shadows")
async def get_solar_shadows(
    date: Optional[str] = Query("2026-06-21", description="Date YYYY-MM-DD"),
    hour: float = Query(14.0, ge=0.0, le=24.0, description="Local hour in UTC+5")
):
    """
    Calculates low-sun astronomical solar angles and courtyard insolation/shadow vectors at 60.94°N.
    """
    result = calculate_sun_and_shadows(date_str=date, hour_utc5=hour)
    return {
        "status": "ok",
        "data": result,
    }


@router.get("/snow-intelligence")
async def get_snow_intelligence():
    """
    Returns ArcticDEM drift-risk zones, snow dump sites, and prioritized municipal clearing routes.
    """
    result = get_snow_intelligence_layers()
    return result


@router.get("/samotlor-flares")
async def get_samotlor_flares():
    """
    Returns Sentinel-2 SWIR flare thermal signatures and wildfire buffer ring status.
    """
    result = get_samotlor_flares_and_fire_ring()
    return result


@router.get("/timeline-4d")
async def get_4d_timeline():
    """
    Returns 4D historical time-machine snapshots of urban growth in Nizhnevartovsk (2015-2026).
    """
    snapshots = get_4d_timeline_snapshots()
    return {
        "status": "ok",
        "count": len(snapshots),
        "snapshots": snapshots,
    }


@router.get("/layers-config")
async def get_layers_config():
    """
    Returns map layer endpoints and styling parameters for 3D MapLibre & Cesium renderers.
    """
    return {
        "status": "ok",
        "center": NV_CENTER,
        "default_zoom": 14.5,
        "default_pitch": 55.0,
        "default_bearing": 20.0,
        "bbox": NV_BBOX,
        "satellite": {
            "name": "Sentinel-2 True Color",
            "mgrs_tile": "T43VBN",
            "resolution_m": 10.0,
            "acquisition_window": "Summer 2026",
            "url_template": "https://tiles.citypulse-nv.ru/satellite/{z}/{x}/{y}.png",
        },
        "elevation": {
            "name": "ArcticDEM 2m / Copernicus GLO-30",
            "type": "terrain-rgb",
            "encoding": "terrarium",
            "url_template": "https://tiles.citypulse-nv.ru/terrain/{z}/{x}/{y}.png",
        },
        "vector_buildings": {
            "name": "Nizhnevartovsk 3D Buildings",
            "type": "fill-extrusion",
            "endpoint": "/api/v1/3d-twin/buildings",
            "height_property": "render_height",
            "base_property": "render_min_height",
            "color_property": "color",
        },
    }


@router.get("/buildings-rev")
async def get_buildings_revision():
    """Ревизия реестра зданий для клиентского кэширования (автообновление тайлов)."""
    import json as _json
    import os as _os

    for p in ("data/twin_buildings_osm.json", "/app/data/twin_buildings_osm.json"):
        if _os.path.exists(p):
            try:
                fc = _json.load(open(p, encoding="utf-8"))
                props = fc.get("properties", {})
                sync = props.get("hermes_sync", {})
                rev = _os.path.getmtime(p)
                return {
                    "status": "ok",
                    "revision": int(rev),
                    "total_buildings": props.get("total_buildings", len(fc.get("features", []))),
                    "last_sync": sync.get("last_run"),
                }
            except Exception as exc:
                return {"status": "error", "message": str(exc)}
    return {"status": "error", "message": "registry not found"}


@router.post("/hermes-twin-sync")
async def trigger_hermes_twin_sync():
    """Ручной запуск цикла Гермеса «Строитель двойника» (для теста/админа)."""
    from services.business.hermes_twin_builder import sync_twin_buildings

    return await sync_twin_buildings()


@router.get("/landscape")
async def get_landscape():
    """
    Ландшафт долины Оби для 3D-двойника:
    зеркало реки (реальные контуры), линия русла, озёра/старицы, болота, лес,
    DEM-профиль и калибровка уровней затопления по гидропосту Нижневартовск.
    """
    import json as _json
    import os as _os

    for p in ("data/nv_landscape.json", "/app/data/nv_landscape.json"):
        if _os.path.exists(p):
            try:
                data = _json.load(open(p, encoding="utf-8"))
                # не отдаём DEM-картинку в JSON — она отдельным эндпоинтом
                data.pop("dem", None)
                return {"status": "ok", **data}
            except Exception as exc:
                return {"status": "error", "message": str(exc)}
    return {"status": "error", "message": "landscape pack not built"}


@router.get("/landscape/dem")
async def get_landscape_dem():
    """DEM-тайл (terrarium PNG) вокруг города для симуляции затопления."""
    from fastapi import Response

    for p in ("data/nv_dem.png", "/app/data/nv_dem.png"):
        import os as _os
        if _os.path.exists(p):
            data = open(p, "rb").read()
            return Response(content=data, media_type="image/png",
                            headers={"Cache-Control": "public, max-age=86400"})
    return {"status": "error", "message": "dem not built"}


@router.get("/landscape/meta")
async def get_landscape_meta():
    """Метаданные DEM-сетки (bbox/zoom) для привязки пикселей к координатам."""
    import json as _json
    import os as _os

    for p in ("data/nv_dem_meta.json", "/app/data/nv_dem_meta.json"):
        if _os.path.exists(p):
            return {"status": "ok", **_json.load(open(p, encoding="utf-8"))}
    return {"status": "error", "message": "dem meta not found"}


@router.get("/stats")
async def get_twin_stats():
    """
    Returns summary statistics for the Nizhnevartovsk 3D Digital Twin.
    """
    geojson = generate_nizhnevartovsk_3d_buildings_geojson()
    features = geojson.get("features", [])
    total_buildings = len(features)
    landmarks_count = len(NV_LANDMARKS)
    avg_height = sum(f["properties"].get("render_height", 12.0) for f in features) / max(1, total_buildings)
    
    return {
        "status": "ok",
        "city": "Нижневартовск",
        "total_3d_buildings": total_buildings,
        "landmarks_count": landmarks_count,
        "average_height_m": round(avg_height, 1),
        "microdistricts_covered": 26,
        "terrain_resolution": "2m (ArcticDEM) / 30m (Copernicus GLO-30)",
        "satellite_basemap": "Sentinel-2 MSI Tile T43VBN (10m)",
        "ob_flood_model": "Active (500cm - 1100cm gauge range)",
        "solar_shadow_engine": "Active (60.9°N Polar Angles)",
        "snow_drift_engine": "Active (ArcticDEM Slope & Aspect)",
        "samotlor_swir_guardian": "Active (Sentinel-2 B11/B12)",
        "digital_twin_readiness": "100%",
    }
