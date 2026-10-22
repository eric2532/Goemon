#!/usr/bin/env python3
"""Build the user-selected Dragon Leap landing: thud + spear pierce + attack.
Usage: python3 tools/build_dragoon_landing_audio.py /path/to/landing-source.wav
Source: https://www.youtube.com/watch?v=FW4tiK_N9kc (Celestial SFX).
"""
import array
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
import wave

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'assets/rogue/audio'
SOURCE = Path(sys.argv[1])
RATE = 48000
EVENTS = [(1.16, 1.58), (2.84, 3.50), (4.36, 5.55),
          (6.465, 7.31), (8.31, 8.75), (10.10, 10.72)]


def decode(path, start=0, duration=None, filters='anull'):
    cmd = ['ffmpeg', '-v', 'error', '-ss', str(start), '-i', str(path)]
    if duration is not None:
        cmd += ['-t', str(duration)]
    cmd += ['-af', filters, '-ar', str(RATE), '-ac', '2', '-f', 'f32le', 'pipe:1']
    result = subprocess.run(cmd, capture_output=True, check=True)
    values = array.array('f'); values.frombytes(result.stdout)
    return values


def save(name, values, peak_db):
    peak = max(abs(v) for v in values)
    assert peak > .001, name
    gain = 10 ** (peak_db / 20) / peak
    frames = len(values) // 2
    pcm = array.array('h')
    for i, v in enumerate(values):
        frame = i // 2
        fade = max(0, min(1, frame / (RATE * .002), (frames - 1 - frame) / (RATE * .025)))
        pcm.append(round(max(-1, min(1, v * gain * fade)) * 32767))
    path = DEST / (name + '.wav')
    with wave.open(str(path), 'wb') as out:
        out.setnchannels(2); out.setsampwidth(2); out.setframerate(RATE); out.writeframes(pcm.tobytes())
    return {'file': path.name, 'duration_seconds': round(frames / RATE, 5),
            'peak_dbfs': round(20 * math.log10(max(abs(v) for v in pcm) / 32767), 2),
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}


start, end = EVENTS[3]
landing = save('landing-dragoon', decode(SOURCE, start, end - start, 'highpass=f=65,lowpass=f=10000'), -10)
layers = [
    {'file': 'landing-dragoon.wav', 'role': 'Landing body / ground impact', 'gain': 1.0, 'offset_seconds': 0},
    {'file': 'thrust-dragoon-2.wav', 'role': 'Spear piercing impact', 'gain': .65, 'offset_seconds': .008},
    {'file': 'sweep-dragoon.wav', 'role': 'Lance attack / air cut', 'gain': .45, 'offset_seconds': .016},
]
values = [(layer, decode(DEST / layer['file'])) for layer in layers]
size = max(len(v) + round(layer['offset_seconds'] * RATE) * 2 for layer, v in values)
mix = array.array('f', [0]) * size
for layer, samples in values:
    offset = round(layer['offset_seconds'] * RATE) * 2
    for i, v in enumerate(samples):
        mix[offset + i] += v * layer['gain']
impact = save('landing-strike-dragoon', mix, -7.5)
manifest = {
    'title': 'Landing Sound Effects', 'channel': 'Celestial SFX',
    'source_url': 'https://www.youtube.com/watch?v=FW4tiK_N9kc', 'retrieved_on': '2026-10-17',
    'source_wav_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
    'source_effect_count': 6, 'source_effect_windows_seconds': EVENTS,
    'selected_effect': 4, 'selected_seconds': [start, end],
    'usage': 'Dragoon Dragon Leap: one three-layer strike at actual landing contact; normal jumps and grounded sweep unchanged.',
    'processing': 'Landing: 65 Hz high-pass / 10 kHz low-pass, 2 ms / 25 ms fades, -10 dBFS peak. Composite: thud, existing spear pierce and lance sweep at 0/8/16 ms, -7.5 dBFS final peak. Stereo 48 kHz PCM16, no looping. Native landing voice/take routing retained.',
    'license': 'Not established by download; user supplied this source for the prototype.',
    'generator': 'tools/build_dragoon_landing_audio.py',
    'landing': landing, 'impact': impact,
    'layers': [dict(layer, sha256=hashlib.sha256((DEST / layer['file']).read_bytes()).hexdigest()) for layer in layers],
    'existing_spear_source_manifest': 'dragoon_spear.source.json',
}
(DEST / 'dragoon_landing.source.json').write_text(json.dumps(manifest, indent=2) + '\n')
print(json.dumps(manifest, indent=2))
