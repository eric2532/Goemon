"""Bake the retail B2C level-up sequence into one pooled playback cue."""
import array
import hashlib
import json
import shutil
import struct
import subprocess
import wave
from recover_monster_audio import ROOT, RECOVERY
from musashi_pitch import render_pitch


def main():
    out = ROOT / 'assets/audio/recovered_musashi'
    work = ROOT / 'build/Other Files/Asset Toolkit/Construction and Level Audio/Musashi'
    work.mkdir(parents=True, exist_ok=True)
    exe = (RECOVERY / 'raw/SLUS_007.26').read_bytes()
    base = struct.unpack_from('<I', exe, 24)[0]

    def read(address, size):
        offset = address - base + 0x800
        assert 0 <= offset <= len(exe) - size
        return exe[offset:offset + size]

    dispatch = read(0x8006451C + 0xB2C * 4, 4)
    assert dispatch == bytes.fromhex('85 00 00 10')
    descriptor = read(0x80068A54 + dispatch[3] * 12, 12)
    pointer = struct.unpack_from('<I', descriptor)[0]
    source = read(pointer, 80)
    # 8003388C: full note, three compact notes, then three fading repetitions.
    assert descriptor[8] == 0x10 and source[3] == 0x80
    assert struct.unpack_from('<I', source, 44)[0] == 0x82000003
    assert struct.unpack_from('<II', source, 72) == (0x85000A00, 0x87000000)
    notes = []
    tick = 0
    for offset, attenuation in [(0, 0), (20, 0), (28, 0), (36, 0)] + [
            (offset, repeat * 10) for repeat in range(3) for offset in (48, 56, 64)]:
        pitch, volume, opcode, gate, delay = struct.unpack_from('<HBBHH', source, offset)
        assert opcode == (0x80 if offset == 0 else 0x81) and gate > 0 and delay > 0
        notes.append(dict(tick=tick, pitch=pitch, volume=volume-attenuation, gate=gate))
        tick += delay
    assert [n['tick'] for n in notes] == [0, 2, 4, 6, 20, 22, 24, 38, 40, 42, 56, 58, 60]
    assert [n['pitch'] >> 8 for n in notes] == [50, 52, 57, 62] + [52, 57, 62] * 3
    assert [n['volume'] for n in notes] == [103] * 4 + [89] * 3 + [79] * 3 + [69] * 3
    assert source[8:12] == bytes([0, 26, 0, 0]) and source[16:20] == bytes(4)
    bank = next(b for b in json.loads((RECOVERY / 'media_manifest.json').read_text())
                if b.get('id') == 'bank_d8f2dc9eb7ed7287')
    lookup = struct.unpack('<I', read(0x80064D44, 4))[0]
    program, tone_index = read(lookup + source[9] * 2, 2)
    header = (RECOVERY / bank['header_path']).read_bytes()
    offset = 32 + 128 * 16 + program * 512 + tone_index * 32
    tone = header[offset:offset + 32]
    sample = bank['sample_list'][struct.unpack_from('<H', tone, 22)[0] - 1]
    decoded = work / 'level_up_sample.wav'
    subprocess.run([shutil.which('ffmpeg'), '-nostdin', '-v', 'error', '-y', '-i',
                    str(RECOVERY / 'converted/audio/samples_vag' / (sample['id'] + '.vag')),
                    '-c:a', 'pcm_s16le', str(decoded)], check=True)
    with wave.open(str(decoded)) as wav:
        assert wav.getnchannels() == 1 and wav.getsampwidth() == 2
        dry = wav.readframes(wav.getnframes())
    pitch_table = struct.unpack('<84H', read(0x8006AB30, 168))
    volume_table = struct.unpack('<128H', read(0x8006AA30, 256))
    mixed = [0.0] * (tick * 735)
    for note in notes:
        pcm = array.array('h', render_pitch(dry, note['pitch'], tone[4], [], pitch_table))
        count = min(len(pcm), note['gate'] * 735)
        gain = volume_table[note['volume']] / max(volume_table)
        for i in range(count):
            # Dry recovery uses a 3ms key-off fade to avoid truncation clicks.
            mixed[note['tick'] * 735 + i] += pcm[i] * gain * min(1, (count - i) / 132)
    assert max(map(abs, mixed)) < 32768 and max(map(abs, mixed)) > 1000
    path = out / 'level_up.wav'
    with wave.open(str(path), 'wb') as wav:
        wav.setnchannels(1); wav.setsampwidth(2); wav.setframerate(44100)
        wav.writeframes(array.array('h', (round(v) for v in mixed)).tobytes())
    report = dict(event='0xB2C', source_trace='8002A088 / 8002A2D4 / 8002A544 / 8002A7B4: successful body, mind, Lumina and Fusion level increases call 8002D4C8(B2C,0). 80034314 selects resident descriptor; 8003388C decodes notes and fading repeats.',
                  executable_sha256=hashlib.sha256(exe).hexdigest(), descriptor=descriptor.hex(),
                  sequence_address=hex(pointer), sequence_hex=source.hex(), notes=notes,
                  bank=bank['id'], bank_sha256=bank['sha256'], bank_sources=bank['sources'],
                  sample=sample, tone_hex=tone.hex(), program=program, tone=tone_index,
                  wav_sha256=hashlib.sha256(path.read_bytes()).hexdigest(), duration_seconds=len(mixed)/44100,
                  processing='Authentic decoded ADPCM, retail pitch/volume tables, note gates and 60Hz timing; one mono PCM16 cue. Dry adaptation uses a 3ms key-off fade; PS1 ADSR, Gaussian interpolation and reverb are not emulated.')
    (out / 'level_up_provenance.json').write_text(json.dumps(report, indent=2) + '\n')
    print('Musashi level-up: 13 source-traced notes, %.3fs' % (len(mixed)/44100))


if __name__ == '__main__':
    main()
