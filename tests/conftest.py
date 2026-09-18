"""Shared pytest fixtures and environment defaults."""

import os
import tempfile
from pathlib import Path

# Must be set before importing modules that load services.data_layer.auth
_test_db_path = Path(tempfile.gettempdir()) / f"soobshio_pytest_{os.getpid()}.db"
if _test_db_path.exists():
    _test_db_path.unlink()

os.environ.setdefault("JWT_SECRET", "test-jwt-secret-for-pytest-only-32chars")
os.environ["DATABASE_URL"] = f"sqlite:///{_test_db_path.as_posix()}"
os.environ.setdefault("DB_AUTO_CREATE", "true")
os.environ.setdefault("ADMIN_API_TOKEN", "test-admin-token-for-pytest")
os.environ.setdefault("REPORT_RETENTION_CLEANUP_ENABLED", "false")
os.environ.setdefault("PRODUCTION", "false")
os.environ["TG_AUTO_START_MONITOR"] = "false"

import pytest


@pytest.fixture(scope="session", autouse=True)
def _ensure_fresh_schema():
    """Drop and recreate tables so the schema matches current models."""
    from services.data_layer.database import Base, engine

    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)
    if _test_db_path.exists():
        try:
            _test_db_path.unlink()
        except OSError:
            pass


@pytest.fixture(scope="module")
def client():
    from fastapi.testclient import TestClient

    from services.Backend.app import app

    with TestClient(app) as test_client:
        yield test_client


@pytest.fixture(autouse=True)
def mock_generate_text_using_llm(monkeypatch):
    from services.ai import zai_service
    async def mock_generate(*args, **kwargs):
        return '{"template": "sad-keanu", "top_text": "Mock top text", "bottom_text": "Mock bottom text", "explanation": "Mock explanation"}'
    monkeypatch.setattr(zai_service, "generate_text_using_llm", mock_generate)

    # Mock geocode and reverse_geocode to prevent Nominatim/Photon HTTP blocks
    from services.business import geo_service
    async def mock_reverse_geocode(lat, lon):
        return "ул. Ленина, д. 10"
    async def mock_get_coordinates(address, *args, **kwargs):
        return 60.93, 76.55
    monkeypatch.setattr(geo_service, "reverse_geocode", mock_reverse_geocode)
    monkeypatch.setattr(geo_service, "get_coordinates", mock_get_coordinates)


