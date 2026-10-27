"""Recover DL2's direct and sequenced SPU cues, with their source timing/layers."""
import array
import hashlib
import json
import shutil
import struct
import subprocess
import wave
from recover_monster_audio import ROOT, RECOVERY, OWNER_BASE
from musashi_pitch import render_pitch

OUT=ROOT/'assets/characters/recovered_monsters/audio/dark_lumina_2'
WORK=ROOT/'build/Other Files/Asset Toolkit/Dark Lumina 2/Audio Catalog'
NAMES={0xb52:'slam',0xb53:'step',0xb54:'fire_release',0xb56:'hurt',0xb79:'claw',
       0xb9c:'breath',0xb9e:'breakup',0xb9f:'effect',0xc17:'throw',0xc18:'grab',
       0xc31:'contact_a',0xc32:'contact_b',0xc33:'fire_impact',0xc34:'recover',
       0xc35:'fire_charge',0xc73:'death',0xc7b:'throw_layer',0xc8c:'death_final',0xb58:'effect_b',
       0x437:'hit',0x438:'hit_strong',0x439:'hit_heavy'}


def sequence(read,address):
    """The four battle sequences use the driver's full-note and gain commands."""
    notes=[];tick=0;gain=127;ramp=0
    for _ in range(64):
        word=struct.unpack('<I',read(address,4))[0];op=word>>24
        if op==0x86:gain=word&127;ramp=0;address+=4
        elif op==0x84:ramp=(word>>8)&0xffff;target=word&127;assert target==127;address+=4
        elif op==0x80:
            raw=read(address,20);pitch,volume=word&65535,(word>>16)&127
            gate,delay=struct.unpack_from('<HH',raw,4);flags,index,bank,pan=raw[8:12]
            notes.append(dict(address=hex(address),raw=raw.hex(),tick=tick,pitch=pitch,volume=volume,
                              bank=bank,index=index,curve=struct.unpack_from('<I',raw,16)[0],gate=gate,gain=gain,ramp=ramp,flags=flags,pan=pan))
            tick+=delay;address+=20
            if not delay:break
        elif op==0x87:break
        else:raise ValueError(('unhandled sequence opcode',hex(address),hex(word)))
    else:raise ValueError('Unterminated sequence')
    assert notes
    return notes


def main():
    OUT.mkdir(parents=True,exist_ok=True);WORK.mkdir(parents=True,exist_ok=True)
    owner_path='raw/SC07.CD.dir/FILE_001.dir/4.7';owner=(RECOVERY/owner_path).read_bytes()
    exe=(RECOVERY/'raw/SLUS_007.26').read_bytes();base=struct.unpack_from('<I',exe,24)[0]
    def read(address,n):
        data,offset=(owner,address-OWNER_BASE) if OWNER_BASE<=address<OWNER_BASE+len(owner) else (exe,address-base+0x800)
        assert 0<=offset<=len(data)-n,hex(address)
        return data[offset:offset+n]
    header=struct.unpack('<HHHHIHHIII',owner[-28:]);assert header[0]==15
    banks={b['id']:b for b in json.loads((RECOVERY/'media_manifest.json').read_text()) if b['kind']=='vab_bank'}
    ids={0:'bank_d8f2dc9eb7ed7287',1:'bank_9c8ce35dd2b0baf2',96:'bank_8861d0f48050ebe2'}
    pitch_table=struct.unpack('<84H',read(0x8006ab30,168));decoded={};events={}
    def sample(bank,index):
        b=banks[ids[bank]];resource=read(0x80064d44+bank*12,12);assert index<resource[4]
        program,tone=read(struct.unpack_from('<I',resource)[0]+index*2,2)
        vh=(RECOVERY/b['header_path']).read_bytes();assert tone<vh[32+program*16]
        tone_bytes=vh[32+128*16+program*512+tone*32:32+128*16+program*512+tone*32+32]
        si=struct.unpack_from('<H',tone_bytes,22)[0];s=b['sample_list'][si-1]
        if s['id'] not in decoded:
            wav=WORK/(s['id']+'.wav')
            subprocess.run([shutil.which('ffmpeg'),'-nostdin','-v','error','-y','-i',str(RECOVERY/'converted/audio/samples_vag'/(s['id']+'.vag')),str(wav)],check=True)
            with wave.open(str(wav),'rb') as w:
                assert w.getnchannels()==1 and w.getsampwidth()==2
                decoded[s['id']]=w.readframes(w.getnframes())
        return decoded[s['id']],tone_bytes,s['id']
    for sid,label in NAMES.items():
        dispatch=read(0x8006451c+sid*4,4);resolved=sid
        if dispatch[0]&63==6:
            resolved=struct.unpack('<H',read(header[7]+(dispatch[3]*header[6]+1)*2,2))[0]
            dispatch=read(0x8006451c+resolved*4,4)
        kind=dispatch[0]&63;notes=[]
        if kind==5:
            address=header[9]+dispatch[3]*12;record=read(address,12)
            assert record[8]&16
            notes=sequence(read,struct.unpack_from('<I',record)[0])
        elif kind in (0,1):
            address=(struct.unpack('<I',read(0x80068304,4))[0] if dispatch[1]==0 else struct.unpack('<I',read(header[8]+dispatch[2]*4,4))[0])+dispatch[3]*20
            for _ in range(16):
                raw=read(address,20)
                notes.append(dict(address=hex(address),raw=raw.hex(),tick=struct.unpack_from('<H',raw,2)[0],pitch=struct.unpack_from('<H',raw,4)[0],volume=raw[6]&127,bank=raw[8],index=raw[9],curve=struct.unpack_from('<I',raw,16)[0],gate=0,gain=127,ramp=0))
                address+=20
                if raw[11]==0:break
            else:raise ValueError('Unterminated layers')
        elif kind==2:
            events[label]=dict(id=hex(sid),resolved=hex(resolved),dispatch=list(dispatch),control_only=True);continue
        else:raise ValueError((hex(sid),list(dispatch)))
        buffers=[]
        for note in notes:
            dry,tone,sample_id=sample(note['bank'],note['index']);note['sample']=sample_id;note['tone_hex']=tone.hex()
            curve=list(struct.unpack('<9H',read(note['curve'],18))) if note['curve'] else []
            note['curve_data']=curve
            pcm=array.array('h',render_pitch(dry,note['pitch'],tone[4],curve,pitch_table))
            if note['gate']:pcm=pcm[:note['gate']*735]
            buffers.append((note['tick']*735,pcm,note))
        mixed=[0.0]*max(delay+len(pcm) for delay,pcm,note in buffers)
        for delay,pcm,note in buffers:
            for i,value in enumerate(pcm):
                envelope=min(127*128,note['gain']*128+(i//735)*note['ramp'])/(127*128)
                mixed[delay+i]+=value*note['volume']/127*envelope
        gain=min(1,30000/max(1,max(abs(v) for v in mixed)))
        path=OUT/(label+'.wav')
        with wave.open(str(path),'wb') as w:
            w.setnchannels(1);w.setsampwidth(2);w.setframerate(44100);w.writeframes(array.array('h',(round(v*gain) for v in mixed)).tobytes())
        events[label]=dict(id=hex(sid),resolved=hex(resolved),dispatch=list(dispatch),notes=notes,sha256=hashlib.sha256(path.read_bytes()).hexdigest())
    # The throw calls C17 and C7B together; mix once offline for one pooled voice.
    layers=[]
    for label in ['throw','throw_layer']:
        with wave.open(str(OUT/(label+'.wav')),'rb') as w:layers.append(array.array('h',w.readframes(w.getnframes())))
    mixed=[sum(layer[i] if i<len(layer) else 0 for layer in layers) for i in range(max(map(len,layers)))]
    gain=min(1,30000/max(1,max(map(abs,mixed))))
    with wave.open(str(OUT/'throw_full.wav'),'wb') as w:
        w.setnchannels(1);w.setsampwidth(2);w.setframerate(44100);w.writeframes(array.array('h',(round(x*gain) for x in mixed)).tobytes())
    # Retain every owning-bank sample, including material not triggered by combat.
    samples=[]
    for s in banks[ids[96]]['sample_list']:
        p=RECOVERY/'converted/audio/samples_vag'/(s['id']+'.vag');shutil.copyfile(p,WORK/p.name);samples.append(s)
    report=dict(owner=owner_path,owner_sha256=hashlib.sha256(owner).hexdigest(),bank=ids[96],samples=samples,events=events,
                sequence_driver='8003388c; type 5 header table owner+0x18; compressed full notes 0x80 and gain commands 0x84/0x86',
                notes=['All direct sound IDs referenced by battle module 0x72 retained, plus descriptor contact cues.',
                       'C35 includes its original fade-in; C34/C73/C8C preserve scripted pitch, layers and delays.',
                       'Dry SPU ADPCM recovery; PSX ADSR/reverb/Gaussian interpolation are not emulated. Shared scene music/dialogue are not character skill cues.'])
    (OUT/'sources.json').write_text(json.dumps(report,indent=2)+'\n')
    assert len(events)==len(NAMES) and len(samples)==18
    print('Dark Lumina 2:',len(events),'cues;',len(samples),'bank samples retained')


if __name__=='__main__':main()
