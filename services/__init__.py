def get_coordinates(address):
    from services.geo_service import get_coordinates as _gc
    return _gc(address)

def make_street_view_url(lat, lng):
    from services.geo_service import make_street_view_url as _msv
    return _msv(lat, lng)

def analyze_complaint(text):
    from services.zai_service import analyze_complaint as _ac
    return _ac(text)

def cluster_complaints(reports):
    from services.cluster_service import cluster_complaints as _cc
    return _cc(reports)

def get_ai_proxy(provider):
    from services.ai_proxy_service import get_ai_proxy as _gap
    return _gap(provider)

__all__ = [
    'get_coordinates',
    'make_street_view_url',
    'analyze_complaint',
    'cluster_complaints',
    'get_ai_proxy',
]
