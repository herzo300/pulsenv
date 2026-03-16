import os
import torch
import uvicorn
from fastapi import FastAPI
from pydantic import BaseModel
from transformers import pipeline, AutoTokenizer, AutoModelForSequenceClassification

app = FastAPI(
    title="Local AI Module for Soobshio",
    description="Microservice for analyzing complaints locally using cointegrated/rubert-tiny2 based models",
    version="1.0.0"
)

# We use cointegrated/rubert-tiny-sentiment for sentiment analysis (urgency surrogate)
# And zero-shot-classification for category prediction (using a cross-encoder or NLI model)
# For max speed / lowest RAM, we can use an NLI tiny model 
MODEL_NLI = "cointegrated/rubert-tiny-bilingual-nli"
MODEL_SENTIMENT = "cointegrated/rubert-tiny2-cedr-emotion-rubert-base" 
# NOTE: cointegrated/rubert-tiny-sentiment or similar can be used, 
# here we use a simple pipeline for demonstration with rubert-tiny2 baseline

device = 0 if torch.cuda.is_available() else -1

print("Loading models...")
# Zero-shot classification (for categorizing complaints)
classifier = pipeline(
    "zero-shot-classification", 
    model=MODEL_NLI,
    device=device
)

# Using a standard sentiment model or emotion model to gauge 'urgency' or 'tone'
sentiment = pipeline(
    "text-classification", 
    model="cointegrated/rubert-tiny-sentiment", 
    device=device
)
print("Models loaded successfully!")

class ComplaintRequest(BaseModel):
    text: str

class ComplaintResponse(BaseModel):
    category: str
    category_confidence: float
    sentiment: str
    is_urgent: bool

CATEGORIES = [
    "ЖКХ и благоустройство",
    "Дороги и транспорт",
    "Экология и свалки",
    "Правопорядок",
    "Домашние и дикие животные",
    "Прочее"
]

@app.post("/analyze", response_model=ComplaintResponse)
def analyze_complaint(req: ComplaintRequest):
    # 1. Category Prediction
    cat_result = classifier(
        req.text,
        candidate_labels=CATEGORIES,
        hypothesis_template="Этот текст о теме {}."
    )
    top_category = cat_result['labels'][0]
    top_score = cat_result['scores'][0]
    
    # 2. Sentiment/Urgency Prediction
    sent_result = sentiment(req.text)[0]
    sent_label = sent_result['label']
    
    # Simple heuristic: if sentiment is negative or anger/fear, mark as urgent
    is_urgent = False
    if sent_label in ['negative']:
        is_urgent = True
        
    # Example heuristic for emergency keywords
    emergency_keywords = ["срочно", "пожар", "убивают", "помогите", "авария", "кровь", "труба прорвала"]
    if any(kw in req.text.lower() for kw in emergency_keywords):
        is_urgent = True

    return ComplaintResponse(
        category=top_category,
        category_confidence=top_score,
        sentiment=sent_label,
        is_urgent=is_urgent
    )

@app.get("/health")
def health_check():
    return {"status": "ok", "models_loaded": True}

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
