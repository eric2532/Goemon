#!/usr/bin/env python3
"""Extract the five user-selected bow effects. Pass the decoded source WAV."""
import array
import hashlib
import json
import math
from pathlib import Path
import subprocess
import sys
import wave
ROOT=Path(__file__).resolve().parents[1]
DEST=ROOT/'assets/rogue/audio'
SOURCE=Path(sys.argv[1])
RATE=48000
# Silence-separated events, including a small lead-in and their complete tails.
EVENTS=[(.420,.925),(1.390,1.745),(2.255,2.660),(3.160,3.625),(4.160,4.590)]
CHOICES=[('bow-ranger-rapid-0',2,1.30,-10,'Ranger regular shot variant 1'),
         ('bow-ranger-rapid-1',3,1.40,-10,'Ranger regular shot variant 2'),
         ('bow-ranger-power',1,1.10,-8,'Ranger power shot'),
         ('bow-tower-0',4,1.10,-12,'Tower release variant 1'),
         ('bow-tower-1',5,1.10,-12,'Tower release variant 2')]
records=[]
for name,index,tempo,peak_db,role in CHOICES:
 start,end=EVENTS[index-1]
 result=subprocess.run(['ffmpeg','-v','error','-ss',str(start),'-t',str(end-start),'-i',str(SOURCE),'-af',f'highpass=f=90,atempo={tempo}','-ar',str(RATE),'-ac','2','-f','f32le','pipe:1'],check=True,capture_output=True)
 samples=array.array('f');samples.frombytes(result.stdout)
 peak=max(abs(v) for v in samples);assert peak>.001
 gain=10**(peak_db/20)/peak;frames=len(samples)//2;pcm=array.array('h')
 for i,value in enumerate(samples):
  frame=i//2;fade=min(1,frame/(RATE*.003),(frames-1-frame)/(RATE*.020))
  pcm.append(round(max(-1,min(1,value*gain*fade))*32767))
 path=DEST/(name+'.wav')
 with wave.open(str(path),'wb') as output:
  output.setnchannels(2);output.setsampwidth(2);output.setframerate(RATE);output.writeframes(pcm.tobytes())
 records.append({'file':path.name,'source_effect':index,'source_seconds':[start,end],'role':role,'tempo':tempo,'duration_seconds':round(frames/RATE,5),'peak_dbfs':round(20*math.log10(max(abs(v) for v in pcm)/32767),2),'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
manifest={'title':'Sound arrow effect','channel':'Volk Mark','source_url':'https://www.youtube.com/watch?v=_1GYa-CG-cU','retrieved_on':'2026-10-17','source_effect_count':5,'source_wav_sha256':hashlib.sha256(SOURCE.read_bytes()).hexdigest(),'license':'Not established by download; user supplied source for this prototype.','processing':'Five silence-separated releases. 90Hz high-pass, tempo shortened without pitch shift, 3ms/20ms fades, conservative peak normalization; stereo 48kHz PCM16.','generator':'tools/build_bow_source_audio.py','samples':records}
(DEST/'bow_source.source.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(records,indent=2))
