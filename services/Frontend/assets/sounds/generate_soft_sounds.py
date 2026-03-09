import wave
import struct
import math

def generate_soft_splash(filename):
    sample_rate = 44100
    duration = 3.0  # seconds
    n_samples = int(sample_rate * duration)
    
    # Soft "Whoosh" + Sine sweep
    # Start with a very soft sine wave and fade in/out
    with wave.open(filename, 'w') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(sample_rate)
        
        for i in range(n_samples):
            t = i / sample_rate
            # Sine sweep from 300Hz to 150Hz
            freq = 300 - (150 * (t / duration))
            # Envelope: soft bell curve
            envelope = math.sin(math.pi * (t / duration)) ** 2
            
            sample = math.sin(2 * math.pi * freq * t) * envelope * 0.3
            
            # Add some white noise for "whoosh" effect (very soft)
            import random
            noise = (random.random() * 2 - 1) * 0.05 * envelope
            
            val = int((sample + noise) * 32767)
            wav.writeframesraw(struct.pack('<h', val))

def generate_soft_pulse(filename):
    sample_rate = 44100
    duration = 0.5  # seconds
    n_samples = int(sample_rate * duration)
    
    with wave.open(filename, 'w') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(sample_rate)
        
        for i in range(n_samples):
            t = i / sample_rate
            # 60Hz pulse
            freq = 60
            # Exponential decay
            envelope = math.exp(-6 * t)
            
            sample = math.sin(2 * math.pi * freq * t) * envelope * 0.4
            
            val = int(sample * 32767)
            wav.writeframesraw(struct.pack('<h', val))

def generate_soft_pop(filename):
    sample_rate = 44100
    duration = 0.15  # seconds
    n_samples = int(sample_rate * duration)
    
    with wave.open(filename, 'w') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(sample_rate)
        
        for i in range(n_samples):
            t = i / sample_rate
            # 800Hz to 400Hz quick sweep
            freq = 800 - (400 * (t / duration))
            # Exponential decay
            envelope = math.exp(-20 * t)
            
            sample = math.sin(2 * math.pi * freq * t) * envelope * 0.4
            
            val = int(sample * 32767)
            wav.writeframesraw(struct.pack('<h', val))

if __name__ == "__main__":
    generate_soft_splash(r'c:\Soobshio_project\services\Frontend\assets\sounds\soft_splash.wav')
    generate_soft_pulse(r'c:\Soobshio_project\services\Frontend\assets\sounds\soft_pulse.wav')
    generate_soft_pop(r'c:\Soobshio_project\services\Frontend\assets\sounds\soft_pop.wav')
    print("Files generated.")
