"""Reuse original level-five drain pixels/audio and the shared recovered boss wards."""
import argparse, hashlib, json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/characters/crossgate/falken/spells'
def prepare(source):
 assets=source/'godot/assets'
 native=json.loads((assets/'humanoid-spells/manifest.json').read_text())
 row=native['clips']['110065'];clip={k:row[k] for k in ['frames','columns','width','height','duration','bounds','sha256']}
 raw=(assets/row['file']).read_bytes();assert hashlib.sha256(raw).hexdigest()==row['sha256']
 shared=json.loads((ROOT/'assets/characters/crossgate/skill_tiers/manifest.json').read_text())['clips'].get('110065')
 files={}
 if shared:
  path=shared['runtime_path'];assert hashlib.sha256((ROOT/path.removeprefix('res://')).read_bytes()).hexdigest()==row['sha256']
 else:path='res://assets/characters/crossgate/falken/spells/110065.png';files['110065.png']=raw
 clip['runtime_path']=path;clip['sounds']=[{'at_ms':c['atMs'],'id':c['id']} for c in row['sounds']]
 sounds={}
 for cue in row['sounds']:
  raw=(assets/cue['file']).read_bytes();digest=hashlib.sha256(raw).hexdigest();assert digest==cue['sha256']
  name=Path(cue['file']).name
  found=next((p for p in sorted((ROOT/'assets').glob('**/'+name)) if p.parent!=OUT and hashlib.sha256(p.read_bytes()).hexdigest()==digest),None)
  if found:path='res://'+str(found.relative_to(ROOT))
  else:path='res://assets/characters/crossgate/falken/spells/'+name;files[name]=raw
  sounds[str(cue['id'])]={'runtime_path':path,'sha256':digest}
 proof=(ROOT/'assets/references/falken/original.json').read_bytes()
 meta={'snapshot_sha256':native['snapshotSha256'],'source_rules_sha256':hashlib.sha256(proof).hexdigest(),'clips':{'110065':clip},'sounds':sounds,
  'skills':{'drain':native['skills']['h_drain']['5']},
  'limits':['Original Holy Shield/reflect/recovery art reuses the shared Ruby spell pool. Instant death uses the original common cast and victim death gesture; its unique target artwork is unverified. Real-time cadence and maze generation are fitted.']}
 return files,meta
def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--source',type=Path,default=ROOT.parent/'Magic Power');p.add_argument('--check',action='store_true');a=p.parse_args()
 files,meta=prepare(a.source.resolve())
 if a.check:
  assert json.loads((OUT/'manifest.json').read_text())==meta
  for name,raw in files.items():assert (OUT/name).read_bytes()==raw,name
  print('FALKEN_SPELL_SOURCE_CHECK native drain pixels/audio and source boss rules preserved')
 else:
  OUT.mkdir(parents=True,exist_ok=True)
  for name,raw in files.items():(OUT/name).write_bytes(raw)
  (OUT/'manifest.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
  print('Prepared original drain sheet/audio; shared wards and recovery remain reused')
if __name__=='__main__':main()
