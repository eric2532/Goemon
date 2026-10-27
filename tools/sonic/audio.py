"""Recover GCAX waveforms and MIDI event metadata without modifying the disc.

Layouts: X-Hax/sa_tools_research CommandLine/MLTExtract/Gamecube.cs.
DSP ADPCM uses Nintendo's predictor coefficients; no generated replacement audio.
"""
import hashlib
import json
from pathlib import Path
import struct
import wave

ROOT = Path(__file__).resolve().parents[2]
RESEARCH = ROOT/'build/Other Files/Asset Toolkit/Sonic/Research'
OUT = ROOT/'assets/audio/recovered_sonic'

def u16(data, at): return struct.unpack_from('>H', data, at)[0]
def u32(data, at): return struct.unpack_from('>I', data, at)[0]

def banks(data):
    assert data[:8] == b'gcaxMLT '
    result = {}
    for at in range(32, 32+u32(data, 28), 16):
        if data[at] == 255: continue
        offset = 32+u32(data, at+8)
        size = u32(data, offset+12)
        assert offset+16+size <= len(data)
        result[data[at], data[at+4]] = data[offset:offset+16+size]
    return result

def adpcm(data, coefficients, count, h1=0, h2=0):
    result = []
    for at in range(0, len(data), 8):
        predictor, scale = data[at] >> 4, 1 << (data[at] & 15)
        assert predictor < 8 and at+8 <= len(data)
        a, b = coefficients[predictor*2:predictor*2+2]
        for byte in data[at+1:at+8]:
            for nibble in (byte >> 4, byte & 15):
                nibble = nibble-16 if nibble >= 8 else nibble
                sample = max(-32768, min(32767, ((nibble*scale << 11)+1024+a*h1+b*h2) >> 11))
                result.append(sample); h2, h1 = h1, sample
    assert len(result) >= count
    return result[:count]

def program_bank(data):
    chunks = {}; at = 16
    while at < len(data):
        size = u32(data, at+12)
        assert at+16+size <= len(data)
        chunks[data[at:at+8]] = data[at+16:at+16+size]
        at += 16+size
    params, waves = chunks[b'gcaxMPBP'], chunks[b'gcaxMPBW']
    samples = []
    for i in range(params[0]):
        at = u16(params, 2)+80*i
        count, nibbles, rate = struct.unpack_from('>III', params, at)
        loop, end, offset = u16(params, at+12), u32(params, at+20), u32(params, at+76)
        samples.append({'index':i, 'count':count, 'nibbles':nibbles, 'rate':rate,
                        'loop':loop, 'loop_start':u32(params, at+16), 'end':end, 'offset':offset,
                        'coefficients':list(struct.unpack_from('>16h', params, at+28)),
                        'history':list(struct.unpack_from('>2h', params, at+64))})
    programs = []
    for i in range(params[8]):
        at = u16(params, 10)+4*i; layers = []
        for l in range(params[at]):
            layer = u16(params, at+2)+16*l; splits=[]
            for s in range(params[layer]):
                split = u16(params, layer+2)+48*s
                splits.append({'sample':u32(params, split), 'notes':list(params[split+6:split+8]),
                               'level':params[split+10], 'fx_level':params[split+11],
                               'base_note':params[split+12], 'fine_tune':params[split+13],
                               'bitrate':u16(params, split+14), 'envelope':list(params[split+16:split+22])})
            layers.append({'splits':splits, 'bend':list(params[layer+4:layer+6]), 'delay':u16(params, layer+7)*4})
        programs.append(layers)
    for sample in samples:
        rates={s['bitrate'] for ls in programs for l in ls for s in l['splits'] if s['sample']==sample['index']}
        assert len(rates)==1, rates
        bitrate=rates.pop(); offset=sample['offset']
        if sample['count']:
            length=(sample['nibbles']+15)//16*8
            pcm=adpcm(waves[offset:offset+length], sample['coefficients'], sample['count'], *sample['history'])
        elif bitrate==2:
            pcm=[v*256 for (v,) in struct.iter_unpack('b', waves[offset:offset+sample['end']])]
        else:
            assert bitrate in (0,3,4,5)
            pcm=[v for (v,) in struct.iter_unpack('>h', waves[offset:offset+sample['end']*2])]
        sample['pcm']=pcm
        assert len(pcm)>0 and 4000<=sample['rate']<=96000
    return samples, programs

def midi(data):
    start=data.index(b'MThd'); data=data[start:]
    assert u32(data,4)==6 and u16(data,10)==1
    division=u16(data,12); assert division<32768
    assert data[14:18]==b'MTrk'
    end=22+u32(data,18); at=22; tick=0; status=0; events=[]
    def vlq():
        nonlocal at
        value=0
        for _ in range(4):
            byte=data[at]; at+=1; value=(value<<7)|(byte&127)
            if byte<128:return value
        raise ValueError('Invalid MIDI VLQ')
    while at<end:
        tick+=vlq()
        if data[at]>=128:status=data[at];at+=1
        assert status
        if status==255:
            kind=data[at];at+=1;size=vlq();payload=data[at:at+size];at+=size
            if kind==81:events.append([tick, 'tempo', int.from_bytes(payload,'big')])
            if kind==47:break
        else:
            assert 128<=status<240
            size=1 if status>>4 in (12,13) else 2
            payload=list(data[at:at+size]);at+=size
            events.append([tick, status, *payload])
    return {'division':division, 'events':events}

def sequence_bank(data):
    table=data[16:]; count=(u32(table,0)&0xffffff)//4
    result={}
    for i in range(count):
        value=u32(table,4*i); index=value>>24; offset=(value&0xffffff)+16
        if offset>=len(data) or data[offset:offset+8]!=b'gcaxMSBM':continue
        size=u32(data,offset+12)
        # GCAX's chunk size excludes the two-byte prefix before the MIDI header.
        result[index]=midi(data[offset+16:offset+18+size])
    return result

def write_wav(path, pcm, rate):
    with wave.open(str(path),'wb') as f:
        f.setnchannels(1);f.setsampwidth(2);f.setframerate(rate)
        f.writeframes(struct.pack('<'+str(len(pcm))+'h',*pcm))

def event_wave(samples, programs, sequence):
    tempo=500000;tick=0;seconds=0.0;program=None
    for event in sequence['events']:
        seconds+=(event[0]-tick)*tempo/(sequence['division']*1000000);tick=event[0]
        if event[1]=='tempo':tempo=event[2]
        elif isinstance(event[1],int) and event[1]>>4==12:program=event[2]
        elif isinstance(event[1],int) and event[1]>>4==9 and event[3]>0:
            assert program is not None
            layers=programs[program];assert len(layers)==1 and len(layers[0]['splits'])==1
            split=layers[0]['splits'][0];sample=samples[split['sample']];note=event[2]
            # Main 0x108ed8/0x109134 sends note 48 immediately; GCAX uses a 44.1kHz reference.
            ratio=struct.unpack('>f',struct.pack('>f',90316.8*2**((48-split['base_note']+split['fine_tune']/128)/12)))[0]
            src_ratio=int(ratio);native_rate=src_ratio*32000/65536;rate=round(native_rate)
            metadata={'program':program,'sample':split['sample'],'note':48,'rate':rate,
                      'fine_tune':split['fine_tune'],'src_ratio':src_ratio,'native_rate':native_rate,
                      'delay_samples':0,'note_seconds':0,'sequence_note':note,'sequence_note_seconds':seconds,
                      'loop_start':sample['loop_start'],'loop_end':sample['end'],'envelope':split['envelope']}
            return sample['pcm'],metadata
    raise ValueError('Sequence has no audible note')

def main():
    OUT.mkdir(parents=True,exist_ok=True); manifest={}
    for filename,bank,label in [('P_SONICTAILS.mlt',3,'sonic'),('v_sonictails_e.mlt',6,'voice'),('windyvalley.mlt',0,'common')]:
        data=(RESEARCH/filename).read_bytes(); entries=banks(data)
        samples, programs=program_bank(entries[1,bank])
        sequences=sequence_bank(entries[4,bank]) if (4,bank) in entries else {}
        if label=='voice':sequences=sequence_bank(banks((RESEARCH/'P_SONICTAILS.mlt').read_bytes())[4,6])
        events={}
        wanted={'homing':0,'charge':5,'dash':6,'release':7} if label=='sonic' else {'jump':17,'brake':18,'land':19,'hurt':23,'hit':27,'step':31,'damage_effect':23} if label=='common' else {'wall_voice':0,'damage_voice':11,'jump_voice_1':14,'jump_voice_2':15}
        for name,index in wanted.items():
            pcm,event=event_wave(samples,programs,sequences[index])
            write_wav(OUT/(name+'.wav'),pcm,event['rate'])
            events[name]={'sequence':index,**event}
        for sample in samples:
            pcm=sample.pop('pcm'); name=f'{label}_{sample["index"]:02d}.wav'
            if label!='common':
                write_wav(OUT/name,pcm,sample['rate'])
                sample['file']=name; sample['sha256']=hashlib.sha256((OUT/name).read_bytes()).hexdigest()
        manifest[label]={'source':filename,'sha256':hashlib.sha256(data).hexdigest(),'samples':samples,'programs':programs,'sequences':sequences,'events':events}
        if label=='voice':manifest[label]['sequence_source']='P_SONICTAILS.mlt'
        print(label,len(samples),'samples',len(sequences),'sequences')
    (OUT/'source_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')

if __name__=='__main__':main()
