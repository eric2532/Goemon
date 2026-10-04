"""Check delivered bytes and archive contents from any independent checkout."""
from pathlib import Path
import json,hashlib,zipfile
P=Path(__file__).resolve().parents[1]
refs=json.loads((P/'references/manifest.json').read_text())['files']
for a in refs:
 f=P/'references'/a['file_name'];assert f.stat().st_size==a['bytes'];assert hashlib.sha256(f.read_bytes()).hexdigest()==a['sha256']
lib=json.loads((P/'library_validation.json').read_text());assert hashlib.sha256((P/'Ninja_Dogs_Collection.blend').read_bytes()).hexdigest()==lib['sha256']
assets=json.loads((P/'asset_manifest.json').read_text())['assets'];assert len(assets)==10
for a in assets:
 for typ,key in [('source','source_sha256'),('export','glb_sha256')]:assert hashlib.sha256((P/a[typ]).read_bytes()).hexdigest()==a[key]
 for v in ['front','side','threequarter','rear','backthreequarter','portrait']:assert (P/'renders'/f"{a['id']}_{v}.png").stat().st_size>1000
 for key in ['comparison','views']:assert (P/a[key]).stat().st_size>1000
archives=json.loads((P/'archive_manifest.json').read_text())
for a in archives:
 f=P/'downloads'/a['file'];assert f.stat().st_size==a['bytes']<15_000_000;assert hashlib.sha256(f.read_bytes()).hexdigest()==a['sha256']
 with zipfile.ZipFile(f) as z:
  assert z.testzip() is None
  for n in z.namelist():assert not n.startswith('/') and '..' not in Path(n).parts
assert len(list((P/'sources').glob('*.blend')))==10;assert len(list((P/'exports').glob('*.glb')))==10
print(json.dumps({'reference_hashes':10,'source_hashes':10,'export_hashes':10,'renders':60,'comparison_and_view_sheets':20,'zip_archives_verified':len(archives),'largest_zip_bytes':max(a['bytes'] for a in archives),'result':'passed'},indent=2))
