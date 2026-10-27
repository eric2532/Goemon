"""Trace enemy sound IDs through retail scene owners, layers and VAB tone banks.

Keep the complete owning bank and event catalog beside the focused runtime cues.
"""
import array
import hashlib
import json
from pathlib import Path
import shutil
import struct
import subprocess
import wave
from musashi_pitch import render_pitch

ROOT=Path(__file__).resolve().parents[1]
RECOVERY=ROOT/'build/Other Files/Musashi Asset Recovery'
OUT=ROOT/'assets/characters/recovered_monsters/audio'
WORK=ROOT/'build/Other Files/Asset Toolkit/Vambee and Haya Wolf/Audio Catalog'
OWNER_BASE=0x800c7f08
CONTEXTS=[('haya_wolf','SC04',2,{0x7e4:'kick',0xa9c:'death',0xb6b:'special_state_end',0x437:'hit',0x438:'hit_strong',0x439:'hit_heavy',0x43c:'reaction',0x6aa:'death_candidate'}),
          ('karate_wolf','SC04',4,{0xa9d:'kick',0xa9e:'death',0x83c:'landing',0x437:'hit',0x438:'hit_strong',0x439:'hit_heavy',0x43c:'reaction'}),
          ('vambee','SC03',89,{0xa9b:'bite',0xcba:'vanish',0x437:'hit',0x438:'hit_strong',0x439:'hit_heavy',0x43c:'reaction',0x6aa:'death_candidate'})]


def recover(name,archive,number,names,slot,output,catalog,notes,owner_source=None,bank_sources=None):
    exe=(RECOVERY/'raw/SLUS_007.26').read_bytes();exe_base=struct.unpack_from('<I',exe,24)[0]
    banks={b['id']:b for b in json.loads((RECOVERY/'media_manifest.json').read_text()) if b['kind']=='vab_bank'}
    ffmpeg=shutil.which('ffmpeg') or '/opt/homebrew/bin/ffmpeg'
    source=f'raw/{archive}.CD.dir/FILE_{number:03}.dir/'
    owner_path=owner_source or source+'4.7';owner=(RECOVERY/owner_path).read_bytes()
    def read(address,count):
        data,offset=(owner,address-OWNER_BASE) if OWNER_BASE<=address<OWNER_BASE+len(owner) else (exe,address-exe_base+0x800)
        if offset<0 or offset+count>len(data):raise ValueError(hex(address))
        return data[offset:offset+count]
    header_address=OWNER_BASE+len(owner)-28
    header=struct.unpack('<HHHHIHHIII',read(header_address,28));level=header[0]
    level_map=list(struct.unpack('<'+str(header[1])+'h',read(header[4],header[1]*2)))
    scene_column=level_map[slot-header[2]]-1
    bank_ids={0:'bank_d8f2dc9eb7ed7287',1:'bank_9c8ce35dd2b0baf2',
              slot:next(b['id'] for b in banks.values() if source+'2.2' in b['sources'])}
    if name=='vambee':bank_ids[31]='bank_315786768bddcde4'
    for bank_slot,bank_source in (bank_sources or {}).items():
        matches=[b['id'] for b in banks.values() if bank_source in b['sources']]
        assert len(matches)==1,(bank_slot,bank_source)
        bank_ids[bank_slot]=matches[0]
    output.mkdir(parents=True,exist_ok=True);catalog.mkdir(parents=True,exist_ok=True)
    records=struct.unpack('<I',read(0x80068304,4))[0]
    table=struct.unpack('<84H',read(0x8006ab30,168));decoded={};events={};aliases={};unresolved={}
    # Every local event, including aliases unused by these two actors, is catalogued.
    ids=set(names)
    for sid in range(0x400,0xcf8):
        dispatch=read(0x8006451c+sid*4,4)
        if dispatch[1]==level and dispatch[0]&63 in (1,5):ids.add(sid)
    for sid in sorted(ids):
        original=read(0x8006451c+sid*4,4);resolutions=[sid]
        if original[0]&63==6:
            resolutions=list(struct.unpack('<'+str(header[6])+'H',read(header[7]+original[3]*header[6]*2,header[6]*2)))
            aliases[f'{sid:03x}']=resolutions
        for column,resolved in enumerate(resolutions):
            if resolved==127:continue
            dispatch=read(0x8006451c+resolved*4,4)
            if (dispatch[0]&63 not in (1,5) and not (sid in names and dispatch[0]&63==0)) or dispatch[1] not in (0,level):continue
            address=records+dispatch[3]*20 if dispatch[1]==0 else struct.unpack('<I',read(header[8]+dispatch[2]*4,4))[0]+dispatch[3]*20
            if read(address,20)[8] not in bank_ids:continue
            layers=[];buffers=[]
            for _ in range(16):
                record=read(address,20);bank_slot,index=record[8:10]
                bank=banks[bank_ids[bank_slot]]
                resource=read(0x80064d44+bank_slot*12,12);lookup=struct.unpack_from('<I',resource)[0]
                vh=(RECOVERY/bank['header_path']).read_bytes()
                assert index<resource[4],(name,bank_slot,index)
                program,tone=read(lookup+index*2,2)
                if tone>=vh[32+program*16]:
                    # Scene owners share aliases for banks loaded in other scenes.
                    assert sid not in names,(name,hex(sid),bank_slot,index)
                    unresolved[f'{sid:03x}:{column}']=dict(bank_slot=bank_slot,index=index,program=program,tone=tone)
                    buffers=[];break
                tone_bytes=vh[32+128*16+program*512+tone*32:32+128*16+program*512+tone*32+32]
                sample_index=struct.unpack_from('<H',tone_bytes,22)[0];sample=bank['sample_list'][sample_index-1]
                if sample['id'] not in decoded:
                    temporary=catalog/(sample['id']+'.decode.wav')
                    subprocess.run([ffmpeg,'-nostdin','-v','error','-y','-i',str(RECOVERY/'converted/audio/samples_vag'/(sample['id']+'.vag')),'-c:a','pcm_s16le',str(temporary)],check=True)
                    with wave.open(str(temporary),'rb') as w:
                        assert w.getnchannels()==1 and w.getsampwidth()==2
                        decoded[sample['id']]=w.readframes(w.getnframes())
                    temporary.unlink()
                pitch=struct.unpack_from('<H',record,4)[0];pointer=struct.unpack_from('<I',record,16)[0]
                try:
                    curve=list(struct.unpack('<9H',read(pointer,18))) if pointer else []
                except ValueError:
                    if sid in names:raise
                    unresolved[f'{sid:03x}:{column}']=dict(record=hex(address),curve_pointer=hex(pointer),reason='Alias does not resolve to a sound record in this scene owner')
                    buffers=[];break
                pcm=array.array('h',render_pitch(decoded[sample['id']],pitch,tone_bytes[4],curve,table))
                delay=struct.unpack_from('<H',record,2)[0]*735;buffers.append((delay,pcm,(record[6]&127)/127))
                layers.append(dict(record_address=hex(address),record_hex=record.hex(),bank_slot=bank_slot,bank=bank['id'],
                                   program=program,tone=tone,tone_hex=tone_bytes.hex(),sample_id=sample['id'],sample_index=sample_index,pitch_q8=pitch,curve=curve,delay_frames=delay))
                address+=20
                if record[11]==0:break
            else:raise ValueError('Unterminated event layers')
            if not buffers:continue
            mixed=[0.0]*max(delay+len(pcm) for delay,pcm,gain in buffers)
            for delay,pcm,gain in buffers:
                for i,value in enumerate(pcm):mixed[delay+i]+=value*gain
            gain=min(1,30000/max(1,max(abs(v) for v in mixed)))
            label=names.get(sid,f'event_{sid:03x}')+('_column%d'%column if column else '')
            path=(output if sid in names else catalog)/(label+'.wav')
            with wave.open(str(path),'wb') as w:
                w.setnchannels(1);w.setsampwidth(2);w.setframerate(44100);w.writeframes(array.array('h',(round(v*gain) for v in mixed)).tobytes())
            events[f'{sid:03x}:{column}']=dict(file=str(path.relative_to(ROOT)),resolved_id=hex(resolved),dispatch_hex=dispatch.hex(),enabled=bool(dispatch[0]&63),layers=layers,sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    bank=banks[bank_ids[slot]]
    for selected in set(bank_ids)-{0,1}:
        for sample in banks[bank_ids[selected]]['sample_list']:
            path=RECOVERY/'converted/audio/samples_vag'/(sample['id']+'.vag');shutil.copyfile(path,catalog/path.name)
    report=dict(owner=owner_path,owner_sha256=hashlib.sha256(owner).hexdigest(),header_address=hex(header_address),
                bank=bank['id'],bank_sha256=bank['sha256'],bank_samples=bank['sample_list'],events=events,scene_aliases=aliases,unresolved_scene_aliases=unresolved,
                source_resource_level=slot,scene_column=scene_column,scene_level_map=level_map,
                scene_resolution_trace='8002F4E4: resource level minus owner+4 indexes owner+8; the resulting 1-based value selects the owner+10 sound row column.',
                retained_banks={str(k):dict(id=banks[v]['id'],sha256=banks[v]['sha256'],samples=banks[v]['sample_list']) for k,v in bank_ids.items() if k not in (0,1)},
                notes=notes+['Every owner event alias and all stage samples retained; unrelated events are not labelled as character actions.',
                       'Dry authentic SPU ADPCM with source pitch curves, layer delays and relative volume. PSX ADSR, reverb, Gaussian interpolation and key-off loops are not emulated.'])
    (output/'sources.json').write_text(json.dumps(report,indent=2)+'\n')
    print(name,'events',len(events),'bank samples',len(bank['sample_list']))


def main():
    notes={'haya_wolf':'Historical misnamed Slow Guy recovery: 7E4 attack, A9C death, B6B special state.',
           'karate_wolf':'Haya Wolf: A9D kick at801831E0, A9E death at80182F88, 83C landing at80182F50; launch at source tick15.',
           'vambee':'Vambee: A9B bite and CBA vanish.'}
    for name,archive,number,names in CONTEXTS:
        recover(name,archive,number,names,35 if name=='vambee' else 50,OUT/name,WORK/name,
                [notes[name],'437/438/439/43C are descriptor contact/reaction cues; 6AA remains a candidate.'])


if __name__=='__main__':main()
