from fastapi import FastAPI, Depends, HTTPException
from pydantic import BaseModel
from backend.database import SessionLocal
from backend.models import Report
from services.zai_service import analyze_complaint
from typing import Any, Dict

app = FastAPI(title="Soobshio Backend")


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@app.get("/")
def root():
    return {"status": "OK"}


@app.get("/health")
def health_check():
    return {"status": "ok"}


class AnalyzeRequest(BaseModel):
    text: str


class AnalyzeResponse(BaseModel):
    category: str
    summary: str


@app.post("/ai/analyze")
async def analyze_text(request: AnalyzeRequest):
    """
    AI анализ текста через Zai GLM-4.7
    """
    try:
        result = await analyze_complaint(request.text)
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/reports")
def get_reports():
    return {"reports": []}
