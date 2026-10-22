#!/usr/bin/env python3
"""Recover original retail PS1 sounds, with source-table and pitch provenance.

Only writes into the requested development artifact directory. Uses the recovered
VAG ADPCM bytes, not replacement sound synthesis. No production assets edited.
"""
from pathlib import Path
import argparse, hashlib, json, shutil, struct, subprocess, wave
from musashi_pitch import render_pitch

DEFAULT_ROOT = Path('/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Musashi Asset Recovery')
DEFAULT_OUT = Path('/Users/eric/Desktop/Projects_Codex/Sonic/build/Other Files/Musashi Audio')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--recovery', type=Path, default=DEFAULT_ROOT)
    ap.add_argument('--out', type=Path, default=DEFAULT_OUT)
    ap.add_argument('--sound', action='append', default=[], metavar='HEX_ID:NAME',
                    help='Recover a specific event as a candidate; original material/object use is not asserted.')
    ap.add_argument('--bank', action='append', default=[], metavar='SLOT:SOURCE_PATH',
                    help='Explicit recovered VAB source for another original driver bank slot.')
    ap.add_argument('--driver-pitch', action='store_true',
                    help='Apply source-traced type10 pitch modulation at60 gameplay ticks/sec; still dry SPU audio.')
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
    for selection in args.bank:
        slot, source = selection.split(':', 1)
        matches = [entry for entry in banks.values() if source in entry['sources']]
        if len(matches) != 1:
            ap.error('Bank source must identify exactly one recovered VAB bank')
        bank_ids[int(slot, 0)] = matches[0]['id']
    metadata = []
    specifications = [
        (0x400, 'fusion_swing', 'Fusion swing', 'confirmed', 'func_801555F4 and func_8015B6F4'),
        (0x446, 'fusion_swing_2', 'Fusion alternate swing', 'confirmed', 'func_801555F4 case2'),
        (0x447, 'fusion_air_swing', 'Fusion air follow-through swing', 'confirmed', 'func_80155B9C'),
        (0x455, 'lumina_swing', 'Lumina swing', 'confirmed', 'func_801575E4 and func_8015B7B4'),
        (0x437, 'sword_entity_hit_437', 'Basic Fusion and Lumina entity contact', 'confirmed entity contact; bank selection structurally verified', 'func_80156A88 ->8014CA14(target,selector)->8014CA70(targetdescriptor+0x14+2*selector)->80147364; SC01 FILE077/084 enemy templates contain437,437,438,439; selector0 default both swords'),
        (0x438, 'sword_entity_hit_438', 'Fusion third combo / stronger entity contact', 'confirmed entity contact; bank selection structurally verified', 'Same entity target sound-selector table as437; selector2 maps438'),
        (0x439, 'sword_entity_hit_439', 'Advanced attack entity contact', 'confirmed entity contact; bank selection structurally verified', 'Same entity target sound-selector table as437; selector3 maps439'),
        (0x41E, 'movement_land_41e', 'Ground-contact / landing surface0', 'landing source trace confirmed; bank selection structurally verified', 'func_8015AC48 selects animationtable9 then80161CD0; func_8015B950 also selects table9 on groundtransition then80161CD0; SC01_000 soundtableD_801816F0[0]=41E; chapter1 owner resolves481'),
        (0x482, 'sword_contact_type_2', 'Sword contact material/type2; shared by swords', 'source-traced; bank selection structurally verified', 'func_80156848 -> func_80156A1C -> D_80180EDC[2]=0x428 -> scene owner row34,column0=0x482'),
        (0x483, 'sword_contact_type_1', 'Sword contact material/type1; shared by swords', 'source-traced; bank selection structurally verified', 'func_80156848 -> func_80156A1C -> D_80180EDC[1]=0x427 -> scene owner row33,column0=0x483'),
        (0x5F4, 'voice_attack', 'Musashi combat grunt; also stored as inactive0x5F3', 'confirmed combat call; audible reuse is adaptation', 'func_801555F4 case7 calls0x5F4; normal Fusion/Lumina call0x5F3, disabled in this US executable'),
        (0x5F5, 'voice_exertion_5f5', 'Musashi exertion / stronger attack grunt', 'confirmed calls; not proven damage voice', 'func_8015DB6C and func_8015DECC follow held object178 position; 0x5F6 uses same record in Fusion attackcase4'),
        (0x5F7, 'candidate_voice_5f7', 'Third resident grunt candidate; no proven jump association', 'candidate only', 'sound table record present; no jump call established'),
        (0x451, 'voice_hurt', 'Musashi damage / knockback sound', 'damage reaction source calls confirmed; voice vs body-impact not auditioned', 'func_801519C8 / 801523F4 / 801528B0 / 80152DA8 call51204 with damageparamF2, set hitreaction animationD5880/D58AC and knockback; not a confirmed landing sound'),
        (0x436, 'damage_reaction_436', 'Damage reaction alternate, scene-resolved', 'source call confirmed; not a confirmed landing sound', 'func_80151DB0 applies damageparamF2 and hitreactionD5880/D58AC, then calls436; common chapter1 bank resolves48E'),
    ]
    if args.sound:
        specifications = []
        for specification in args.sound:
            sound_id, name = specification.split(':', 1)
            if not name or any(c not in 'abcdefghijklmnopqrstuvwxyz0123456789_-' for c in name):
                ap.error('Sound names must use lowercase letters, digits, underscore or hyphen.')
            sid = int(sound_id, 0)
            if not 0 <= sid < 0xCF8:
                ap.error('Sound ID is outside the original dispatch table.')
            specifications.append((sid, name, f'Recovered Musashi event0x{sid:03X}',
                'original bank/sample/pitch verified; material or object association not established',
                'Retail executable dispatch table0x8006451C; scene references resolve through the SC01 sound owner.'))
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
        # Validate the complete driver lookup against this supplied bank, not
        # only the requested note: mismatched stage banks can sound plausible.
        for index in range(resource[4]):
            expected_program, expected_tone = read_exe(lookup_pointer + index * 2, 2)
            assert expected_program < 128 and expected_tone < header[32 + expected_program * 16]
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
        curve_pointer = u32(record[16:20])
        curve = []
        output_rate = round(playback_rate)
        if args.driver_pitch:
            if curve_pointer:
                curve = list(struct.unpack('<9H', read_owner(curve_pointer, 18) if curve_pointer >= 0x800C7F08 else read_exe(curve_pointer, 18)))
            pitch_table = struct.unpack('<84H', read_exe(0x8006AB30, 168))
            pcm = render_pitch(pcm, pitch_q8, tone_bytes[4], curve, pitch_table)
            output_rate = 44100
        with wave.open(str(target), 'wb') as w:
            w.setnchannels(1); w.setsampwidth(2)
            w.setframerate(output_rate); w.writeframes(pcm)
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
            wav_sample_rate=output_rate, duration_seconds=len(pcm)/2/output_rate,
            pitch_modulation=dict(applied=args.driver_pitch, pointer=hex(curve_pointer), words=curve, tick_rate=60,
                trace='800316F8 case10 initializes;800314DC steps;80031988 case10 handles key-off'),
            sha256=hashlib.sha256(target.read_bytes()).hexdigest()))
    report = dict(source_executable=str(exe_path), source_executable_sha256=hashlib.sha256(exe).hexdigest(),
        sound_owner=str(owner_path), sound_owner_sha256=hashlib.sha256(owner).hexdigest(),
        notes=[
            'WAVs decode authentic recovered retail SPU ADPCM; no synthetic or substitute sounds.',
            'Pitch follows original custom sound-driver SPU lookup/interpolation, rounded to integer WAV sample rate.',
            ('Original type10 pitch motion applied at60 gameplay ticks/sec with linear resampling; SPU ADSR, Gaussian interpolation, reverb and event volume are not emulated.' if args.driver_pitch else 'Dry samples: original SPU ADSR, reverb, event volumes and pitch modulation are recorded/retained in tone and record bytes, not emulated.'),
            'Sword contact type1/type2 sounds are shared material/contact variants. Do not assert different sword identities.',
            'Entity-hit437 is shared by basic Fusion and Lumina; 438 is selected by stronger combo and439 by advanced descriptors. Environment482/483 are separate.',
            'Combat0x5F3 is kind0/inactive in this US executable, but points at the same voice record as active0x5F4.',
            'No confirmed jump voice recovered; candidate_voice_5f7 must not be labelled original jump voice.',
            '0x451 is damage/knockback reaction, not a confirmed landing sound. 0x5F5/5F6 is exertion/stronger-attack audio, not a source-confirmed hurt voice.',
            'Confirmed landing material0 is0x41E (scene-resolved0x481); source8015AC48 and8015B950 enter animationtable9 then call80161CD0 with groundmaterial actor+16E.',
            'Original source calls swing/voice during attack initialization, including air attack initializers. Delaying to animation release is a runtime adaptation.',
        ], clips=metadata)
    (out / 'audio_provenance.json').write_text(json.dumps(report, indent=2) + '\n')
    lines = ['Original Musashi audio recovery', '', *report['notes'], '']
    for m in metadata:
        lines.extend([f"{Path(m['file']).name}: {m['sound_id']} — {m['description']}",
            f"  {m['bank_id']}; program {m['program']}, tone {m['tone']}, sample {m['sample_index']}; {m['wav_sample_rate']} Hz; {m['duration_seconds']:.3f}s",
            f"  {m['source_trace']}", f"  Confidence: {m['confidence']}", ''])
    (out / 'RECOVERY_NOTES.txt').write_text('\n'.join(lines))
    print(json.dumps([dict(file=Path(x['file']).name, sound_id=x['sound_id'], seconds=round(x['duration_seconds'],3), sample_rate=x['wav_sample_rate']) for x in metadata], indent=2))


if __name__ == '__main__':
    main()
