"""Export edited sources without procedurally rebuilding them."""
from pathlib import Path
import json
P=Path(__file__).resolve().parent
exec(compile((P/'build_pack.py').read_text().split('\nspec=')[0],str(P/'build_pack.py'),'exec'))
entries=json.loads((P/'manifest.json').read_text());result=[]
for a in entries:
 bpy.ops.wm.open_mainfile(filepath=str(P/'sources'/f'{a["id"]}.blend'))
 bpy.context.view_layer.update()
 result.append(export(a['id'],a['category']))
(P/'manifest.json').write_text(json.dumps(result,indent=2))
