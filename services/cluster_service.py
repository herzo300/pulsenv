# services/cluster_service.py
from typing import List, Dict, Any
import numpy as np
import hdbscan

EARTH_RADIUS_KM = 6371.0088

def cluster_complaints(
    complaints: List[Dict[str, Any]],
    min_cluster_size: int = 3,
    min_samples: int = 1,
) -> List[Dict[str, Any]]:
    """
    Кластеризация жалоб с использованием HDBSCAN (переменная плотность).
    complaints: список словарей с полями latitude / longitude.
    """
    data = []
    original = []

    for c in complaints:
        lat = c.get("latitude")
        lon = c.get("longitude")
        if lat is None or lon is None:
            continue
        data.append([np.radians(lat), np.radians(lon)])
        original.append(c)

    # HDBSCAN требует min_cluster_size >= 2
    if min_cluster_size < 2:
        min_cluster_size = 2
    
    if len(data) < min_cluster_size:
        return []

    data = np.array(data)

    clusterer = hdbscan.HDBSCAN(
        min_cluster_size=min_cluster_size,
        min_samples=min_samples,
        metric="haversine",
        cluster_selection_method="eom",
        allow_single_cluster=True,
    )

    labels = clusterer.fit_predict(data)

    clusters_dict: Dict[int, Dict[str, Any]] = {}

    for label, complaint in zip(labels, original):
        if label == -1:
            continue
        if label not in clusters_dict:
            clusters_dict[label] = {
                "cluster_id": int(label),
                "complaints": [],
                "lats": [],
                "lons": [],
            }
        clusters_dict[label]["complaints"].append(complaint)
        clusters_dict[label]["lats"].append(complaint["latitude"])
        clusters_dict[label]["lons"].append(complaint["longitude"])

    clusters: List[Dict[str, Any]] = []
    for cid, data in clusters_dict.items():
        lats = data["lats"]
        lons = data["lons"]
        center_lat = sum(lats) / len(lats)
        center_lon = sum(lons) / len(lons)
        clusters.append(
            {
                "cluster_id": cid,
                "center_lat": center_lat,
                "center_lon": center_lon,
                "complaints_count": len(data["complaints"]),
                "complaints": data["complaints"],
            }
        )

    return clusters
