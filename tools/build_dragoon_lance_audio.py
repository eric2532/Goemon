#!/usr/bin/env python3
"""Build Dragoon's user-selected spear sounds from a decoded source WAV.

Usage: python3 tools/build_dragoon_lance_audio.py /path/to/source.wav
Source: https://www.youtube.com/watch?v=meRwEzTTneI (Spear).
Requires ffmpeg; produces stereo 48 kHz PCM16 assets and a source manifest.
"""
import array
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
import wave

RATE = 48000
ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets/rogue/audio"
SOURCE = Path(sys.argv[1])


def cut(start, end, tempo=1.0):
    result = subprocess.run([
        "ffmpeg", "-v", "error", "-ss", str(start), "-t", str(end-start),
        "-i", str(SOURCE), "-af", f"highpass=f=85,atempo={tempo}",
        "-ar", str(RATE), "-ac", "2", "-f", "f32le", "pipe:1",
    ], check=True, capture_output=True)
    values = array.array("f")
    values.frombytes(result.stdout)
    return values


def save(name, values, peak_db):
    peak = max(abs(value) for value in values)
    assert peak > 0.001, f"Silent source for {name}"
    gain = 10**(peak_db/20)/peak
    frames = len(values)//2
    pcm = array.array("h")
    for i, value in enumerate(values):
        frame = i//2
        fade = min(1, frame/(RATE*.003), (frames-1-frame)/(RATE*.025))
        pcm.append(round(max(-1, min(1, value*gain*fade))*32767))
    path = DEST / (name+".wav")
    with wave.open(str(path), "wb") as out:
        out.setnchannels(2)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(pcm.tobytes())
    return {"path": "audio/"+path.name, "duration_seconds": round(frames/RATE, 5),
            "peak_dbfs": round(20*math.log10(max(abs(v) for v in pcm)/32767), 2),
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


samples = []
for index, (start, end, tempo, peak) in enumerate([
    (1.092, 1.570, 1.15, -9.0),
    (1.906, 2.220, 1.05, -9.0),
    (4.567, 5.150, 1.20, -7.5),
]):
    record = save(f"thrust-dragoon-{index}", cut(start, end, tempo), peak)
    record.update(role=f"Left-click thrust {index+1}", source_seconds=[start, end], tempo=tempo)
    samples.append(record)

# One broad cleave follows the single sweep, rather than baking damage pulses.
layers = [
    {"source_seconds": [2.800, 3.140], "tempo": 1.10, "gain": .85, "offset_seconds": 0.0},
    {"source_seconds": [3.780, 4.060], "tempo": 1.10, "gain": .65, "offset_seconds": .008},
    {"source_seconds": [4.580, 5.100], "tempo": 1.40, "gain": .35, "offset_seconds": .015},
]
mix = array.array("f", [0.0]) * int(RATE*.7)*2
for layer in layers:
    values = cut(*layer["source_seconds"], layer["tempo"])
    offset = round(layer["offset_seconds"]*RATE)*2
    for i, value in enumerate(values):
        frame = i//2
        fade = min(1, frame/(RATE*.003), (len(values)//2-1-frame)/(RATE*.02))
        mix[offset+i] += value*layer["gain"]*fade
while len(mix)>2 and abs(mix[-1])+abs(mix[-2]) < .00003:
    del mix[-2:]
record = save("sweep-dragoon", mix, -7.5)
record.update(role="Right-click Azure Lance Sweep", layers=layers)
samples.append(record)
metadata = {
    "title": "Spear", "channel": "Sounds of the Stickman",
    "source_url": "https://www.youtube.com/watch?v=meRwEzTTneI",
    "retrieved_on": "2026-10-15", "source_wav_sha256": hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
    "usage": "Dragoon grounded left-click thrust combo and grounded right-click three-hit sweep",
    "processing": "Trimmed individual effects, 85 Hz high-pass, tempo adjusted without shifting pitch, 3 ms attack/25 ms tail fades, peak normalized to -9 or -7.5 dBFS; stereo 48 kHz PCM16. Sweep blends both cleaves and a quieter thrust at 0/.008/.015 seconds into one broad strike, released once at the first contact.",
    "generator": "tools/build_dragoon_lance_audio.py",
    "license": "Not established by this download; original video lists the source attributions below.",
    "original_video_sound_attributions": [
        "https://www.zapsplat.com/music/spear-thrown-and-stick-into-ground-version-4/",
        "https://www.zapsplat.com/music/spear-thrown-and-stick-into-ground-with-slight-vibration-of-the-wooden-spear-pole-on-impact-version-1/",
        "https://www.zapsplat.com/music/knife-slice-slash-skin-fleshy-wound-squelch-of-blood-and-guts-2/",
        "https://freesfx.co.uk/sfx/spear",
        "https://www.zapsplat.com/music/knife-slice-slash-skin-fleshy-wound-squelch-of-blood-and-guts-4/",
        "https://freesound.org/people/Pogotron/sounds/60835/",
        "https://www.zapsplat.com/page/2/?s=slash&post_type=music&sound-effect-category-id",
        "https://www.zapsplat.com/music/spear-thrown-and-stick-into-ground-with-slight-vibration-of-the-wooden-spear-pole-on-impact-version-5/",
    ],
    "samples": samples,
}
(DEST / "dragoon_spear.source.json").write_text(json.dumps(metadata, indent=2)+"\n")
print(json.dumps(samples, indent=2))
