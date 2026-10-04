"""Add one original enterable kit through the existing Tidefall Blender pipeline.
Never rebuild or overwrite the five existing town sources.
"""
import bpy,math,json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
SRC=ROOT/'assets/blender/town';OUT=ROOT/'assets/models/town'
target=SRC/'open_teahouse.blend'
assert not target.exists(), 'Existing open-house source must not be overwritten'
library=(ROOT/'tools/build_tidefall_town.py').read_text()
exec(library[library.index('M={}'):library.index('def build(')],globals())
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=1
# Source metres match the original 8x6 kit. Runtime enlarges all houses uniformly 4x.
box('Walkable timber floor',(0,-.04,0),(8,.10,6),'wood')
box('West wall',(-3.9,2,0),(.2,4,6),'plaster')
box('East wall',(3.9,2,0),(.2,4,6),'plaster')
box('Rear wall',(0,2,-2.9),(8,4,.2),'plaster')
for side in [-1,1]:
 box('Open front side',(side*2.75,2,2.9),(2.5,4,.2),'plaster')
 box('Door jamb',(side*1.5,1.25,3.03),(.10,2.5,.18),'wood')
 box('Corner upright',(side*3.86,2,3.04),(.14,4,.2),'wood')
 window(side*2.75,1.35,1.8,2.1,3.03)
box('Open door lintel',(0,3.25,2.9),(3,1.5,.2),'wood')
box('Upper facade',(0,3.55,3.04),(7.8,.7,.06),'plaster')
for y in [.2,2.6,4.05]:
 for side in [-1,1]:box('Front rail',(side*2.75,y,3.08),(2.5,.10,.10),'wood')
roof(4.2,w=8.6,d=7.4,rise=1.85)
# Furniture stays at human scale after the 4x building scale; leave the center and doorway open.
for side in [-1,1]:
 box('Communal table',(side*2.2,.25,-1.2),(1.25,.07,.5),'wood')
 for x in [-.45,.45]:
  box('Table leg',(side*2.2+x,.105,-1.2),(.07,.21,.38),'wood')
 box('Bench',(side*2.2,.15,-.35),(1.25,.055,.24),'wood')
 for x in [-.45,.45]:box('Bench foot',(side*2.2+x,.055,-.35),(.06,.11,.2),'wood')
box('Merchant counter',(0,.28,-2.2),(2.3,.12,.35),'wood')
for x in [-.9,.9]:box('Counter leg',(x,.1,-2.2),(.08,.2,.3),'wood')
for x in [-2.4,-1.9,1.9,2.4]:box('Tea tray',(x,.30,-1.2),(.14,.03,.14),'red')
for group in ['Body','Roof']:
 obs=[o for o in bpy.context.scene.objects if o.type=='MESH' and o.name.startswith('Roof')==(group=='Roof')]
 bpy.ops.object.select_all(action='DESELECT')
 for o in obs:o.select_set(True)
 bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.join();o=bpy.context.object;o.name=group
 bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
 uv=o.data.uv_layers.active or o.data.uv_layers.new(name='TownUV');uv.active_render=True
 for poly in o.data.polygons:
  axis=max(range(3),key=lambda i:abs(poly.normal[i]));axes=[i for i in range(3) if i!=axis]
  for li in poly.loop_indices:
   v=o.matrix_world@o.data.vertices[o.data.loops[li].vertex_index].co;uv.data[li].uv=(v[axes[0]]*.45,v[axes[1]]*.45)
bpy.context.scene['authoring_note']='Original enterable Tidefall house: 3m open doorway, actual floor, three walls, split facade, tables and benches. Runtime scale 4. No filled hull.'
bpy.ops.wm.save_as_mainfile(filepath=str(target))
exec((ROOT/'tools/export_blender.py').read_text(),{'__file__':str(ROOT/'tools/export_blender.py'),'__name__':'__main__'})
print('OPEN_TEAHOUSE_READY',target)
