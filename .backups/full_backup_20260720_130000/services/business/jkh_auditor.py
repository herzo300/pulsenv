# services/business/jkh_auditor.py
import logging
import base64
import json
import os
import re
from datetime import datetime
from services.ai.zai_service import generate_text_using_llm
from services.Backend.routers.vlm import describe_frame

logger = logging.getLogger(__name__)

# Official 2026 Nizhnevartovsk residential utilities tariffs (Jan 1 - Sep 30, 2026)
TARIFFS_2026 = {
    "hvs": 62.66,          # Cold water (rub / m3)
    "vodootvedenie": 67.98, # Sewage (rub / m3)
    "heating": 2453.10,     # Heating (rub / Gcal)
    "tko": 997.84,          # Waste management per m3
}

async def audit_jkh_receipt(image_bytes: bytes) -> dict:
    """Analyze utilities receipt image, extract tariffs, compare with official thresholds, and build claims."""
    logger.info("Starting JKH Receipt Audit via Vision LLM...")
    
    # Encode image to Base64 for the Vision API
    img_b64 = base64.b64encode(image_bytes).decode("utf-8")
    
    # 1. Ask Vision LLM to extract JSON data from receipt image
    prompt = (
        "Ты — профессиональный аудитор квитанций ЖКХ в Российской Федерации. "
        "Внимательно изучи приложенное изображение квитанции ЖКХ и найди в ней тарифы (цену за единицу ресурса) "
        "для следующих коммунальных услуг: ХВС (холодное водоснабжение / питьевая вода), "
        "водоотведение (канализация) и отопление (тепловая энергия).\n\n"
        "Выдай результат СТРОГО в формате JSON без какого-либо дополнительного текста, в следующем виде:\n"
        "{\n"
        "  \"hvs_rate\": 0.0,\n"
        "  \"vodootvedenie_rate\": 0.0,\n"
        "  \"heating_rate\": 0.0,\n"
        "  \"total_sum\": 0.0,\n"
        "  \"detected_address\": \"адрес из квитанции\",\n"
        "  \"detected_uk\": \"название УК или ТСЖ\"\n"
        "}\n"
        "Если какой-то тариф не найден на изображении, укажи для него значение 0.0."
    )
    
    try:
        # Use describe_frame (which routes to Gemini 2.5 Flash on OpenRouter)
        from services.ai.zai_service import generate_text_using_llm
        
        # Prepare content payload with image
        api_key = (
            os.getenv("openrouter_api_key")
            or os.getenv("OPENROUTER_API_KEY")
            or os.getenv("GEMMA_CLOUD_API_KEY")
            or os.getenv("OPENAI_API_KEY")
        )
        api_base = os.getenv("OPENAI_BASE_URL", "https://openrouter.ai/api/v1")
        
        if not api_key:
            return {"error": "API key for audit is not configured."}
            
        import httpx
        headers = {
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        }
        payload = {
            "model": "google/gemini-2.5-flash",
            "messages": [
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": prompt},
                        {
                            "type": "image_url",
                            "image_url": {"url": f"data:image/jpeg;base64,{img_b64}"},
                        },
                    ],
                }
            ],
            "temperature": 0.1,
            "response_format": {"type": "json_object"}
        }
        
        async with httpx.AsyncClient(timeout=30) as client:
            resp = await client.post(f"{api_base}/chat/completions", json=payload, headers=headers)
            if resp.status_code != 200:
                logger.error(f"Audit API error: {resp.status_code} {resp.text}")
                return {"error": f"Failed to connect to audit engine (Status: {resp.status_code})"}
                
            result_data = resp.json()
            raw_json = result_data.get("choices", [{}])[0].get("message", {}).get("content", "{}")
            
        # Parse extracted JSON
        data = json.loads(raw_json)
        
        hvs_rate = float(data.get("hvs_rate", 0.0))
        vod_rate = float(data.get("vodootvedenie_rate", 0.0))
        heat_rate = float(data.get("heating_rate", 0.0))
        total_sum = float(data.get("total_sum", 0.0))
        address = data.get("detected_address", "Нижневартовск")
        uk_name = data.get("detected_uk", "Управляющая компания")
        
        # 2. Compare with official tariffs
        audit_passed = True
        overpaid_amount = 0.0
        details = []
        
        # Check HVS
        if hvs_rate > 0.0:
            threshold = TARIFFS_2026["hvs"]
            if hvs_rate > threshold:
                audit_passed = False
                diff = hvs_rate - threshold
                overpaid_amount += diff * 10  # assume avg consumption of 10m3
                details.append(
                    f"⚠️ Превышение тарифа на ХВС: обнаружено {hvs_rate} руб./м³ при нормативе {threshold} руб./м³."
                )
            else:
                details.append(f"✅ Тариф на ХВС ({hvs_rate} руб./м³) в пределах нормы.")
                
        # Check Sewage (Водоотведение)
        if vod_rate > 0.0:
            threshold = TARIFFS_2026["vodootvedenie"]
            if vod_rate > threshold:
                audit_passed = False
                diff = vod_rate - threshold
                overpaid_amount += diff * 15  # assume avg consumption of 15m3
                details.append(
                    f"⚠️ Превышение тарифа на водоотведение: обнаружено {vod_rate} руб./м³ при нормативе {threshold} руб./м³."
                )
            else:
                details.append(f"✅ Тариф на водоотведение ({vod_rate} руб./м³) в пределах нормы.")
                
        # Check Heating (Отопление)
        if heat_rate > 0.0:
            threshold = TARIFFS_2026["heating"]
            if heat_rate > threshold:
                audit_passed = False
                diff = heat_rate - threshold
                overpaid_amount += diff * 1.5  # assume avg consumption of 1.5 Gcal
                details.append(
                    f"⚠️ Превышение тарифа на отопление: обнаружено {heat_rate} руб./Гкал при нормативе {threshold} руб./Гкал."
                )
            else:
                details.append(f"✅ Тариф на отопление ({heat_rate} руб./Гкал) в пределах нормы.")

        # 3. Generate Claim Text if overpaid
        claim_text = ""
        if not audit_passed:
            claim_text = (
                f"Руководителю {uk_name}\n"
                f"Адрес: {address}\n"
                f"От: Собственника квартиры\n\n"
                f"ПРЕТЕНЗИЯ\n"
                f"о проведении перерасчета в связи с завышением тарифов ЖКХ\n\n"
                f"На основании квитанции за коммунальные услуги, по моему адресу начисления произведены по завышенным тарифам, "
                f"превышающим официально установленные тарифы РСТ ХМАО-Югры на 2026 год для г. Нижневартовска:\n"
            )
            for d in details:
                if "Превышение" in d:
                    claim_text += f"- {d}\n"
            claim_text += (
                f"\nВ соответствии с ч. 11 ст. 156 ЖК РФ и Постановлением Правительства РФ № 354, требую провести проверку правильности начислений, "
                f"произвести перерасчет платы за коммунальные услуги и выплатить штраф в размере 50% от величины превышения на мой лицевой счет.\n\n"
                f"Дата: {datetime.now().strftime('%d.%m.%Y')}\n"
                f"Подпись: ______________"
            )
        else:
            claim_text = "Все проверенные тарифы соответствуют закону. Нарушений не обнаружено."

        return {
            "audit_passed": audit_passed,
            "overpaid_amount": round(overpaid_amount, 2),
            "details": details,
            "claim_text": claim_text,
            "detected_address": address,
            "detected_uk": uk_name,
            "tariffs_extracted": {
                "hvs": hvs_rate,
                "vodootvedenie": vod_rate,
                "heating": heat_rate
            }
        }
    except Exception as e:
        logger.error(f"Error parsing receipt during audit: {e}")
        return {"error": f"Failed to analyze receipt structure: {str(e)}"}
