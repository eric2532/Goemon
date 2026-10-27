"""Recover final-boss sound calls, their shared banks and complete event catalog."""
import argparse
import array
import hashlib
import io
import json
import math
import shutil
import struct
import subprocess
import wave
from recover_monster_audio import ROOT, RECOVERY, recover
from musashi_pitch import render_pitch

NAMES={0xab5:'sword_wave',0xab6:'sword_cross',0xab7:'water_burst',0xab8:'fire_fall',0x437:'hit',0x438:'hit_strong',0x439:'hit_heavy',0x43c:'reaction',
       0xaba:'sky_copy',0xabb:'sky_launch',0xabc:'earth_impact',0xabd:'fire_loop',
       0xabe:'wind_loop',0xab9:'wind_start',0xb4b:'core_charge',0xb4c:'core_hit',
       0xb4d:'defeat',0xb4e:'ending',0xb59:'core_burst',0xb5a:'core_loop',
       0xba3:'impact',0xba5:'cast',0xba6:'sword_swing',0xba7:'earth_rumble'}

def wind_sample():
    """Prepare the selected Wind sequence sample, retaining its actual loop region."""
    exe_path=RECOVERY/'raw/SLUS_007.26';owner_path=RECOVERY/'raw/SC07.CD.dir/FILE_002.dir/2.7'
    exe=exe_path.read_bytes();owner=owner_path.read_bytes()
    exe_base=struct.unpack_from('<I',exe,24)[0]-0x800;owner_base=0x800c7f08
    header=struct.unpack_from('<HHHHIHHIII',owner,len(owner)-28)
    dispatch=exe[0x8006451c+0xabe*4-exe_base:0x8006451c+0xabe*4-exe_base+4]
    assert dispatch==bytes.fromhex('050f0001')
    # Type 5 reads owner+0x18 / 12-byte descriptors, not the ordinary event table.
    assert struct.unpack_from('<I',exe,0x800343b0-exe_base)[0]==0x8ca20018
    descriptor=header[9]+dispatch[3]*12
    pointer,priority,lock_ticks,flags=struct.unpack_from('<IHHI',owner,descriptor-owner_base)
    assert (pointer,priority,lock_ticks,flags)==(0x800c8a00,250,8,0x10)
    op,timing,routing,voice_priority,curve=struct.unpack_from('<5I',owner,pointer-owner_base)
    note=op&0xffff;volume=(op>>16)&0xff
    bank_slot=(routing>>16)&0xff;index=(routing>>8)&0xff
    assert (op>>24,note,volume,bank_slot,index,timing,curve)==(0x80,0x4a00,100,94,12,20,0)
    bank=next(b for b in json.loads((RECOVERY/'media_manifest.json').read_text())
              if b.get('kind')=='vab_bank' and 'raw/SC07.CD.dir/FILE_004.dir/2.2' in b['sources'])
    lookup=struct.unpack_from('<I',exe,0x80064d44+bank_slot*12-exe_base)[0]
    program,tone=exe[lookup+index*2-exe_base:lookup+index*2-exe_base+2]
    vh=(RECOVERY/bank['header_path']).read_bytes()
    tone_bytes=vh[32+128*16+program*512+tone*32:32+128*16+program*512+tone*32+32]
    sample_index=struct.unpack_from('<H',tone_bytes,22)[0];sample=bank['sample_list'][sample_index-1]
    assert sample['id']=='sample_7c2b6ff8fa8c4ed9' and tone_bytes[5]==0
    raw=(RECOVERY/bank['body_path']).read_bytes()[sample['body_offset']:sample['body_offset']+sample['bytes']]
    loop_start=next(i//16 for i in range(0,len(raw),16) if raw[i+1]&4)
    loop_end=next(i//16 for i in range(0,len(raw),16) if raw[i+1]&1)
    assert (loop_start,loop_end,raw[loop_end*16+1])==(1,372,3)
    vag=RECOVERY/'converted/audio/samples_vag'/(sample['id']+'.vag')
    decoded=subprocess.run([shutil.which('ffmpeg') or '/opt/homebrew/bin/ffmpeg','-nostdin','-v','error',
                           '-i',str(vag),'-f','s16le','-c:a','pcm_s16le','pipe:1'],check=True,capture_output=True).stdout
    assert len(decoded)==(loop_end+1)*28*2
    table=struct.unpack_from('<84H',exe,0x8006ab30-exe_base)
    pcm=array.array('h',render_pitch(decoded,note,tone_bytes[4],[],table))
    register=table[(note-((tone_bytes[4]-60)<<8))>>8]
    loop_begin=math.ceil(loop_start*28/(register/4096))
    gain=.5*32767/max(abs(v) for v in pcm)
    pcm=array.array('h',(round(v*gain) for v in pcm))
    result=io.BytesIO()
    with wave.open(result,'wb') as w:
        w.setnchannels(1);w.setsampwidth(2);w.setframerate(44100);w.writeframes(pcm.tobytes())
    report=dict(event='0xabe',dispatch=dispatch.hex(),descriptor=hex(descriptor),sequence=hex(pointer),
                bank_slot=bank_slot,bank=bank['id'],lookup_index=index,sample_index=sample_index,sample_id=sample['id'],
                pitch_q8=note,source_volume=volume,source_keyoff_ticks=timing,loop_begin=loop_begin,loop_end=len(pcm),
                peak_gain=gain,sha256=hashlib.sha256(result.getvalue()).hexdigest(),
                source_hashes={str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in [exe_path,owner_path,vag]},
                adaptation='User-selected sustained Wind sample at audition headroom; retains source pitch and loop bounds. Goemon cast owns duration. No PSX ADSR/reverb or original retrigger emulation.')
    return result.getvalue(),report


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--wind-only',action='store_true');args=parser.parse_args()
    if not args.wind_only:recover('dark_lumina_3','SC07',4,NAMES,94,
        ROOT/'assets/characters/recovered_monsters/audio/dark_lumina_3',
        ROOT/'build/Other Files/Asset Toolkit/Dark Lumina 3/Audio Catalog',
        ['Finale module0x73; sound calls traced through its handlers and scene owner.',
         'AB9 is disabled in retail dispatch; Goemon uses it as the user-selected Wind opening gust.'],
        owner_source='raw/SC07.CD.dir/FILE_002.dir/2.7',
        bank_sources={96:'raw/SC07.CD.dir/FILE_003.dir/2.2',100:'raw/SC07.CD.dir/FILE_000.dir/2.2'})
    audio,report=wind_sample()
    out=ROOT/'assets/characters/recovered_monsters/audio/dark_lumina_3'
    (out/'wind_sustain.wav').write_bytes(audio)
    (out/'wind_sustain_sources.json').write_text(json.dumps(report,indent=2)+'\n')
    print('Wind sustain: bank',report['bank_slot'],'sample',report['sample_index'],'loop',report['loop_begin'],report['loop_end'])
