"""Reproducible original claymore sound design. Requires numpy; writes 48 kHz PCM.
Air sweeps, high-frequency cutting transients and short inharmonic metal tails.
No sampled third-party recordings, kick-like sine drops or sub-bass impacts.
"""
from pathlib import Path
import wave
import numpy as np

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/rogue/audio'
SR=48000
RNG=np.random.default_rng(2301)

def band(n, lo, hi):
    # FFT-shaped noise avoids phasey repeated oscillators in the blade-air layer.
    f=np.fft.rfftfreq(n,1/SR)
    spectrum=np.fft.rfft(RNG.normal(size=n))
    curve=(1-np.exp(-(f/max(lo,1))**4))*np.exp(-(f/hi)**4)
    x=np.fft.irfft(spectrum*curve,n)
    return x/max(np.std(x),1e-9)

def stereo(x, pan):
    return np.stack((x*np.sqrt((1-pan)/2), x*np.sqrt((1+pan)/2)),axis=1)

def save(name,x):
    fade=min(240,len(x)//4)
    x[:fade]*=np.linspace(0,1,fade)[:,None]
    x[-fade:]*=np.linspace(1,0,fade)[:,None]
    # Consistent peak headroom; never hard-clip the metallic attack.
    x*=.78/max(np.max(np.abs(x)),1e-9)
    with wave.open(str(OUT/(name+'.wav')),'wb') as w:
        w.setnchannels(2);w.setsampwidth(2);w.setframerate(SR)
        w.writeframes((x*32767).astype('<i2').tobytes())
    print(name, 'duration',round(len(x)/SR,3),'peak',round(float(abs(x).max()),3),'rms',round(float(np.sqrt(np.mean(x*x))),3))

def sweep(index):
    duration=[.43,.46,.57][index]
    t=np.arange(int(SR*duration))/SR
    # Peak 65ms after trigger, close to the actual claymore contact frame.
    peak=.065 if index<2 else .075
    air=np.exp(-((t-peak)/np.where(t<peak,.046,.105 if index<2 else .14))**2)
    edge=np.exp(-((t-peak-.018)/.045)**2)
    x=.62*band(len(t),140,1250)*air+.34*band(len(t),1200,5800)*edge
    # A quiet travelling steel edge, not a bell or a low pitched hammer.
    freq=(1650 if index<2 else 1280)*np.exp(-t*2.3)
    phase=np.cumsum(freq)*2*np.pi/SR
    metal=(np.sin(phase)+.35*np.sin(phase*1.47))*.028*np.exp(-t*8)*(1-np.exp(-t*180))
    x+=metal
    pan=np.tanh((t-peak)*12)*(.45 if index%2==0 else -.45)
    y=stereo(x,pan)
    # Short, quiet room tail retains scale without obscuring consecutive cuts.
    delay=int(.023*SR);y[delay:]+=y[:-delay,::-1]*.13
    return y

def impact(heavy):
    duration=.46 if heavy else .32
    t=np.arange(int(SR*duration))/SR
    attack=1-np.exp(-t*1200)
    shear=attack*np.exp(-t/(.045 if heavy else .032))
    rasp=attack*np.exp(-t/(.11 if heavy else .075))*(.65+.35*np.sin(t*270)**2)
    x=.47*band(len(t),1300,7600)*shear+.24*band(len(t),550,3400)*rasp
    # Inharmonic steel resonances supply edge; little energy under 150 Hz.
    for f,amp in [(920,.042),(1473,.03),(2381,.018),(3517,.009)]:
        x+=np.sin(2*np.pi*f*(.83 if heavy else 1)*t)*amp*attack*np.exp(-t/(.105 if heavy else .065))
    x+=.055*band(len(t),180,650)*attack*np.exp(-t/.028)
    y=stereo(x,np.zeros_like(t))
    delay=int(.013*SR);y[delay:,1]+=x[:-delay]*.075
    return y

if __name__=='__main__':
    OUT.mkdir(exist_ok=True,parents=True)
    for i in range(3):save('claymore-sweep-'+str(i),sweep(i))
    for heavy in (False,True):save('claymore-impact-'+('heavy' if heavy else 'light'),impact(heavy))
