"""User-approved v2.37 equipment, built on the accepted v2.35 native roster.

Blender -b --python tools/equip_rogue_roster.py -- [HERO ...]
--baseline DIR reads saved pre-equipment sources for iteration; default rebuilds
through the deterministic v2.35 sculptors. The Goemon master and face atlas are
read-only references. Runtime animates Samurai's separate ScarfTail_Geometry.
"""
import bpy, math, json, sys
from pathlib import Path
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from sculpt_rogue_pilot import make_mesh, hair_clump, world_points, finish_mesh, validate_changed, export_batched, validate_export_face_uv
HEROES=('dragoon','magic-swordsman','samurai','ninja')
OUT=ROOT/'assets/rogue/styled'


def palette(hero,uv):
 return next(m for m in bpy.data.materials if m.name==hero+' | Goemon matte painted palette'),uv

def plate(name,outline,depth,mat,uv,head,coll):
 # A closed beveled-looking plate: the outline is a front world-space polygon.
 verts=[Vector(p) for p in outline];n=len(verts);verts += [p+Vector((0,depth,0)) for p in verts]
 faces=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
 return make_mesh('Equipment '+name,verts,faces,mat,head,coll,uv)

def cap(name,mat,uv,head,coll,width,front,back,low_front,low_side,low_back,top):
 verts=[];faces=[];n=48
 for fraction in [0,.22,.45,.67,.84,.95]:
  for j in range(n):
   a=math.tau*j/n;c=math.cos(a);s=math.sin(a)
   low=low_side+(low_front-low_side)*max(c,0)**1.4+(low_back-low_side)*max(-c,0)**1.4
   z=low+(top-low)*fraction;radius=math.sqrt(max(.015,1-fraction*fraction))
   verts.append((width*s*radius,(-front*c if c>=0 else -back*c)*radius,z))
 for k in range(5):
  for j in range(n):a=k*n+j;b=k*n+(j+1)%n;faces.append((a,b,b+n,a+n))
 bot=len(verts);verts.append((0,.06,low_side+.08));tip=len(verts);verts.append((0,.035,top))
 for j in range(n):faces.extend([(bot,(j+1)%n,j),(5*n+j,5*n+(j+1)%n,tip)])
 return make_mesh('Equipment '+name,verts,faces,mat,head,coll,uv)

def lock(name,points,widths,depths,mat,uv,head,coll):
 return hair_clump('Equipment '+name,points,widths,depths,mat,uv,head,coll)

def remove_components(coll,prefixes):
 names=[]
 for o in list(coll.objects):
  if o.type=='MESH' and any(o.name.startswith(n) for n in prefixes):names.append(o.name);bpy.data.objects.remove(o,do_unlink=True)
 return names

def dragon_helmet(hero,head,coll):
 mat,blue=palette(hero,(.5625,.0625));teal=(.1875,.0625);silver=(.6875,.0625)
 removed=remove_components(coll,['Azure helmet crown','Azure forehead inlay','Silver forehead crest','Dragon horn','Helm individual wing feather'])
 cap('dragon azure skull shell',mat,blue,head,coll,.365,.335,.375,2.025,1.83,1.78,2.275)
 # Broad reptilian muzzle sits above the human brow, opening the entire face.
 snout=plate('dragon swept snout',[(0,-.57,2.055),(-.235,-.51,2.085),(-.26,-.33,2.19),(0,-.34,2.275),(.26,-.33,2.19),(.235,-.51,2.085)],.095,mat,blue,head,coll)
 plate('dragon silver muzzle rim',[(-.23,-.523,2.09),(-.18,-.576,2.035),(0,-.602,2.02),(.18,-.576,2.035),(.23,-.523,2.09),(0,-.56,2.055)],.027,mat,silver,head,coll)
 surface=BVHTree.FromPolygons(world_points(snout),[list(f.vertices) for f in snout.data.polygons])
 for side in [-1,1]:
  # Slanted flat visor inlay reads as a dragon eye, not an added character eye.
  inlay=plate('dragon teal eye inlay '+str(side),[(side*.06,-.572,2.125),(side*.22,-.513,2.155),(side*.18,-.536,2.103)],.012,mat,teal,head,coll)
  # Seat inlays on the actual sloping snout; no hovering helmet decoration.
  for v in inlay.data.vertices:
   hit,normal,index,distance=surface.ray_cast(Vector((v.co.x,-10,v.co.z)),Vector((0,1,0)))
   assert hit is not None, 'Helmet inlay lies outside dragon snout'
   v.co.y=hit.y-.005+(.012 if v.index>=3 else 0)
  finish_mesh(inlay.data)
  lock('dragon swept silver horn '+str(side),[(side*.255,.10,2.18),(side*.40,.25,2.39),(side*.47,.40,2.57),(side*.45,.56,2.64)],[.10,.075,.04],[.09,.06,.037],mat,silver,head,coll)
  lock('dragon teal horn root '+str(side),[(side*.24,.08,2.15),(side*.32,.14,2.28),(side*.405,.25,2.40)],[.116,.095],[.093,.073],mat,teal,head,coll)
  # Solid layered dragon cheek fins replace the old feather fan silhouette.
  for i in range(3):
   y=.09+i*.10;z=1.98-i*.07
   plate('dragon swept temple scale %s %s'%(side,i),[(side*.29,y-.12,z+.11),(side*.38,y-.08,z+.16),(side*(.56-i*.035),y+.19,z+.13),(side*.40,y+.19,z-.065),(side*.29,y+.05,z-.08)],.045,mat,silver if i==0 else teal,head,coll)
  plate('dragon jaw guard '+str(side),[(side*.30,-.15,1.97),(side*.385,-.095,1.94),(side*.355,-.07,1.67),(side*.27,-.18,1.59),(side*.27,-.225,1.74)],.075,mat,blue,head,coll)
 # Three swept crest scales complete the rear reptilian head silhouette.
 for i in range(3):
  y=-.02+i*.14;z=2.255-i*.055
  lock('dragon dorsal silver crest '+str(i),[(0,y,z-.06),(0,y+.06,z+.10),(0,y+.24,z+.16)],[.07,.048],[.055,.045],mat,teal if i%2 else silver,head,coll)
 from rogue_face_masks import dragon_face_mask
 masked_removed,adjusted,description=dragon_face_mask(hero,head,coll)
 return removed+masked_removed,adjusted,description

def arcane_helmet(hero,head,coll):
 mat,purple=palette(hero,(.3125,.1875));silver=(.0625,.1875);light=(.8125,.0625)
 removed=remove_components(coll,['Silver temple circlet','Temple jewel','Pilot silver crown lock 00','Pilot silver crown lock 01','Pilot silver crown lock 02','Pilot silver crown lock 03'])
 cap('arcane violet helmet shell',mat,purple,head,coll,.414,.378,.405,2.025,1.83,1.75,2.30)
 # Broad raised brow, open lower half, and forked crown preserve the visible face.
 plate('arcane angular brow',[(-.365,-.27,2.005),(-.31,-.37,2.125),(-.115,-.417,2.145),(0,-.438,2.065),(.115,-.417,2.145),(.31,-.37,2.125),(.365,-.27,2.005),(.235,-.355,2.023),(.09,-.406,2.027),(0,-.431,1.986),(-.09,-.406,2.027),(-.235,-.355,2.023)],.035,mat,silver,head,coll)
 for side in [-1,1]:
  plate('arcane upswept crown blade '+str(side),[(side*.17,-.13,2.15),(side*.30,-.055,2.37),(side*.52,.06,2.58),(side*.465,.19,2.27),(side*.32,.22,2.025)],.07,mat,purple,head,coll)
  plate('arcane lavender blade edge '+str(side),[(side*.30,-.066,2.37),(side*.52,.049,2.58),(side*.443,.08,2.36),(side*.343,-.055,2.22)],.022,mat,silver,head,coll)
  plate('arcane temple guard '+str(side),[(side*.32,-.19,2.035),(side*.425,-.11,1.96),(side*.395,-.10,1.70),(side*.29,-.22,1.63),(side*.31,-.25,1.82)],.078,mat,purple,head,coll)
  plate('arcane temple rune '+str(side),[(side*.35,-.219,1.93),(side*.393,-.151,1.885),(side*.355,-.176,1.80),(side*.32,-.244,1.855)],.012,mat,light,head,coll)
 # A single large faceted focus crystal and a supporting diamond setting.
 plate('arcane crystal silver setting',[(0,-.413,2.57),(-.111,-.413,2.305),(0,-.453,2.105),(.111,-.413,2.305)],.07,mat,silver,head,coll)
 verts=[(0,-.425,2.53),(-.075,-.426,2.31),(0,-.461,2.16),(.075,-.426,2.31),(0,-.49,2.315),(0,-.377,2.315)]
 faces=[(0,1,4),(1,2,4),(2,3,4),(3,0,4),(0,5,1),(1,5,2),(2,5,3),(3,5,0)]
 crystal=make_mesh('Equipment arcane amethyst focus',verts,faces,mat,head,coll,light)
 for p in crystal.data.polygons:p.use_smooth=False
 from rogue_face_masks import demon_face_mask
 masked_removed,adjusted,description=demon_face_mask(hero,head,coll)
 return removed+masked_removed,adjusted,description

def samurai_scarf(hero,head,coll):
 scarf_mat,red=palette(hero,(.9375,.0625))
 # Bring the entire head/helmet down, then shorten the neck rather than hiding
 # the old long cylinder under more fabric. All weapon and body joints stay put.
 head.matrix_world.translation.z-=.13
 bpy.context.view_layer.update()
 neck=bpy.data.objects['Samurai neck'];points=world_points(neck)
 low=min(p.z for p in points);high=max(p.z for p in points);new_low=low+.13
 inv=neck.matrix_world.inverted()
 for vertex in neck.data.vertices:
  point=neck.matrix_world@vertex.co
  point.z=new_low+(point.z-low)/(high-low)*(high-new_low)
  vertex.co=inv@point
 finish_mesh(neck.data)
 adjusted=[o.name for o in coll.objects if o.type=='MESH' and o.parent==head]
 # Existing painted vermilion swatch keeps the accepted matte material grammar.
 removed=remove_components(coll,['Chin silk tie'])
 skull=next(o for o in coll.objects if o.type=='MESH' and o.get('painted_face'))
 face_surface=BVHTree.FromPolygons(world_points(skull),[list(f.vertices) for f in skull.data.polygons])
 # Rounded continuous cloth tube varies its top edge to cover mouth, exposing nose.
 verts=[];faces=[];n=64;rows=6
 for inner in [False,True]:
  for k in range(rows):
   t=k/(rows-1)
   for j in range(n):
    a=math.tau*j/n;c=math.cos(a);s=math.sin(a)
    bottom=1.275+.045*max(-c,0);top=1.545-.12*max(-c,0)+.009*s
    z=bottom+(top-bottom)*t
    w=.245+.058*t+.007*math.sin(t*math.pi*3)
    dep=.205+.106*t+.012*math.sin(t*math.pi*3)
    y=-dep*c**.43 if c>=0 else .24*(-c)**.85
    if c>=0:
     hit,normal,index,distance=face_surface.ray_cast(Vector((w*s,-10,z)),Vector((0,1,0)))
     if hit is not None:y=min(y,hit.y-.028)
    if inner:w-=.018;y*=.935
    verts.append((w*s,y,z))
 half=rows*n
 for k in range(rows-1):
  for j in range(n):a=k*n+j;b=k*n+(j+1)%n;faces.extend([(a,b,b+n,a+n),(half+a,half+a+n,half+b+n,half+b)])
 for j in range(n):
  a=j;b=(j+1)%n;faces.append((a,half+a,half+b,b));a=(rows-1)*n+j;b=(rows-1)*n+(j+1)%n;faces.append((a,b,half+b,half+a))
 make_mesh('Equipment crimson mouth and neck wrap',verts,faces,scarf_mat,head,coll,red)
 # Closed knot connects wrap to the separate deforming tail behind the left nape.
 lock('crimson scarf side knot',[(-.22,.10,1.41),(-.32,.22,1.41),(-.44,.30,1.40),(-.49,.38,1.40)],[.075,.08,.070],[.065,.06,.05],scarf_mat,red,head,coll)
 root=bpy.data.objects.new('ScarfTail',None);coll.objects.link(root);root.parent=head;root['role']='ScarfTail';root.matrix_world=Matrix.Translation(Vector((-.44,.30,1.40)));bpy.context.view_layer.update()
 root['wind_axis']='Godot local -Z / Blender local +Y';root['length']=1.4;root['root_pin_length']=.10
 verts=[];faces=[];segments=24;across=4;length=1.4
 # Two skin layers with a small rolled cross-section and connected hems.
 for layer in [-1,1]:
  for i in range(segments+1):
   t=i/segments
   for j in range(across+1):
    v=j/across*2-1;width=.115*(1-.37*t)
    x=-.18*t+.055*math.sin(t*math.pi*1.4)+layer*.006
    y=length*t
    z=.095*math.sin(t*math.pi*1.4)-.025*t+v*width+.017*(1-v*v)*math.sin(t*math.pi)
    verts.append((x,y,z))
 stride=across+1;half=(segments+1)*stride
 for i in range(segments):
  for j in range(across):
   a=i*stride+j;faces.extend([(a,a+stride,a+stride+1,a+1),(half+a,half+a+1,half+a+stride+1,half+a+stride)])
 for i in range(segments):
  a=i*stride;faces.append((a,half+a,half+a+stride,a+stride));a=i*stride+across;faces.append((a,a+stride,half+a+stride,half+a))
 for j in range(across):
  a=j;faces.append((a,a+1,half+a+1,half+a));a=segments*stride+j;faces.append((a,half+a,half+a+1,a+1))
 tail=make_mesh('Equipment continuous long scarf tail',verts,faces,scarf_mat,root,coll,red);tail.matrix_parent_inverse=Matrix.Identity(4);tail.matrix_basis=Matrix.Identity(4)
 tail['length_subdivisions']=segments;tail['continuous_cloth']=True
 return removed,adjusted,'Compact Samurai neckline: head/helmet lowered 0.13, neck shortened 41 percent, fitted crimson mouth wrap and unchanged long wind-driven tail'

def ninja_jaw(hero,head,coll):
 changed=[]
 for o in coll.objects:
  if o.type!='MESH' or not (o.get('painted_face') or o.name=='Roster fitted shinobi mask'):continue
  inv=o.matrix_world.inverted()
  for v in o.data.vertices:
   p=o.matrix_world@v.co;t=(p.z-1.515)/.617
   weight=max(0,1-abs(t-.19)/.22)
   # Six percent wider jaw, gentle lower chin support, no eye-plane changes.
   p.x*=1+.065*weight;p.z-=.009*weight
   if p.y<-.12:p.y-=.005*weight
   v.co=inv@p
  finish_mesh(o.data);changed.append(o.name)
 return [],changed,'Slightly fuller lower jaw and chin (maximum 6.5 percent width), coordinated fitted cloth mask; upper face/UV artwork exact'


def apply_equipment(hero):
 head=bpy.data.objects['Head'];coll=head.users_collection[0]
 pivots={o.name:tuple(tuple(r) for r in o.matrix_world) for o in coll.objects if o.type=='EMPTY'}
 before={o.name:[tuple(p) for p in world_points(o)] for o in coll.objects if o.type=='MESH'}
 removed,adjusted,description={'dragoon':dragon_helmet,'magic-swordsman':arcane_helmet,'samurai':samurai_scarf,'ninja':ninja_jaw}[hero](hero,head,coll)
 bpy.context.view_layer.update()
 # Samurai's rigidly lowered original helmet parts keep their original topology;
 # manifold validation applies to newly authored or reshaped geometry only.
 changed=[o for o in coll.objects if o.type=='MESH' and (o.name.startswith('Equipment ') or (o.name in adjusted and (hero!='samurai' or o.name=='Samurai neck')))]
 checks=validate_changed(changed)
 assert all(tuple(tuple(r) for r in bpy.data.objects[n].matrix_world)==m for n,m in pivots.items() if not (hero=='samurai' and n=='Head'))
 untouched=[o for o in coll.objects if o.type=='MESH' and o.name in before and o.name not in adjusted]
 assert all([tuple(p) for p in world_points(o)]==before[o.name] for o in untouched),'Unrequested geometry change'
 source=ROOT/'assets/blender/rogue'/(hero+'.blend');bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True)
 triangles,batches=export_batched(hero,coll);uv=validate_export_face_uv(hero)
 path=OUT/(hero+'-build.json');report=json.loads(path.read_text())
 report.update({'triangles':triangles,'mesh_batches':batches,'equipment_revision':'2.36' if hero=='ninja' else '2.37','equipment_generator':'tools/equip_rogue_roster.py','equipment_design':description,'equipment_removed':removed,'equipment_adjusted':adjusted,'equipment_mesh_checks':checks,'equipment_unchanged_components':len(untouched),'export_face_uv_check':uv,'equipment_pivot_invariance':hero!='samurai','equipment_pivot_adjustments':{'Head':[0,0,-.13]} if hero=='samurai' else {},'equipment_body_and_weapon_geometry_invariance':True,'painted_atlas_changed':False})
 if hero=='samurai':report['scarf_contract']={'root':'Head/ScarfTail','mesh':'ScarfTail_Geometry','source_axis':'+Y','godot_axis':'-Z','length':1.4,'length_subdivisions':24,'source_attachment_world':[-.44,.30,1.40],'mesh_transform':'identity','root_pin_length':.10}
 path.write_text(json.dumps(report,indent=2)+'\n');print('ROGUE_EQUIPMENT_COMPLETE',hero,triangles,batches,flush=True)

def build(hero,baseline=None):
 if baseline:path=Path(baseline)/'assets/blender/rogue'/(hero+'.blend')
 else:
  from sculpt_rogue_pilot import build as build_pilot
  from sculpt_rogue_roster import build as build_roster
  (build_pilot if hero=='magic-swordsman' else build_roster)(hero)
  path=ROOT/'assets/blender/rogue'/(hero+'.blend')
 bpy.ops.wm.open_mainfile(filepath=str(path));bpy.context.view_layer.update();apply_equipment(hero)

if __name__=='__main__':
 args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else list(HEROES);baseline=None
 if '--baseline' in args:i=args.index('--baseline');baseline=args[i+1];del args[i:i+2]
 for hero in args or HEROES:build(hero,baseline)
