"""Package only validated current artifacts. No remote publication occurs here."""
import json,hashlib,zipfile
from pathlib import Path
R=Path(__file__).resolve().parents[1]
names=['sen','raku','izumi','gaku','shiro','banji','touma','roan','nagi','kuren']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
reports=[];files=[]
for name in names:
 p=R/'validation'/f'{name}.json';r=json.loads(p.read_text());assert r['status']=='PASS';reports.append(r)
 assert r['source_sha256']==sha(R/'blend'/f'{name}.blend'),name+' stale source validation'
 assert r['glb_sha256']==sha(R/'glb'/f'{name}.glb'),name+' stale GLB validation'
 for typ,ext in [('blend','blend'),('glb','glb')]:
  p=R/typ/f'{name}.{ext}';files.append(dict(path=str(p.relative_to(R)),bytes=p.stat().st_size,sha256=sha(p)))
 for suffix in ('comparison','turnaround'):
  assert (R/'previews'/f'{name}_{suffix}.jpg').exists()
summary=dict(status='PASS',characters=10,static_unrigged=True,blender_version='4.3.2',source_reopen_and_glb_reimport=True,total_evaluated_triangles=sum(r['source']['triangles'] for r in reports),max_bounds_error=max(r['bounds_max_error'] for r in reports),characters_validated=[dict(name=r['character'],triangles=r['source']['triangles'],source_objects=r['source']['objects'],bounds=r['source']['bounds_max']) for r in reports])
(R/'validation'/'summary.json').write_text(json.dumps(summary,indent=2))
(R/'models_manifest.json').write_text(json.dumps(dict(schema=1,files=files),indent=2))
release=R/'releases';release.mkdir(exist_ok=True);archive=release/'approved-ten-blender-models.zip'
paths=[R/'README.md',R/'models_manifest.json']+list((R/'blend').glob('*.blend'))+list((R/'glb').glob('*.glb'))+list((R/'validation').glob('*.json'))+list((R/'tools').glob('*.py'))+list((R/'previews').glob('*_comparison.jpg'))+list((R/'previews').glob('*_turnaround.jpg'))+[R/'previews'/'lineup.jpg']
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for p in sorted(paths):z.write(p,Path('approved-ten')/p.relative_to(R))
with zipfile.ZipFile(archive) as z:assert z.testzip() is None;assert sum(x.endswith('.blend') for x in z.namelist())==10;assert sum(x.endswith('.glb') for x in z.namelist())==10
assert archive.stat().st_size<99*1024*1024,'Split archive before GitHub publication'
(release/'approved-ten-blender-models.zip.sha256').write_text(sha(archive)+'  '+archive.name+'\n')
print(json.dumps(dict(archive=str(archive.relative_to(R)),bytes=archive.stat().st_size,sha256=sha(archive),validation=summary),indent=2))
