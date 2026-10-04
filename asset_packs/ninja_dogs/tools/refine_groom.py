import bpy,runpy,sys,math
from pathlib import Path
from mathutils import Vector,Matrix
P=Path(__file__).resolve().parents[1];d=runpy.run_path(str(P/'tools/build_dogs.py'));args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
for r in d['DOGS']:
 if args and r['id'] not in args:continue
 src=P/'sources'/f"{r['id']}_{r['name']}.blend";bpy.ops.wm.open_mainfile(filepath=str(src))
 if bpy.context.scene.get('groom_refined'):continue
 h=Vector(r['head']);Ri=Matrix.Rotation(math.radians(8 if r['breed']=='sighthound' else 35),3,'Z');o=bpy.data.objects['FUR | groomed tapered surface clumps'];me=o.data;ca=me.color_attributes['FurColor']
 for start in range(0,len(me.vertices),12):
  origin=sum((me.vertices[start+k].co for k in range(3)),Vector())/3;q=h+Ri@(origin-h)
  facial=q.x>h.x-.02 and q.z>h.z-.20 and abs(q.y)<r['hs'][1]*1.1
  eye=False
  for sign in [-1,1]:
   e=h+Vector((r['hs'][0]*.64,sign*r['hs'][1]*.69,r['hs'][2]*.26));delta=q-e
   if (delta.x/.15)**2+(delta.y/.15)**2+(delta.z/.15)**2<1.4:eye=True
  factor=.06 if eye else (.20 if facial else 1)
  for k in range(12):
   v=me.vertices[start+k];v.co=origin+(v.co-origin)*factor
   if r['breed'] in ['chin','shikoku']:ca.data[start+k].color=(*d['color_at'](origin,r),1)
 if r['breed'] in ['chin','shikoku']:
  body=bpy.data.objects['ANATOMY | unified canine skin'];col=body.data.color_attributes['FurColor']
  for v,c in zip(body.data.vertices,col.data):c.color=(*d['color_at'](v.co,r),1)
 if r['id']=='06':
  # Ward at the far ear moves outward so it does not obscure the face.
  for ob in bpy.data.objects:
   if ob.name.startswith('DISPLAY |') and ob.type in ['MESH','CURVE']:
    pass
 bpy.context.scene['groom_refined']=True
 bpy.ops.wm.save_as_mainfile(filepath=str(src),compress=True);print('GROOM REFINED',r['id'],flush=True)
