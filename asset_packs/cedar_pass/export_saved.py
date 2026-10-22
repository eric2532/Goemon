"""Export hand-edited sources, retaining interior groups. Update interiors.json if collider proxies change."""
from pathlib import Path
import json,bpy
P=Path(__file__).resolve().parent
exec(compile((P/'build_interiors.py').read_text().split("\nif __name__=='__main__':")[0],str(P/'build_interiors.py'),'exec'))
entries=json.loads((P/'manifest.json').read_text());meta=json.loads((P/'interiors.json').read_text());result=[]
for a in entries:
 bpy.ops.wm.open_mainfile(filepath=str(P/'sources'/f'{a["id"]}.blend'));bpy.context.view_layer.update()
 if bpy.context.scene.get('cedar_interior_revision',0)==2:
  updated=export_parts(a['id']);a.update(updated);meta[a['id']].update(updated);result.append(a)
 else:result.append(export(a['id'],a['category']))
(P/'manifest.json').write_text(json.dumps(result,indent=2));(P/'interiors.json').write_text(json.dumps(meta,indent=2))
