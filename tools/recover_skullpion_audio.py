"""Recover the Skullpion stage sound catalog and its original layered pitch motion."""
import array
import hashlib
import json
from pathlib import Path
import shutil
import struct
import subprocess
import wave
from musashi_pitch import render_pitch

ROOT = Path(__file__).resolve().parents[1]
RECOVERY = ROOT/'build/Other Files/Musashi Asset Recovery'
OWNER = 'raw/SC03.CD.dir/FILE_028.dir/4.7'
OWNER_BASE = 0x800C7F08
HEADER = 0x800CA3E4
BANK = 'bank_af40596fbbf765f2'
NAMES = {0x558:'bank_event_558',0x559:'bank_event_559',0x55a:'bank_event_55a',
         0x55b:'sand_windup',0x55c:'sand_blast',0x55d:'tail_slam',0x55e:'tail_sweep',
         0x55f:'drill_windup',0x560:'ground_impact',0x561:'drill_release',
         0x562:'drill_emerge',0x563:'helper_rock_hit',0x564:'breakup',
         0x565:'defeat',0x566:'core_recover',0x627:'volley_release',0x628:'volley_bounce',0x629:'volley_expire',0x6c1:'sand_turn',
         0xb08:'core_hit',0x5e0:'core_finish',0xbf2:'helper_hit'}


def main():
    out = ROOT/'assets/characters/recovered_skullpion/audio'
    catalog = ROOT/'build/Other Files/Asset Toolkit/Skullpion/Audio Catalog'
    out.mkdir(parents=True,exist_ok=True);catalog.mkdir(parents=True,exist_ok=True)
    exe = (RECOVERY/'raw/SLUS_007.26').read_bytes()
    owner = (RECOVERY/OWNER).read_bytes()
    exe_base, = struct.unpack_from('<I',exe,24)
    def read(address,count):
        data,offset = (owner,address-OWNER_BASE) if OWNER_BASE<=address<OWNER_BASE+len(owner) else (exe,address-exe_base+0x800)
        if offset<0 or offset+count>len(data):raise ValueError(f'Invalid sound address {address:#x}')
        return data[offset:offset+count]
    header = struct.unpack('<HHHHIHHIII',read(HEADER,28))
    assert header[:3]==(4,11,22)
    arrays = struct.unpack('<9I',read(header[8],36))
    bank = next(b for b in json.loads((RECOVERY/'media_manifest.json').read_text()) if b.get('id')==BANK)
    assert 'raw/SC03.CD.dir/FILE_028.dir/2.2' in bank['sources']
    vh = (RECOVERY/bank['header_path']).read_bytes()
    resource = read(0x80064D44+22*12,12)
    lookup, = struct.unpack_from('<I',resource)
    assert resource[4]==31 and bank['tones']==33
    for i in range(resource[4]):
        program,tone = read(lookup+i*2,2)
        assert tone<vh[32+program*16]
    table = struct.unpack('<84H',read(0x8006AB30,168))
    ffmpeg = shutil.which('ffmpeg') or '/opt/homebrew/bin/ffmpeg'
    decoded={};events={}
    for sid in range(0x400,0xCF8):
        dispatch=read(0x8006451C+sid*4,4)
        if dispatch[1]!=4 or dispatch[0]&63 not in (1,5) or dispatch[2]>=len(arrays):continue
        address=arrays[dispatch[2]]+dispatch[3]*20
        if not OWNER_BASE<=address<=OWNER_BASE+len(owner)-20 or read(address,20)[8]!=22:continue
        layers=[];buffers=[]
        for _ in range(16):
            record=read(address,20)
            assert record[8]==22
            program,tone=read(lookup+record[9]*2,2)
            tone_bytes=vh[32+128*16+program*512+tone*32:32+128*16+program*512+tone*32+32]
            sample_index,=struct.unpack_from('<H',tone_bytes,22)
            sample=bank['sample_list'][sample_index-1]
            if sample_index not in decoded:
                path=catalog/(sample['id']+'.decode.wav')
                subprocess.run([ffmpeg,'-nostdin','-v','error','-y','-i',str(RECOVERY/'converted/audio/samples_vag'/(sample['id']+'.vag')),'-c:a','pcm_s16le',str(path)],check=True)
                with wave.open(str(path),'rb') as w:
                    assert w.getnchannels()==1 and w.getsampwidth()==2
                    decoded[sample_index]=w.readframes(w.getnframes())
                path.unlink()
            initial,=struct.unpack_from('<H',record,4)
            pointer,=struct.unpack_from('<I',record,16)
            curve=list(struct.unpack('<9H',read(pointer,18))) if pointer else []
            pcm=array.array('h',render_pitch(decoded[sample_index],initial,tone_bytes[4],curve,table))
            delay=struct.unpack_from('<H',record,2)[0]*735
            # Preserve the original event layer balance; SPU ADSR/reverb remain hardware-specific.
            gain=(record[6]&127)/127
            buffers.append((delay,pcm,gain))
            layers.append(dict(record_address=hex(address),record_hex=record.hex(),program=program,tone=tone,
                tone_hex=tone_bytes.hex(),sample_index=sample_index,sample_id=sample['id'],
                lookup_index=record[9],pitch_q8=initial,curve_pointer=hex(pointer),curve=curve,delay_frames=delay))
            address+=20
            if record[11]==0:break
        else:raise ValueError('Unterminated sound-layer chain')
        mixed=[0.0]*max(offset+len(pcm) for offset,pcm,gain in buffers)
        for offset,pcm,gain in buffers:
            for i,value in enumerate(pcm):mixed[offset+i]+=value*gain
        peak=max(1,max(abs(v) for v in mixed));headroom=min(1,30000/peak)
        final=array.array('h',(round(v*headroom) for v in mixed))
        name=NAMES.get(sid,f'event_{sid:03x}')+'.wav'
        path=(out if sid in NAMES else catalog)/name
        with wave.open(str(path),'wb') as w:
            w.setnchannels(1);w.setsampwidth(2);w.setframerate(44100);w.writeframes(final.tobytes())
        events[f'{sid:03x}']=dict(file=str(path.relative_to(ROOT)),dispatch_hex=dispatch.hex(),layers=layers,
            seconds=len(final)/44100,sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    # Keep every original stage sample, including tones without a confirmed boss call.
    for sample in bank['sample_list']:
        source=RECOVERY/'converted/audio/samples_vag'/(sample['id']+'.vag')
        shutil.copyfile(source,catalog/source.name)
    report=dict(owner=OWNER,owner_base=hex(OWNER_BASE),header=hex(HEADER),bank=BANK,
        owner_sha256=hashlib.sha256(owner).hexdigest(),bank_sha256=bank['sha256'],
        events=events,bank_samples=bank['sample_list'],
        limitations=['Dry authentic SPU samples with source pitch, layer delays and relative volumes.',
            'PSX ADSR, Gaussian interpolation, reverb and held-loop key-off envelopes are not emulated.',
            'Event aliases elsewhere in the game are catalogued, not asserted as distinct boss attacks.'])
    (out/'sources.json').write_text(json.dumps(report,indent=2)+'\n')
    (catalog/'sources.json').write_text(json.dumps(report,indent=2)+'\n')
    print(f'Recovered {len(events)} event aliases and all {len(bank["sample_list"])} bank samples; {len(NAMES)} named encounter cues.')


if __name__=='__main__':main()
