import bpy,hashlib
from pathlib import Path
p=Path(__file__).resolve().parents[1];path=p/'Musashi_Final.blend';sha=hashlib.sha256(path.read_bytes()).hexdigest();bpy.ops.wm.open_mainfile(filepath=str(path));sc=bpy.context.scene
sc.render.resolution_x=600;sc.render.resolution_y=1080;sc.cycles.samples=16
key=bpy.data.objects['Light_Key_Soft'];fill=bpy.data.objects['Light_Fill_Soft'];bg=sc.world.node_tree.nodes.get('Background')
# Same approved camera; changed light balance only. Painting is stored in material/rest data.
key.data.energy=260;fill.data.energy=850;bg.inputs[1].default_value=.65;sc.render.filepath=str(p/'Validation/lighting_fill_side.png');bpy.ops.render.render(write_still=True)
key.data.energy=0;fill.data.energy=0;bg.inputs[0].default_value=(1,1,1,1);bg.inputs[1].default_value=1
sc.render.filepath=str(p/'Validation/lighting_ambient_only.png');bpy.ops.render.render(write_still=True)
assert sha==hashlib.sha256(path.read_bytes()).hexdigest();print('Lighting independence views complete. Saved presentation unchanged.')
