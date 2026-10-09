"""Approved anime face/hair direction across the eight remaining Rogue heroes.

Blender -b --python tools/sculpt_rogue_roster.py -- [HERO ...]
--baseline DIR opens saved pre-rollout sources. By default base sources rebuild
from tracked originals. Accepted Magic Swordsman/Explorer use their own generator.

Every skull is a single closed surface, with class-specific cheek/jaw geometry,
convex eye planes, integrated rounded nose and coordinated UV0 painted features.
Native pivots and every component outside the Head branch remain exact.
"""
import bpy, bmesh, math, json, sys, importlib.util
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'tools'))
from sculpt_rogue_pilot import finish_mesh, make_mesh, hair_clump, interp, world_points, validate_changed, export_batched, validate_export_face_uv
OUT=ROOT/'assets/rogue/styled'
HEROES=('pirate','samurai','ninja','mage','knight','dragoon','ranger','master-thief')
# Bottom/top match class headwear and seated neck heights. Shape values are
# explicit ring design, not a transform of an existing head or Goemon's skull.
DESIGNS={
 'pirate':dict(tile=0,bottom=1.36,top=2.064,width=.318,jaw=.80,chin=.47,cheek=.92,nose=.054,eye=.58,eye_v=.565,mouth_v=.24,uv_width=.620,description='Square captain jaw, broad cheek planes, strong rounded nose; swept black locks and tied queue'),
 'samurai':dict(tile=1,bottom=1.485,top=2.121,width=.302,jaw=.69,chin=.41,cheek=.91,nose=.054,eye=.57,eye_v=.56,mouth_v=.235,uv_width=.578,description='Firm compact chin, sharp cheek-to-jaw break, focused brow; black tapered temple locks under kabuto'),
 'ninja':dict(tile=2,bottom=1.515,top=2.132,width=.286,jaw=.63,chin=.36,cheek=.87,nose=.043,eye=.58,eye_v=.56,mouth_v=.235,uv_width=.560,description='Narrow tapered face and forward alert eye plane; hood-fitted dark locks and wrapped violet mask'),
 'mage':dict(tile=3,bottom=1.435,top=2.060,width=.288,jaw=.69,chin=.39,cheek=.93,nose=.039,eye=.58,eye_v=.558,mouth_v=.245,uv_width=.556,description='Soft compact jaw with rounded cheek transition and small nose; broad silver curtain locks beneath celestial hat'),
 'dragoon':dict(tile=4,bottom=1.435,top=2.076,width=.280,jaw=.63,chin=.34,cheek=.88,nose=.052,eye=.58,eye_v=.556,mouth_v=.245,uv_width=.537,description='Angular cheek apex and crisp short chin; swept charcoal locks continue horned helmet silhouette'),
 'ranger':dict(tile=6,bottom=1.435,top=2.057,width=.275,jaw=.62,chin=.34,cheek=.86,nose=.051,eye=.58,eye_v=.556,mouth_v=.235,uv_width=.538,description='Lean tapered jaw and elevated cheek plane; asymmetric chestnut fringe and temple locks inside forest hood'),
 'master-thief':dict(tile=8,bottom=1.385,top=2.000,width=.327,jaw=.83,chin=.49,cheek=.96,nose=.048,eye=.60,eye_v=.574,mouth_v=.27,nose_v=.430,uv_width=.614,description='Broad mature jaw and smile-supported cheeks, rounded nose; swept chestnut crown and bold silver temples'),
}

def bounds(obj):
 p=world_points(obj)
 return [Vector(tuple(min(v[i] for v in p) for i in range(3))),Vector(tuple(max(v[i] for v in p) for i in range(3)))]

def sculpt_face(skull,hero):
 d=DESIGNS[hero];bottom=d['bottom'];top=d['top'];height=top-bottom;w=d['width']
 # Profile anatomy: compact chin, intentional jaw corner, cheek apex and cranium.
 rings=[(.0,.12,-.148,.02),(.028,.28,-.211,.066),(.082,d['chin'],-.246,.10),
  (.15,d['jaw']*.79,-.266,.129),(.23,d['jaw'],-.281,.155),
  (.315,d['cheek']*.94,-.290,.178),(.385,d['cheek'],-.290,.198),
  (.46,.975,-.289,.22),(.535,1.,-.289,.237),(.61,.992,-.285,.25),
  (.685,.980,-.274,.255),(.755,.924,-.247,.246),(.83,.831,-.207,.22),
  (.9,.661,-.160,.175),(.956,.427,-.103,.113)]
 # Same accepted rounded integrated nose, sampled densely around bridge and tip.
 for t in [.275,.33,.405,.435,.495,.575,.645,.705]:
  rings.append((t,*[interp(t,[(r[0],r[i]) for r in rings]) for i in range(1,4)]))
 rings.sort();segments=64;verts=[];faces=[]
 for t,width,front,back in rings:
  z=bottom+height*t
  for j in range(segments):
   a=math.tau*j/segments;s=math.sin(a);c=math.cos(a);x=w*width*s
   if c>=0:
    y=front*c**.38
    # Supporting face volumes vary by anatomy, while temples meet the headwear.
    nose=d['nose']*math.exp(-((t-.385)/.074)**2)
    bridge=.027*math.exp(-((t-.485)/.135)**2)
    y-=nose*math.exp(-(x/.062)**2)+bridge*math.exp(-(x/.052)**2)
    cheek_amp=.023 if hero=='master-thief' else (.018 if hero in ['pirate','mage'] else .014)
    y-=cheek_amp*math.exp(-((abs(x)-w*.57)/(w*.28))**2)*math.exp(-((t-.445)/.125)**2)
    y-=.010*math.exp(-((abs(x)-w*.43)/(w*.33))**2)*math.exp(-((t-.695)/.08)**2)
    y-=.012*math.exp(-(x/.135)**2)*math.exp(-((t-.18)/.10)**2)
    # Shallow orbital transition; no recessed mask-like sockets.
    y+=.003*math.exp(-((abs(x)-w*.47)/.070)**2)*math.exp(-((t-d['eye'])/.068)**2)
   else:y=back*(-c)**.90
   verts.append((x,y,z))
 for k in range(len(rings)-1):
  for j in range(segments):
   a=k*segments+j;b=k*segments+(j+1)%segments;faces.append((a,b,b+segments,a+segments))
 bot=len(verts);verts.append((0,-.060,bottom-.004));tip=len(verts);verts.append((0,.012,top))
 for j in range(segments):
  faces.append((bot,(j+1)%segments,j));a=(len(rings)-1)*segments+j;b=(len(rings)-1)*segments+(j+1)%segments;faces.append((a,b,tip))
 mesh=bpy.data.meshes.new(hero+' coherent cheek jaw nose skull');inv=skull.matrix_world.inverted();mesh.from_pydata([inv@Vector(p) for p in verts],[],faces)
 for mat in skull.data.materials:mesh.materials.append(mat)
 finish_mesh(mesh);skull.data=mesh;uv=mesh.uv_layers.new(name='Painted palette');tile=d['tile'];col=tile%3;row=tile//3
 landmarks=[(bottom-.004,.035),(bottom+height*.175,d['mouth_v']),(bottom+height*.382,d.get('nose_v',.361)),(bottom+height*d['eye'],d['eye_v']),(bottom+height*.725,.710),(bottom+height*.855,.855),(top,.998)]
 for face in mesh.polygons:
  front=(skull.matrix_world@face.center).y<-.025
  for li in face.loop_indices:
   p=skull.matrix_world@mesh.vertices[mesh.loops[li].vertex_index].co
   u=max(.012,min(.988,.5+p.x/d['uv_width']));v=max(.015,min(.985,interp(p.z,landmarks)))
   if not front:u,v=.025,.975
   uv.data[li].uv=((col+u)/3,(2-row+v)/3)
 skull['painted_face']=True;skull['head_shape']=d['description'];skull['face_uv_bounds']=[-d['uv_width']/2,d['uv_width']/2,bottom-.004,top];skull['roster_design']='Approved integrated face volume and coordinated UV0 landmarks'
 return skull

def swatch(obj):
 return obj.data.materials[0],tuple(obj.data.uv_layers.active.data[0].uv)

def move_geometry(obj,fn):
 inv=obj.matrix_world.inverted()
 for v in obj.data.vertices:v.co=inv@fn(obj.matrix_world@v.co)

def frame_hair(hero,head,coll):
 d=DESIGNS[hero];b=d['bottom'];h=d['top']-b;w=d['width']
 source=bpy.data.objects['Face framing hair L'];mat,uv=swatch(source)
 grey=swatch(bpy.data.objects['Grey sideburn']) if hero=='master-thief' else (mat,uv)
 keep=('braid','ribbon','bun','tie')
 removed=[]
 for obj in list(coll.objects):
  name=obj.name.lower()
  if obj.type=='MESH' and obj.parent==head and any(s in name for s in ['hair','fringe','sideburn','sidelock']) and not any(s in name for s in keep):
   removed.append(obj.name);bpy.data.objects.remove(obj,do_unlink=True)
 def p(x,y,t):return (x*w,y,b+h*t)
 def lock(name,points,widths,depths,alt=None):
  m,u=alt or (mat,uv);return hair_clump('Roster '+name,[p(*point) for point in points],widths,depths,m,u,head,coll)
 # Broad swept temple forms deliberately terminate above lobes and earrings.
 for side in [-1,1]:
  tip={'pirate':.24,'samurai':.31,'ninja':.43,'mage':-.24,'dragoon':.26,'ranger':.22,'master-thief':.25}[hero]
  pts=[(side*.80,-.105,.81),(side*1.025,-.167,.64),(side*1.025,-.182,.45),(side*.82,-.212,tip)]
  if hero=='mage':pts=[(side*.77,-.07,.84),(side*1.12,-.12,.55),(side*1.13,-.14,.10),(side*.99,-.13,tip)]
  lock(hero+' temple '+str(side),pts,[.085,.076,.052],[.060,.057,.037],grey if hero=='master-thief' else None)
  if hero not in ['ninja','samurai']:
   lock(hero+' ear sweep '+str(side),[(side*.87,.025,.74),(side*1.13,.045,.56),(side*1.15,.065,.37),(side*1.26,.070,.28)],[.085,.074,.040],[.063,.058,.033],grey if hero=='master-thief' else None)
 if hero=='pirate':
  lock('captain swept fringe',[(-.76,-.19,.84),(-.50,-.31,.88),(.07,-.32,.85),(.71,-.26,.74)],[.108,.100,.067],[.073,.056,.038])
  for side in [-1,1]:
   lock('captain swept rear '+str(side),[(side*.45,.16,.91),(side*.81,.28,.74),(side*.70,.30,.44),(side*.32,.31,.22)],[.125,.112,.086],[.08,.072,.055])
 elif hero=='mage':
  lock('mage silver side parted fringe',[(.62,-.135,.91),(.33,-.27,.90),(-.19,-.325,.82),(-.72,-.27,.68)],[.111,.112,.068],[.063,.060,.042])
  lock('mage small silver fringe',[(.61,-.12,.90),(.77,-.255,.83),(.65,-.30,.72),(.45,-.29,.64)],[.083,.067,.047],[.055,.045,.03])
  for i,x in enumerate([-.72,-.25,.25,.72]):
   lock('mage long rear lock '+str(i),[(x*.75,.16,.87),(x,.285,.63),(x*1.05,.305,.17),(x*1.04,.285,-.23)],[.110,.105,.082],[.074,.070,.052])
 elif hero=='samurai':
  for i,x in enumerate([-.60,-.20,.20,.60]):
   lock('samurai nape lock '+str(i),[(x,.17,.59),(x,.245,.38),(x*.96,.25,.20),(x*.84,.235,.10)],[.083,.079,.052],[.062,.059,.037])
 elif hero=='dragoon':
  for i,x in enumerate([-.50,0,.50]):
   lock('dragoon nape lock '+str(i),[(x,.18,.57),(x,.267,.38),(x*1.06,.282,.19),(x*1.08,.255,.08)],[.086,.085,.055],[.059,.057,.038])
  for side in [-1,1]:
   lock('dragoon swept nape '+str(side),[(side*.76,.11,.68),(side*.98,.24,.49),(side*1.06,.30,.29),(side*1.16,.32,.14)],[.098,.085,.055],[.065,.061,.04])
  lock('dragoon diagonal fringe',[(.62,-.17,.88),(.20,-.29,.81),(-.26,-.33,.75),(-.65,-.29,.68)],[.077,.077,.055],[.048,.045,.028])
 elif hero=='ranger':
  lock('ranger parted fringe left',[(-.11,-.16,.92),(-.42,-.30,.88),(-.65,-.325,.76),(-.87,-.27,.57)],[.09,.086,.054],[.055,.053,.033])
  lock('ranger parted fringe right',[(.06,-.17,.94),(.34,-.30,.88),(.55,-.325,.79),(.69,-.30,.68)],[.076,.074,.046],[.051,.045,.028])
 elif hero=='master-thief':
  lock('thief chestnut swept fringe',[(-.75,-.13,.90),(-.51,-.28,.94),(.11,-.29,.96),(.73,-.19,.89)],[.115,.120,.075],[.070,.064,.040])
  for side in [-1,1]:
   lock('thief swept rear '+str(side),[(side*.64,.08,.96),(side*.98,.21,.79),(side*.91,.27,.63),(side*.54,.30,.56)],[.11,.097,.06],[.081,.068,.046])
 # Fitted lower rear masses prevent cracks between separate locks. Hats and
 # helmets remain the upper cap for their own characters.
 if hero in ['pirate','mage','master-thief']:
  z0=b+h*(.1 if hero=='mage' else .38);z1=b+h*.95
  verts=[];faces=[];n=32
  for z,width,dep in [(z0,w*.52,.13),(z0+(z1-z0)*.28,w*.9,.26),(z1-.1,w*1.01,.28),(z1,w*.73,.20)]:
   for j in range(n):
    a=math.tau*j/n;verts.append((width*math.sin(a),.09+dep*math.cos(a),z))
  for k in range(3):
   for j in range(n):a=k*n+j;bb=k*n+(j+1)%n;faces.append((a,bb,bb+n,a+n))
  faces.append(tuple(reversed(range(n))));faces.append(tuple(3*n+j for j in range(n)))
  make_mesh('Roster '+hero+' solid rear hair mass',verts,faces,mat,head,coll,uv)
 return removed

def fitted_accessories(hero,skull,head,coll):
 # Re-seat existing facial clothing on the new surface; original pivots never move.
 surface=BVHTree.FromPolygons(world_points(skull),[list(f.vertices) for f in skull.data.polygons])
 changed=[]
 names={'samurai':['Chin silk tie'],'ninja':['Shinobi forehead plated crest','Shinobi crest violet gem']}.get(hero,[])
 for obj in list(coll.objects):
  if obj.type!='MESH' or not any(obj.name.startswith(n) for n in names):continue
  pts=world_points(obj);mean_y=sum(p.y for p in pts)/len(pts);inv=obj.matrix_world.inverted()
  for v,p in zip(obj.data.vertices,pts):
   hit,normal,index,dist=surface.ray_cast(Vector((p.x,-10,p.z)),Vector((0,1,0)))
   if hit:p.y=hit.y-.013+(p.y-mean_y)*.35;v.co=inv@p
  changed.append(obj.name)
 if hero=='ninja':
  # Mask must be outside the fuller nose, with its upper edge below the eyes.
  hood=bpy.data.objects['Shinobi close hood'];hood_mat,hood_uv=swatch(hood)
  bpy.data.objects.remove(hood,do_unlink=True)
  # A complete fitted skull cap replaces the original aggressively decimated
  # shell, whose triangular panels let the new convex temple poke through.
  verts=[];faces=[];segments=48
  for fraction in [0,.22,.46,.67,.84,.95]:
   for j in range(segments):
    a=math.tau*j/segments;c=math.cos(a)
    low=1.53+.49*max(c,0)**2
    z=low+(2.195-low)*fraction
    width=interp(z,[(1.53,.294),(1.73,.323),(1.95,.326),(2.055,.289),(2.13,.208),(2.195,.02)])
    front=interp(z,[(1.53,.254),(1.80,.31),(1.98,.305),(2.055,.264),(2.13,.175),(2.195,.02)])
    back=interp(z,[(1.53,.235),(1.75,.285),(1.98,.295),(2.055,.26),(2.13,.18),(2.195,.02)])
    verts.append((width*math.sin(a),-front*c**.40 if c>=0 else back*(-c)**.9,z))
  for k in range(5):
   for j in range(segments):a=k*segments+j;bb=k*segments+(j+1)%segments;faces.append((a,bb,bb+segments,a+segments))
  bottom=len(verts);verts.append((0,.04,1.73));top=len(verts);verts.append((0,.01,2.195))
  for j in range(segments):faces.extend([(bottom,(j+1)%segments,j),(5*segments+j,5*segments+(j+1)%segments,top)])
  make_mesh('Roster fitted shinobi hood',verts,faces,hood_mat,head,coll,hood_uv)
  mask=bpy.data.objects['Faceted shinobi mask'];mat,uv=swatch(mask)
  for obj in list(coll.objects):
   if obj.type=='MESH' and any(obj.name.startswith(s) for s in ['Faceted shinobi mask','Mask breathing vent','Mask violet folded seam']):bpy.data.objects.remove(obj,do_unlink=True)
  d=DESIGNS[hero];b=d['bottom'];h=d['top']-b
  verts=[];faces=[];n=32
  # Follow the actual sculpted lower face and wrap continuously around the jaw
  # into the hood, including the wider preserved neck under the compact chin.
  levels=[.006,.028,.055,.082,.12,.15,.23,.315,.385,.405,.46,.495,.505]
  width_keys=[(0,.12),(.028,.28),(.082,d['chin']),(.15,d['jaw']*.79),(.23,d['jaw']),(.315,d['cheek']*.94),(.385,d['cheek']),(.46,.975),(.535,1.)]
  back_keys=[(0,.02),(.028,.066),(.082,.10),(.15,.129),(.23,.155),(.315,.178),(.385,.198),(.46,.22),(.535,.237)]
  for inner in [False,True]:
   for t in levels:
    z=b+h*t;radius=max(d['width']*interp(t,width_keys)*.993,.195*(1-t/.7))
    for j in range(n):
     a=math.tau*j/n;c=math.cos(a);x=radius*math.sin(a)
     if c>=0:
      hit,normal,index,dist=surface.ray_cast(Vector((x,-10,z)),Vector((0,1,0)))
      skin_y=hit.y if hit else -.19*math.sqrt(max(0,1-(x/.195)**2))
      y=skin_y-(.012 if inner else .035)
     else:y=max(.17*(1-t/.8),interp(t,back_keys))*(-c)**.8+(.012 if inner else .035)
     verts.append((x*(1.025 if inner else 1.075),y,z))
  rows=len(levels);half=n*rows
  for row in range(rows-1):
   for j in range(n):
    a=row*n+j;bb=row*n+(j+1)%n;faces.append((a,bb,bb+n,a+n));faces.append((half+a,half+a+n,half+bb+n,half+bb))
  for j in range(n):
   a=j;bb=(j+1)%n;faces.append((a,half+a,half+bb,bb));a=(rows-1)*n+j;bb=(rows-1)*n+(j+1)%n;faces.append((a,bb,half+bb,half+a))
  make_mesh('Roster fitted shinobi mask',verts,faces,mat,head,coll,uv)
 return changed

def sculpt_knight(head,coll):
 # His face is a closed armet. Keep its armor language; replace weak flat visor
 # plates and many thin feathers with dimensional visor planes and broad plumes.
 upper=bpy.data.objects['Knight angled upper visor'];lower=bpy.data.objects['Knight pointed lower visor'];feather=bpy.data.objects['Flowing cobalt crest feather'];ridge=bpy.data.objects['Helmet central ridge']
 upper_mat,upper_uv=swatch(upper);lower_mat,lower_uv=swatch(lower);hair_mat,hair_uv=swatch(feather);gold_mat,gold_uv=swatch(ridge)
 removed=[]
 for obj in list(coll.objects):
  if obj.type=='MESH' and any(obj.name.startswith(s) for s in ['Knight angled upper visor','Knight pointed lower visor','Flowing cobalt crest feather','Plume silk highlight','Helmet central ridge','Visor perforated breathing slit']):
   removed.append(obj.name);bpy.data.objects.remove(obj,do_unlink=True)
 def shell(name,zs,widths,depths,mat,uv):
  verts=[];faces=[];n=24
  for inner in [False,True]:
   for z,w,d in zip(zs,widths,depths):
    for j in range(n+1):
     a=-math.pi/2+math.pi*j/n;c=math.cos(a)
     verts.append((w*math.sin(a),-.085-d*c**.63+( .025 if inner else 0),z))
  k=n+1;m=len(zs);half=k*m
  for row in range(m-1):
   for j in range(n):
    a=row*k+j;faces.append((a,a+1,a+k+1,a+k));faces.append((half+a,half+a+k,half+a+k+1,half+a+1))
  for j in range(n):
   a=j;faces.append((a,half+a,half+a+1,a+1));a=(m-1)*k+j;faces.append((a,a+1,half+a+1,half+a))
  for row in range(m-1):
   a=row*k;faces.append((a,a+k,half+a+k,half+a));a=row*k+n;faces.append((a,half+a,half+a+k,a+k))
  return make_mesh(name,verts,faces,mat,head,coll,uv)
 shell('Roster knight sculpted brow visor',[1.908,1.95,2.04,2.12],[.33,.351,.337,.266],[.305,.34,.292,.195],upper_mat,upper_uv)
 shell('Roster knight tapered jaw visor',[1.505,1.57,1.685,1.82,1.86],[.13,.229,.316,.343,.338],[.257,.323,.363,.365,.342],lower_mat,lower_uv)
 # Three broad directional crest masses, each a closed swept volume.
 for i,x in enumerate([-.08,.005,.082]):
  hair_clump('Roster knight cobalt plume '+str(i),[(x,.065,2.285),(x-.015,.14,2.58),(x+.035,.35,2.72),(x+.055,.63,2.55),(x+.065,.77,2.22)],[.082,.105,.094,.065],[.077,.09,.08,.058],hair_mat,hair_uv,head,coll)
 # The integral central gold spine follows the actual helmet brow/visor profile.
 # Sample the visible surfaces directly so the gold spine cannot bridge away
 # from the low-poly armet dome. Only the intentional eye slit is bridged.
 helmet_objects=[bpy.data.objects[n] for n in ['Knight sculpted armet dome','Roster knight sculpted brow visor','Roster knight tapered jaw visor']]
 vv=[];ff=[]
 for obj in helmet_objects:
  offset=len(vv);vv.extend(world_points(obj));ff.extend([tuple(offset+i for i in f.vertices) for f in obj.data.polygons])
 surface=BVHTree.FromPolygons(vv,ff)
 ridge_points=[(0,.065,2.275)]
 for z in [2.25,2.22,2.19,2.16,2.13,2.12,2.09,2.06,2.04,2.0,1.95,1.93,1.908,1.89,1.87,1.86,1.82,1.77,1.72,1.685,1.63,1.57,1.535,1.508]:
  hit,normal,index,dist=surface.ray_cast(Vector((0,-10,z)),Vector((0,1,0)))
  y=interp(z,[(1.86,-.434),(1.908,-.397)]) if 1.86<z<1.908 else hit.y-.007
  ridge_points.append((0,y,z))
 hair_clump('Roster knight gold central crest',ridge_points,[.016]*(len(ridge_points)-1),[.012]*(len(ridge_points)-1),gold_mat,gold_uv,head,coll)
 # Bold dark breathing slots remain costume graphic forms on the armor, not eyes.
 dark=bpy.data.objects['Knight shadow inside helm'];mat,uv=swatch(dark)
 for side in [-1,1]:
  for i in range(3):
   x=side*(.105+i*.042);z=1.69;y=-.085-.363*(max(0,1-(x/.316)**2)**.5)**.63-.003
   verts=[(x+dx,y+dy,z+dz) for dx,dy,dz in [(-.007,-.004,-.047),(.007,-.004,-.047),(.007,-.004,.047),(-.007,-.004,.047),(-.007,.009,-.047),(.007,.009,-.047),(.007,.009,.047),(-.007,.009,.047)]]
   make_mesh('Roster knight visor vent '+str(side)+' '+str(i),verts,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],mat,head,coll,uv)
 return removed

def apply_roster(hero):
 assert hero in HEROES
 head=bpy.data.objects['Head'];coll=head.users_collection[0]
 pivots={o.name:tuple(tuple(r) for r in o.matrix_world) for o in coll.objects if o.type=='EMPTY'}
 # Parent Head includes static neck and clothing details too: these only change
 # when explicitly named, everything else must retain exact world geometry.
 before={o.name:[tuple(p) for p in world_points(o)] for o in coll.objects if o.type=='MESH'}
 if hero=='knight':removed=sculpt_knight(head,coll);skull=None;adjusted=[]
 else:
  skull=next(o for o in coll.objects if o.type=='MESH' and o.get('painted_face'))
  sculpt_face(skull,hero);removed=frame_hair(hero,head,coll);adjusted=fitted_accessories(hero,skull,head,coll)
 bpy.context.view_layer.update()
 changed=([skull] if skull else [])+[o for o in coll.objects if o.type=='MESH' and (o.name.startswith('Roster ') or o.name in adjusted)]
 checks=validate_changed(changed)
 assert all(tuple(tuple(r) for r in bpy.data.objects[n].matrix_world)==m for n,m in pivots.items())
 untouched=[o for o in coll.objects if o.type=='MESH' and o.name in before and o!=skull and o.name not in adjusted]
 assert all([tuple(p) for p in world_points(o)]==before[o.name] for o in untouched), 'Unintended component change'
 source=ROOT/'assets/blender/rogue'/(hero+'.blend');bpy.context.preferences.filepaths.save_version=0;bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True)
 triangles,batches=export_batched(hero,coll);uv=validate_export_face_uv(hero) if skull else {'face_method':'enclosed helmet','uv_set':0}
 report_path=OUT/(hero+'-build.json');report=json.loads(report_path.read_text()) if report_path.exists() else {'hero':hero}
 report.update({'triangles':triangles,'mesh_batches':batches,'source':str(source.relative_to(ROOT)),'head_shape':DESIGNS[hero]['description'] if skull else 'Closed armet with supported brow, tapered jaw visor and three solid cobalt plumes','roster_generator':'tools/sculpt_rogue_roster.py','facial_depth_revision':'approved-2.34.1-roster-rollout','painted_atlas_changed':False,'export_face_uv_check':uv,'pivot_invariance':True,'body_and_weapon_geometry_invariance':True,'unchanged_components':len(untouched),'adjusted_accessories':adjusted,'replaced_head_components':removed,'roster_mesh_checks':checks})
 report_path.write_text(json.dumps(report,indent=2)+'\n');print('ROGUE_ROSTER_COMPLETE',hero,triangles,'triangles',batches,'batches',flush=True)

def build(hero,baseline=None):
 if baseline:path=Path(baseline)/'assets/blender/rogue'/(hero+'.blend')
 else:
  bpy.context.preferences.filepaths.save_version=0
  spec=importlib.util.spec_from_file_location('rogue_base_style',ROOT/'tools/style_rogue_roster.py');module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);module.build(hero)
  path=ROOT/'assets/blender/rogue'/(hero+'.blend')
 bpy.ops.wm.open_mainfile(filepath=str(path));bpy.context.view_layer.update();apply_roster(hero)

if __name__=='__main__':
 args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else list(HEROES);baseline=None
 if '--baseline' in args:
  i=args.index('--baseline');baseline=args[i+1];del args[i:i+2]
 for hero in args or HEROES:build(hero,baseline)
