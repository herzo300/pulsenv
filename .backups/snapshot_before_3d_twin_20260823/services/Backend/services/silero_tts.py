import os
import torch
import soundfile as sf
import io
import logging

logger = logging.getLogger("SileroTTS")

class SileroTTSService:
    _instance = None
    _model = None

    @classmethod
    def get_instance(cls):
        if cls._instance is None:
            cls._instance = cls()
        return cls._instance

    def _init_model(self):
        if self._model is not None:
            return
        
        # Override TORCH_HOME to an ASCII directory to avoid Cyrillic encoding crashes on Windows
        os.environ["TORCH_HOME"] = "c:/Soobshio_project/.cache/torch"
        os.environ["no_proxy"] = "*"
        os.environ["NO_PROXY"] = "*"

        logger.info("Initializing local Silero TTS model (v4_ru) Kseniya speaker...")
        device = torch.device('cpu')
        torch.set_num_threads(4)

        try:
            self._model, _ = torch.hub.load(
                repo_or_dir='snakers4/silero-models',
                model='silero_tts',
                language='ru',
                speaker='v4_ru',
                trust_repo=True,
                skip_validation=True
            )
            self._model.to(device)
            logger.info("Silero TTS model loaded successfully.")
        except Exception as e:
            logger.error(f"Failed to load Silero TTS model: {e}")
            raise e

    def generate_wav(self, text: str, speaker: str = "kseniya", sample_rate: int = 24000) -> bytes:
        self._init_model()
        
        # Synthesize audio
        audio = self._model.apply_tts(
            text=text,
            speaker=speaker,
            sample_rate=sample_rate
        )
        
        # Write to byte buffer as standard WAV PCM_16
        buffer = io.BytesIO()
        sf.write(buffer, audio.numpy(), sample_rate, format='WAV', subtype='PCM_16')
        buffer.seek(0)
        return buffer.read()
