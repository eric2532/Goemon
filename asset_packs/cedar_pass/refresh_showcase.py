"""Refresh the full-scale Blender/GLB display from the saved game exports."""
from pathlib import Path
import bpy,json
P=Path(__file__).resolve().parent
exec(compile((P/'build_pack.py').read_text().split('\nspec=')[0],str(P/'build_pack.py'),'exec'))
reset()
for i,a in enumerate(json.loads((P/'manifest.json').read_text())):import_asset(a['id'],((i%6)*18,(i//6)*25,0))
box('Showcase ground',(45,32,-.2),(120,120,.4),'paper')
bpy.ops.wm.save_as_mainfile(filepath=str(P/'sources/showcase.blend'))
bpy.ops.export_scene.gltf(filepath=str(P/'showcase.glb'),export_format='GLB')
