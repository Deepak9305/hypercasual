"""Create original quiet game audio from deterministic synthesis (no third-party samples)."""
import math
import random
import struct
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "audio"
RATE = 22050

def write(name, seconds, render):
    count = int(seconds * RATE)
    samples = []
    for i in range(count):
        t = i / RATE
        v = max(-0.95, min(0.95, render(t, seconds)))
        samples.append(struct.pack("<h", int(v * 32767)))
    with wave.open(str(OUT / f"{name}.wav"), "wb") as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(b"".join(samples))

def tone(t, f, decay=8):
    return math.sin(t * f * 2 * math.pi) * math.exp(-t * decay)

OUT.mkdir(parents=True, exist_ok=True)
write("tap", 0.12, lambda t, d: tone(t, 740, 38) * 0.25)
write("place", 0.3, lambda t, d: (tone(t, 620, 15) + tone(t, 930, 18)) * 0.2)
write("invalid", 0.18, lambda t, d: tone(t, 180, 20) * 0.3)
write("bounce", 0.45, lambda t, d: math.sin(2 * math.pi * (200*t + 250*t*t)) * math.exp(-t*10) * 0.4)
write("freeze", 0.8, lambda t, d: (math.sin(2*math.pi*(1000*t-490*t*t)) + math.sin(2*math.pi*1600*t)*0.25) * math.sin(math.pi*t/d) * 0.23)
write("resume", 0.55, lambda t, d: math.sin(2*math.pi*(220*t+680*t*t)) * math.sin(math.pi*t/d) * 0.3)
notes = [523.25, 659.25, 783.99, 1046.5]
write("success", 1.5, lambda t, d: sum(tone(t-i*0.18, f, 6)*0.22 for i,f in enumerate(notes) if t>=i*0.18))
write("failure", 0.65, lambda t, d: math.sin(2*math.pi*(350*t-150*t*t)) * math.exp(-t*6) * 0.28)
chords = [(261.63,329.63,392), (220,261.63,329.63), (174.61,220,261.63), (196,246.94,293.66)]
def ambient(t, duration):
    chord = chords[int(t//4)%4]
    section_t = t%4
    env = math.sin(math.pi*section_t/4)**2
    pad = sum(math.sin(2*math.pi*f*t)*0.055 for f in chord) * env
    note_index = int(t*2)
    note_t = t-note_index/2
    bell = tone(note_t, chord[note_index%3]*2, 7)*0.06
    fade = min(1, t/0.5, (duration-t)/0.5)
    return (pad+bell)*fade
write("ambient", 16, ambient)
print("Generated 9 original WAV assets.")

