"""Reproduce the approved original building-placement WAVs; requires numpy.
No sampled recordings. Playback variations are authored, not pitch shifted.
"""
from pathlib import Path
import json
import wave
import numpy as np

OUT = Path(__file__).resolve().parents[1] / "assets/audio/building_placement"
SR = 48000


def noise(rng, n, low, high):
    frequency = np.fft.rfftfreq(n, 1 / SR)
    curve = (1 - np.exp(-(frequency / low) ** 4)) * np.exp(-(frequency / high) ** 4)
    signal = np.fft.irfft(np.fft.rfft(rng.normal(size=n)) * curve, n)
    return signal / max(np.std(signal), 1e-9)


def knock(rng, duration, weight):
    t = np.arange(round(duration * SR)) / SR
    attack = 1 - np.exp(-t / .0007)
    # Inharmonic, heavily damped modes: a solid contact, without a musical ring.
    frequencies = [118, 203, 361, 674, 1123, 1841] if weight else [184, 329, 571, 1043, 1687, 2671]
    modes = np.zeros_like(t)
    for i, frequency in enumerate(frequencies):
        decay = (.045 if weight else .029) / (1 + i * .38)
        f = frequency * rng.uniform(.96, 1.04)
        modes += (.6 ** i) * np.sin(2 * np.pi * f * t) * np.exp(-t / decay)
    modes *= .27 * attack
    body = noise(rng, len(t), 75 if weight else 125, 660 if weight else 960)
    body *= (.38 if weight else .28) * attack * np.exp(-t / (.040 if weight else .026))
    grain = noise(rng, len(t), 850, 3900)
    grain *= .15 * attack * np.exp(-t / .012)
    return modes + body + grain


def placement(kind, variant):
    heavy = kind == 'bunker'
    rng = np.random.default_rng(261022 + variant * 137 + (2000 if heavy else 0))
    duration = .54 if heavy else .39
    t = np.arange(round(duration * SR)) / SR
    signal = knock(rng, duration, heavy)
    # A very small second contact makes the structure feel seated on the ground.
    second = round((.023 if heavy else .018) * SR)
    tap = knock(rng, duration - second / SR, heavy)
    signal[second:second + len(tap)] += tap * (.20 if heavy else .14)
    # Irregular little stones settle, with diminishing force rather than a loop.
    count = 6 if heavy else 4
    for i in range(count):
        when = .065 + i * (.050 if heavy else .049) + rng.uniform(-.008, .008)
        start = round(when * SR)
        length = min(round(.060 * SR), len(t) - start)
        local = np.arange(length) / SR
        envelope = (1 - np.exp(-local / .0004)) * np.exp(-local / rng.uniform(.004, .010))
        grain = noise(rng, length, 420, rng.uniform(2300, 4400))
        grain += .25 * np.sin(2 * np.pi * rng.uniform(850, 2100) * local)
        signal[start:start + length] += grain * envelope * .13 * (.74 ** i)
    # A quiet close-up rubble shuffle connects the impacts.
    shuffle = noise(rng, len(t), 280, 2150)
    envelope = (1 - np.exp(-t / .030)) * np.exp(-t / (.12 if heavy else .080))
    signal += shuffle * envelope * (.045 if heavy else .032)
    signal = np.tanh(signal * 1.15)
    signal -= np.mean(signal)
    signal[:48] *= np.linspace(0, 1, 48)
    signal[-960:] *= np.linspace(1, 0, 960)
    # Keep generous headroom and a modest, stable loudness between variations.
    signal *= (.66 if heavy else .58) / np.max(np.abs(signal))
    return signal


def write(name, signal):
    path = OUT / (name + '.wav')
    assert np.all(np.isfinite(signal)) and np.max(np.abs(signal)) < .95
    pcm = np.rint(signal * 32767).astype('<i2')
    with wave.open(str(path), 'wb') as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(SR)
        stream.writeframes(pcm.tobytes())
    return {
        'file': path.name,
        'seconds': round(len(signal) / SR, 3),
        'peak_dbfs': round(float(20 * np.log10(np.max(np.abs(signal)))), 2),
        'rms_dbfs': round(float(20 * np.log10(np.sqrt(np.mean(signal ** 2)))), 2),
        'clipped_samples': int(np.sum(np.abs(pcm.astype(np.int32)) >= 32767)),
        'bytes': path.stat().st_size,
    }


if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    for kind in ['tower', 'bunker']:
        for i in range(3):
            print(json.dumps(write(f'{kind}-{i + 1}', placement(kind, i))))
