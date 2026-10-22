"""Rebuild the combo, finisher and special slash mixes from the downloaded user-selected WAV.
Usage: bundled-python docs/slash-audio/build_slashes.py /path/to/source.wav
"""
from pathlib import Path
import hashlib,json,subprocess,sys,wave
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
RATE=48000
# The main slice carries the swing; a quieter, early accent adds the blade edge.
MIXES=[
 ('explorer',0,(13.41,14.11),(36.93,37.13),1.25,.15),
 ('explorer',1,(16.84,17.49),(39.48,39.65),1.2,.17),
 ('explorer',2,(14.77,15.49),(18.31,18.53),1.2,.21),
 ('ninja',0,(26.24,26.70),(28.98,29.11),1.5,.12),
 ('ninja',1,(27.39,27.81),(20.35,20.48),1.5,.13),
 ('ninja',2,(38.39,38.83),(34.31,34.46),1.4,.17),
]
def cut(source,bounds,tempo):
 command=['ffmpeg','-v','error','-ss',str(bounds[0]),'-t',str(bounds[1]-bounds[0]),'-i',str(source),'-af',f'highpass=f=110,atempo={tempo}','-ar',str(RATE),'-ac','2','-f','f32le','pipe:1']
 return np.frombuffer(subprocess.check_output(command),dtype='<f4').reshape(-1,2).copy()
def main():
 source=Path(sys.argv[1]);outputs=[]
 for style,index,main_slice,accent_slice,tempo,accent_gain in MIXES:
  base=cut(source,main_slice,tempo);accent=cut(source,accent_slice,tempo)
  # Layer the transient near the start so sound responds immediately to contact.
  offset=int(.012*RATE);mixed=base.copy();length=min(len(accent),len(mixed)-offset)
  mixed[offset:offset+length]+=accent[:length]*accent_gain
  # Finishers add a low blade impact and a delayed metallic snap.
  extra_layers=[]
  if index==2:
   bounds=(22.03,22.53) if style=='explorer' else (36.93,37.23)
   impact=cut(source,bounds,1.05 if style=='explorer' else 1.25)
   impact_offset=int(.045*RATE);count=min(len(impact),len(mixed)-impact_offset)
   mixed[impact_offset:impact_offset+count]+=impact[:count]*.65
   extra_layers.append({'source_seconds':list(bounds),'gain':.65,'offset_seconds':.045})
  peak_db=-6.0 if index==2 else -9.0
  mixed*=10**(peak_db/20)/max(float(np.max(np.abs(mixed))),1e-8)
  fade_in=min(int(.003*RATE),len(mixed));fade_out=min(int(.025*RATE),len(mixed))
  mixed[:fade_in]*=np.linspace(0,1,fade_in)[:,None]
  mixed[-fade_out:]*=np.linspace(1,0,fade_out)[:,None]
  target=ROOT/f'assets/rogue/audio/blade-{style}-{index}.wav'
  with wave.open(str(target),'wb') as out:
   out.setnchannels(2);out.setsampwidth(2);out.setframerate(RATE)
   out.writeframes(np.rint(np.clip(mixed,-1,1)*32767).astype('<i2').tobytes())
  row={'path':'audio/'+target.name,'main_source_seconds':list(main_slice),'accent_source_seconds':list(accent_slice),'tempo':tempo,'accent_gain':accent_gain,'accent_offset_seconds':.012,'role':'finisher' if index==2 else 'light','extra_layers':extra_layers,'duration_seconds':round(len(mixed)/RATE,4),'peak_dbfs':round(20*np.log10(float(np.max(np.abs(mixed)))),2),'sha256':hashlib.sha256(target.read_bytes()).hexdigest()}
  outputs.append(row)
 # Dash specials layer alternating cuts across the duration of the dash.
 for style,first,second,delay,tempo in [
  ('explorer',(18.30,18.75),(23.83,24.16),.095,1.15),
  ('ninja',(25.10,25.50),(28.98,29.30),.075,1.25),
 ]:
  base=cut(source,first,tempo);accent=cut(source,second,tempo)
  offset=int(delay*RATE);mixed=np.zeros((max(len(base),offset+len(accent)),2))
  mixed[:len(base)]+=base
  mixed[offset:offset+len(accent)]+=accent*.75
  mixed*=10**(-7.5/20)/max(float(np.max(np.abs(mixed))),1e-8)
  fade=int(.025*RATE);mixed[:144]*=np.linspace(0,1,144)[:,None];mixed[-fade:]*=np.linspace(1,0,fade)[:,None]
  target=ROOT/f'assets/rogue/audio/blade-{style}-special.wav'
  with wave.open(str(target),'wb') as out:
   out.setnchannels(2);out.setsampwidth(2);out.setframerate(RATE);out.writeframes(np.rint(np.clip(mixed,-1,1)*32767).astype('<i2').tobytes())
  outputs.append({'path':'audio/'+target.name,'role':'special','main_source_seconds':list(first),'accent_source_seconds':list(second),'tempo':tempo,'accent_gain':.75,'accent_offset_seconds':delay,'duration_seconds':round(len(mixed)/RATE,4),'peak_dbfs':-7.5,'sha256':hashlib.sha256(target.read_bytes()).hexdigest()})
 manifest={'title':'Best Sword Sounds (Slice/Slash/Crash/Swoosh/etc)','source_url':'https://www.youtube.com/watch?v=EgRvVq8mStE','retrieved_on':'2026-10-15','usage':'Explorer and Ninja light combos, stronger third-hit finishers, and right-click Cross Slash/Dash Cut specials','processing':'Layered slash mixes with dedicated staggered special cuts and heavier finisher impacts. Trimmed, high-pass at 110 Hz, tempo shortened without shifting pitch, peak normalized to -9 dBFS for light hits, -6 dBFS for finishers, -7.5 dBFS for specials, 3 ms attack and 25 ms tail fade, stereo 48 kHz PCM16.','license':'Not established by this download','samples':outputs}
 (ROOT/'assets/rogue/audio/explorer_ninja_slashes.source.json').write_text(json.dumps(manifest,indent=2)+'\n')
 p=ROOT/'assets/rogue/provenance.json';data=json.loads(p.read_text())
 note='Explorer and Ninja blade audio was remixed on 2026-10-15 from the user-selected video; see audio/explorer_ninja_slashes.source.json. '
 if not data['note'].startswith(note):data['note']=note+data['note']
 for item in data['files']:
  for output in outputs:
   if item['path']==output['path']:
    if output.get('role')!='special':
     item.setdefault('original_source',item['source']);item.setdefault('original_sha256',item['sha256'])
    item['source']=manifest['source_url'];item['sha256']=output['sha256'];item['processing_manifest']='audio/explorer_ninja_slashes.source.json'
 for output in outputs:
  if not any(item['path']==output['path'] for item in data['files']):
   data['files'].append({'path':output['path'],'source':manifest['source_url'],'sha256':output['sha256'],'processing_manifest':'audio/explorer_ninja_slashes.source.json'})
 p.write_text(json.dumps(data,indent=2)+'\n')
 print(json.dumps(outputs,indent=2))
if __name__=='__main__':main()
