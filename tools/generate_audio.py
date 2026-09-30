import math, wave, struct, random
from pathlib import Path
p=Path(__file__).resolve().parents[1] / 'audio'
p.mkdir(exist_ok=True)
r=random.Random(59)
sr=22050
for name,duration,freq in [('swing',.19,500),('heavy_swing',.32,220),('hit',.15,140),('heavy_hit',.30,85),('jump',.22,440),('land',.13,90),('dash',.24,300),('hurt',.24,160),('step',.06,150),('spark',.4,880)]:
    data=[]; smooth=0
    for i in range(int(sr*duration)):
        t=i/sr; k=t/duration; smooth=.55*smooth+.45*r.uniform(-1,1)
        f=freq*(1+k if name in ('jump','spark') else 1-.6*k)
        tone=math.sin(2*math.pi*f*t)
        noise=.8 if name in ('swing','heavy_swing','dash','step','land') else .25
        value=(tone*(1-noise)+smooth*noise)*math.sin(math.pi*min(1,k*5))*(1-k)**2*.65
        data.append(int(max(-1,min(1,value))*32767))
    with wave.open(str(p/(name+'.wav')),'wb') as w:
        w.setnchannels(1);w.setsampwidth(2);w.setframerate(sr);w.writeframes(struct.pack('<%dh'%len(data),*data))
notes=[62,69,74,76,81,76,74,69,65,69,74,77,81,77,74,69]
data=[];smooth=0
for i in range(sr*24):
    t=i/sr; step=int(t/.375); local=t%.375
    midi=notes[step%len(notes)];f=440*2**((midi-69)/12)
    env=(1-math.exp(-local*70))*math.exp(-local*9)
    mel=(math.sin(2*math.pi*f*t)+.20*math.sin(4*math.pi*f*t))*.17*env
    pad=sum(math.sin(2*math.pi*fq*t+math.sin(t*.5)*.06) for fq in [146.8324,220,293.6648])*.032
    smooth=smooth*.995+r.uniform(-1,1)*.005
    v=(mel+pad+smooth*.45)*min(1,t/1.5,(24-t)/1.5)
    data.append(int(v*32767))
with wave.open(str(p/'sanctuary.wav'),'wb') as w:
    w.setnchannels(1);w.setsampwidth(2);w.setframerate(sr);w.writeframes(struct.pack('<%dh'%len(data),*data))
