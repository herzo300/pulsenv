import os
import io
import logging
import urllib.request
import urllib.parse

logger = logging.getLogger("SopranoTTS")

class SopranoTTSService:
    _instance = None
    _model = None

    @classmethod
    def get_instance(cls):
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    def __init__(self):
        os.environ["NO_PROXY"] = "*"
        os.environ["no_proxy"] = "*"

    def _init_model(self):
        if self._model is not None:
            return
        
        try:
            logger.info("Initializing Soprano TTS engine...")
            from soprano import SopranoTTS
            self._model = SopranoTTS(backend='auto', device='cpu')
            logger.info("Soprano TTS model loaded successfully.")
        except Exception as e:
            logger.warning(f"Soprano TTS direct package load info: {e}")

    def generate_wav(self, text: str, category: str = "ЧП") -> bytes:
        """
        Generates high quality audio for emergency (ЧП) and events (Мероприятия)
        using Soprano TTS ultra-realistic speech engine.
        Fallback to local Silero TTS / Google TTS if Soprano model is downloading or uninitialized.
        """
        os.environ["NO_PROXY"] = "*"
        os.environ["no_proxy"] = "*"

        # 1. Try Soprano python module
        try:
            self._init_model()
            if self._model is not None:
                logger.info(f"Synthesizing Soprano TTS for category '{category}': {text[:40]}...")
                audio_data = self._model.infer(text)
                if isinstance(audio_data, bytes):
                    return audio_data
                elif hasattr(audio_data, "tobytes"):
                    buffer = io.BytesIO()
                    buffer.write(audio_data.tobytes())
                    buffer.seek(0)
                    return buffer.read()
        except Exception as exc:
            logger.warning(f"Soprano TTS synthesis exception: {exc}")

        # 2. Try local Soprano HTTP endpoint (if soprano server / CLI is running)
        try:
            req_data = urllib.parse.urlencode({"input": text}).encode('utf-8')
            req = urllib.request.Request(
                "http://127.0.0.1:8000/v1/audio/speech",
                data=req_data,
                headers={"Content-Type": "application/x-www-form-urlencoded"}
            )
            with urllib.request.urlopen(req, timeout=5) as response:
                if response.status == 200:
                    return response.read()
        except Exception:
            pass

        # 3. Fallback to local Silero TTS (kseniya female voice) for seamless reliability
        try:
            logger.info(f"Using high-clarity voice fallback for category '{category}'")
            from services.Backend.services.silero_tts import SileroTTSService
            return SileroTTSService.get_instance().generate_wav(text)
        except Exception as e:
            logger.warning(f"Silero TTS fallback failed: {e}. Trying direct Google TTS...")

        # 4. Final direct Google Translate TTS fallback with proxy bypass
        import requests
        s = requests.Session()
        s.trust_env = False
        google_url = f"https://translate.google.com/translate_tts?ie=UTF-8&tl=ru&client=tw-ob&q={urllib.parse.quote(text)}"
        res = s.get(google_url, timeout=8)
        if res.status_code == 200:
            return res.content
        raise RuntimeError("All TTS backends failed")
