"""Generate only the new leap/stomp cues. Existing audio files are untouched."""
import math, random, struct, wave
from pathlib import Path
root=Path(__file__).resolve().parents[1]/'audio';rate=44100
for name,duration in [('sky_leap',.24),('sky_stomp',.36)]:
 rng=random.Random(871 if name=='sky_leap' else 932);samples=[];low=0.;phase=0.
 for i in range(int(duration*rate)):
  t=i/rate;k=t/duration;noise=rng.uniform(-1,1);low=.85*low+.15*noise
  if name=='sky_leap':
   phase+=2*math.pi*(260+1800*k*k)/rate
   envelope=math.sin(math.pi*k)**.65
   v=(low*.9+math.sin(phase)*.18+noise*.09)*envelope
  else:
   phase+=2*math.pi*(95*math.exp(-t*17)+38)/rate
   v=math.sin(phase)*math.exp(-t*16)*.65+low*math.exp(-t*10)*.8+noise*math.exp(-t*85)*.22
   v*=min(1,t/.002)
  v*=min(1,(duration-t)/.016)
  samples.append(v)
 peak=max(map(abs,samples));data=[int(v/peak*.88*32767) for v in samples]
 with wave.open(str(root/(name+'.wav')),'wb') as w:
  w.setnchannels(1);w.setsampwidth(2);w.setframerate(rate);w.writeframes(struct.pack('<%dh'%len(data),*data))
 print(name,len(data)/rate,round(max(map(abs,data))/32767,3))
