"""Refresh source/export hashes after running tests/tidefall-town/checks.gd."""
import hashlib,json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
out=root/'docs/tidefall-town'
placements=json.loads((out/'placements.json').read_text())
names={'timber_house':'Timber House','noren_shop':'Blue Noren Shop','two_story_inn':'Red Curtain Inn','corner_house':'Gable Corner House','plaster_storehouse':'Plaster Storehouse'}
assets=[]
for key,title in names.items():
    files={kind:f'assets/{folder}/town/{key}.{ext}' for kind,folder,ext in [('source','blender','blend'),('runtime','models','glb')]}
    assets.append({'asset_id':'town/'+key,'display_name':title,'authorship':'Original Blender geometry with original Edo texture kit; no downloaded third-party models','files':files,'sha256':{kind:hashlib.sha256((root/path).read_bytes()).hexdigest() for kind,path in files.items()},'thumbnail':f'docs/tidefall-town/{key}.png','used_by':[p['instance_id'] for p in placements if p['asset_id']=='town/'+key]})
(out/'asset-catalog.json').write_text(json.dumps({'schema_version':1,'area':'Tidefall Sanctuary','assets':assets,'placements':'placements.json'},indent=2)+'\n')
