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

def save(name,x,peak=.78):
    fade=min(240,len(x)//4)
    x[:fade]*=np.linspace(0,1,fade)[:,None]
    x[-fade:]*=np.linspace(1,0,fade)[:,None]
    # Consistent peak headroom; never hard-clip the metallic attack.
    x*=peak/max(np.max(np.abs(x)),1e-9)
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
    x=.50*band(len(t),220,1450)*air+.41*band(len(t),1400,6300)*edge
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
    # A drawn-out shearing zip, rather than an abrupt metallic knock.
    duration=.33 if heavy else .25
    t=np.arange(int(SR*duration))/SR
    attack=1-np.exp(-t*150)
    shear=attack*np.exp(-((t-.026)/(.042 if heavy else .032))**2)
    rasp=attack*np.exp(-t/(.085 if heavy else .065))
    x=.34*band(len(t),1850,7800)*shear+.24*band(len(t),1100,4600)*rasp
    # Only a trace of steel; remove the low/mid resonances that read as an impact.
    for f,amp in [(2280,.006),(3670,.004)]:
        x+=np.sin(2*np.pi*f*t)*amp*attack*np.exp(-t/.05)
    y=stereo(x,np.tanh((t-.035)*28)*.35)
    delay=int(.007*SR);y[delay:]+=y[:-delay,::-1]*.05
    return y

def energy_wave():
    # Edge leaving the sword, then a broad energy rush with a falling shimmer.
    t=np.arange(int(SR*.72))/SR
    attack=1-np.exp(-t*180)
    edge=attack*np.exp(-((t-.035)/.04)**2)
    rush=attack*np.exp(-((t-.07)/.18)**2)
    trail=attack*np.exp(-t/.20)
    x=.32*band(len(t),2000,8500)*edge+.42*band(len(t),480,3400)*rush
    x+=.16*band(len(t),1400,5800)*trail
    phase=np.cumsum(1750*np.exp(-t*2.0))*2*np.pi/SR
    x+=(np.sin(phase)+.3*np.sin(phase*1.53))*.035*trail
    y=stereo(x,np.tanh((t-.05)*7)*.23)
    delay=int(.037*SR);y[delay:]+=y[:-delay,::-1]*.12
    return y

if __name__=='__main__':
    OUT.mkdir(exist_ok=True,parents=True)
    for i in range(3):save('claymore-sweep-'+str(i),sweep(i))
    for heavy in (False,True):save('claymore-impact-'+('heavy' if heavy else 'light'),impact(heavy),peak=.60)
    save('claymore-wave',energy_wave(),peak=.72)
