import os
import math
import struct
import wave

SAMPLE_RATE = 44100
AMPLITUDE = 16000

def generate_note(frequency, duration_sec, fade_out=True):
    num_samples = int(duration_sec * SAMPLE_RATE)
    data = bytearray()
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        envelope = (1.0 - (i / num_samples)) if fade_out else 1.0
        val = int(AMPLITUDE * envelope * math.sin(2 * math.pi * frequency * t))
        data.extend(struct.pack('<h', val))
    return data

def generate_chirp(start_freq, end_freq, duration_sec):
    num_samples = int(duration_sec * SAMPLE_RATE)
    data = bytearray()
    phase = 0.0
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        f = start_freq + (end_freq - start_freq) * (t / duration_sec)
        phase += 2 * math.pi * f / SAMPLE_RATE
        envelope = 1.0 - (t / duration_sec)
        val = int(AMPLITUDE * envelope * math.sin(phase))
        data.extend(struct.pack('<h', val))
    return data

def write_wav(filename, data):
    with wave.open(filename, 'wb') as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(SAMPLE_RATE)
        wav_file.writeframes(data)
    print(f"Generated clean synthesized sound at: {filename} (Size: {os.path.getsize(filename)} bytes)")

def main():
    # 1. menu_confirm: Double beep (880Hz -> 1320Hz)
    confirm_data = bytearray()
    confirm_data.extend(generate_note(880, 0.07))
    confirm_data.extend(generate_note(0, 0.02, fade_out=False)) # silence gap
    confirm_data.extend(generate_note(1320, 0.12))
    
    # 2. menu_notification: Gentle 3-tone chime (C5 -> E5 -> G5)
    notif_data = bytearray()
    notif_data.extend(generate_note(523.25, 0.12))
    notif_data.extend(generate_note(659.25, 0.12))
    notif_data.extend(generate_note(783.99, 0.25))
    
    # 3. splash_gravity: Radar sweep (220Hz -> 660Hz)
    splash_data = generate_chirp(220, 660, 1.5)
    
    # Targets list
    targets = [
        # Frontend assets
        ("services/Frontend/assets/audio/menu_confirm.mp3", confirm_data),
        ("services/Frontend/assets/audio/menu_notification.mp3", notif_data),
        ("services/Frontend/assets/audio/splash_gravity.mp3", splash_data),
        # Backend public assets
        ("public/sounds/menu_confirm.mp3", confirm_data),
        ("public/sounds/menu_notification.mp3", notif_data),
        ("public/sounds/splash_gravity.mp3", splash_data)
    ]
    
    for path, data in targets:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        write_wav(path, data)

if __name__ == "__main__":
    main()
