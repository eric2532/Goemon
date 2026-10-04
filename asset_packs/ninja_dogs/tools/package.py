from pathlib import Path
import zipfile,json,hashlib
P=Path(__file__).resolve().parents[1];D=P/'downloads';D.mkdir(exist_ok=True);rows=json.loads((P/'reference_observations.json').read_text())['notes'];report=[]
def write(name,files):
 path=D/(name+'.zip')
 with zipfile.ZipFile(path,'w',zipfile.ZIP_DEFLATED,6) as z:
  for f in files:z.write(f,f.relative_to(P))
 with zipfile.ZipFile(path) as z:assert z.testzip() is None
 assert path.stat().st_size<15_000_000,(path.name,path.stat().st_size)
 report.append({'file':path.name,'bytes':path.stat().st_size,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'crc_test':'passed'})
for r in rows:
 id=r['id'];name=r['name'];ref=next((P/'references').glob(id+'-*.png'));preview=P/'previews'/f'{id}_comparison.jpg'
 write(f'{id}_{name}_Blender',[P/'sources'/f'{id}_{name}.blend',ref,preview,P/'README.md'])
 write(f'{id}_{name}_GLB',[P/'exports'/f'{id}_{name}.glb',preview,P/'README.md'])
write('Review_Gallery',sorted(f for f in (P/'gallery').rglob('*') if f.is_file()))
write('Rebuild_Tools',sorted(f for f in (P/'tools').glob('*.py'))+[P/'README.md',P/'reference_observations.json',P/'validation.json',P/'library_validation.json',P/'visual_review.json',P/'asset_manifest.json',P/'gallery_test.json'])
(P/'archive_manifest.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
