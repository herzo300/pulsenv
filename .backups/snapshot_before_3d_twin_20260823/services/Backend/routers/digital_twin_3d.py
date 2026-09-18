"""
services/Backend/routers/digital_twin_3d.py — FastAPI Router for 3D Digital Twin of Nizhnevartovsk
Exposes 3D building extrusions, landmarks, camera FOV frustums, Sentinel-2 metadata, and Ob flood simulation.
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
    Simulates Ob River flood extent and inundated areas based on ArcticDEM terrain model.
    """
    result = simulate_ob_flood_layer(water_level_cm=water_level_cm)
    return {
        "status": "ok",
        "data": result,
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
        "digital_twin_readiness": "100%",
    }
