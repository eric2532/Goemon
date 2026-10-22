#!/usr/bin/env python3
"""Recover original retail PS1 sounds, with source-table and pitch provenance.

Only writes into the requested development artifact directory. Uses the recovered
VAG ADPCM bytes, not replacement sound synthesis. No production assets edited.
"""
from pathlib import Path
import argparse, hashlib, json, shutil, struct, subprocess, wave

DEFAULT_ROOT = Path('/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Musashi Asset Recovery')
DEFAULT_OUT = Path('/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Musashi Soldier Audio')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--recovery', type=Path, default=DEFAULT_ROOT)
    ap.add_argument('--out', type=Path, default=DEFAULT_OUT)
    args = ap.parse_args()
    root, out = args.recovery, args.out
    out.mkdir(parents=True, exist_ok=True)
    ffmpeg = shutil.which('ffmpeg') or '/opt/homebrew/bin/ffmpeg'
    manifest = json.loads((root / 'media_manifest.json').read_text())
    banks = {x['id']: x for x in manifest if x['kind'] == 'vab_bank'}
    exe_path = root / 'raw/SLUS_007.26'
    exe = exe_path.read_bytes()
    assert exe[:8] == b'PS-X EXE'
    exe_base = struct.unpack_from('<I', exe, 24)[0]
    def read_exe(address, count):
        off = address - exe_base + 0x800
        assert off >= 0 and off + count <= len(exe)
        return exe[off:off + count]
    def u32(data):
        return struct.unpack('<I', data)[0]
    table_pointer = u32(read_exe(0x80068304, 4))
    owner_path = root / 'raw/SC01.CD.dir/FILE_000.dir/4.7'
    owner = owner_path.read_bytes()
    def read_owner(address, count):
        off = address - 0x800C7F08
        assert off >= 0 and off + count <= len(owner)
        return owner[off:off + count]
    owner_header = struct.unpack('<HHHHIHHIII', read_owner(0x800CA23C, 28))
    assert owner_header[:3] == (1, 11, 0)
    # Non-musical resident banks uniquely match lookup counts/programs. Bank1
    # source selection also matches the SC01 chapter sound-owner lookup.
    bank_ids = {0: 'bank_d8f2dc9eb7ed7287', 1: 'bank_9c8ce35dd2b0baf2'}
    metadata = []
    soldier_path = root / 'raw/SC01.CD.dir/FILE_077.dir/0.4.dec'
    soldier = soldier_path.read_bytes()
    # Shared ordinary death entry, immediately following original tumble setup.
    assert struct.unpack_from('<II', soldier, 0x801824B0 - 0x80128158) == (0x240406AA, 0x0C00B532)
    specifications = [(0x6AA, 'soldier_death_6aa', 'Ordinary Thirstquencher Soldier death/tumble sound', 'shared ordinary death entry confirmed in retail bytes; bank and pitch source-resolved', 'SC01 FILE077 func_80182420 shared ordinary death entry; 801824B0 loads a0=0x6AA; 801824B4 calls8002D4C8 after Source__801b09d0 tumble setup; ordinary subtypes0/1/2 share this entry')]
    for sid, name, description, confidence, trace in specifications:
        dispatch_address = 0x8006451C + sid * 4
        dispatch = read_exe(dispatch_address, 4)
        original_dispatch = dispatch
        resolved_id = sid
        if (dispatch[0] & 63) == 6:
            # Scene owner table level1 => level-map1 => column0. Other scene
            # resource levels may resolve differently; retain this provenance.
            assert dispatch[2] == 3
            row = read_owner(owner_header[7] + dispatch[3] * owner_header[6] * 2, 2)
            resolved_id = struct.unpack('<H', row)[0]
            assert resolved_id != 127
            dispatch = read_exe(0x8006451C + resolved_id * 4, 4)
        assert (dispatch[0] & 63) == 1
        if dispatch[1] == 0:
            record_address = table_pointer + dispatch[3] * 20
            record = read_exe(record_address, 20)
        else:
            assert dispatch[1] == 1
            record_array = u32(read_owner(owner_header[8] + dispatch[2] * 4, 4))
            record_address = record_array + dispatch[3] * 20
            record = read_owner(record_address, 20)
        bank_entry, lookup_index = record[8], record[9]
        bank = banks[bank_ids[bank_entry]]
        resource = read_exe(0x80064D44 + bank_entry * 12, 12)
        lookup_pointer = u32(resource[:4])
        program, tone = read_exe(lookup_pointer + lookup_index * 2, 2)
        header = (root / bank['header_path']).read_bytes()
        assert bank['tones'] >= resource[4]
        if bank_entry == 1:
            assert bank['tones'] == resource[4] == 30 and bank['programs'] == 4
        assert tone < header[32 + program * 16]
        tone_offset = 32 + 128 * 16 + program * 512 + tone * 32
        tone_bytes = header[tone_offset:tone_offset + 32]
        sample_index = struct.unpack_from('<H', tone_bytes, 22)[0]
        sample = bank['sample_list'][sample_index - 1]
        assert sample['index'] == sample_index
        pitch_q8 = struct.unpack_from('<H', record, 4)[0]
        # Custom driver 80030730 caches ToneAtr.center <<8, ignoring fine.
        # 80032A74 subtracts (center-60)<<8, then interpolates this SPU table.
        d = pitch_q8 - ((tone_bytes[4] - 60) << 8)
        p0, p1 = struct.unpack('<HH', read_exe(0x8006AB30 + (d >> 8) * 2, 4))
        pitch_register = (p0 * (256 - (d & 255)) + p1 * (d & 255)) >> 8
        playback_rate = 44100 * pitch_register / 4096
        vag = root / 'converted/audio/samples_vag' / (sample['id'] + '.vag')
        decoded = out / (name + '.decode.wav')
        subprocess.run([ffmpeg, '-nostdin', '-v', 'error', '-y', '-i', str(vag), '-c:a', 'pcm_s16le', str(decoded)], check=True)
        target = out / (name + '.wav')
        with wave.open(str(decoded), 'rb') as w:
            assert w.getnchannels() == 1 and w.getsampwidth() == 2
            pcm = w.readframes(w.getnframes())
        with wave.open(str(target), 'wb') as w:
            w.setnchannels(1); w.setsampwidth(2)
            w.setframerate(round(playback_rate)); w.writeframes(pcm)
        decoded.unlink()
        body = (root / bank['body_path']).read_bytes()
        raw_sample = body[sample['body_offset']:sample['body_offset'] + sample['bytes']]
        metadata.append(dict(sound_id=f'0x{sid:03X}', file=str(target), description=description,
            confidence=confidence, source_trace=trace, dispatch_address=hex(dispatch_address),
            dispatch_bytes=original_dispatch.hex(' '), resolved_sound_id=f'0x{resolved_id:03X}',
            resolved_dispatch_bytes=dispatch.hex(' '), record_address=hex(record_address), record_bytes=record.hex(' '),
            bank_entry=bank_entry, bank_id=bank['id'], bank_sources=bank['sources'],
            bank_sha256=bank['sha256'], lookup_index=lookup_index, program=program,
            tone=tone, tone_bytes=tone_bytes.hex(' '), sample_index=sample_index,
            sample_id=sample['id'], sample_sha256=hashlib.sha256(raw_sample).hexdigest(),
            pitch_q8=pitch_q8, center_note=tone_bytes[4], fine=tone_bytes[5],
            spu_pitch_register=pitch_register, original_playback_rate=playback_rate,
            wav_sample_rate=round(playback_rate), duration_seconds=len(pcm)/2/round(playback_rate),
            sha256=hashlib.sha256(target.read_bytes()).hexdigest()))
    report = dict(soldier_overlay=str(soldier_path), soldier_overlay_sha256=hashlib.sha256(soldier).hexdigest(), death_call_address='0x801824B0', death_call_bytes=soldier[0x801824B0-0x80128158:0x801824BC-0x80128158].hex(' '), source_executable=str(exe_path), source_executable_sha256=hashlib.sha256(exe).hexdigest(),
        sound_owner=str(owner_path), sound_owner_sha256=hashlib.sha256(owner).hexdigest(),
        notes=[
            'Authentic recovered retail SPU ADPCM sample; no synthesis or substitute audio.',
            'Pitch follows original custom driver SPU lookup/interpolation, rounded to integer WAV sample rate.',
            'Dry sample: original SPU ADSR/reverb/volume modulation not emulated; original tone and record bytes retained.',
        ], clips=metadata)
    (out / 'audio_provenance.json').write_text(json.dumps(report, indent=2) + '\n')
    lines = ['Original Thirstquencher death sound recovery', '', *report['notes'], '']
    for m in metadata:
        lines.extend([f"{Path(m['file']).name}: {m['sound_id']} — {m['description']}",
            f"  {m['bank_id']}; program {m['program']}, tone {m['tone']}, sample {m['sample_index']}; {m['wav_sample_rate']} Hz; {m['duration_seconds']:.3f}s",
            f"  {m['source_trace']}", f"  Confidence: {m['confidence']}", ''])
    (out / 'RECOVERY_NOTES.txt').write_text('\n'.join(lines))
    print(json.dumps([dict(file=Path(x['file']).name, sound_id=x['sound_id'], seconds=round(x['duration_seconds'],3), sample_rate=x['wav_sample_rate']) for x in metadata], indent=2))


if __name__ == '__main__':
    main()
