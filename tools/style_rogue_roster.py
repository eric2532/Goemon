"""Rebuild Rogue's editable components to Goemon's chunky, matte visual grammar.
Run: Blender -b --python tools/style_rogue_roster.py -- magic-swordsman
Original source meshes are preserved; export batching never touches the source.
"""
import bpy, math, json, sys, re
from pathlib import Path
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/rogue/styled'
SOURCE=ROOT/'assets/blender/rogue'
PROFILES={
 'pirate':('rogue-characters','CAPTAIN',1.65,1.34,1.48),
 'samurai':('standard-roster','SAMURAI',1.65,1.35,1.44),
 'ninja':('standard-roster','NINJA',1.60,1.22,1.38),
 'mage':('standard-roster','MAGE',1.65,1.24,1.43),
 'knight':('standard-roster','KNIGHT',1.65,1.40,1.45),
 'dragoon':('hero-roster','DRAGOON',1.65,1.30,1.47),
 'magic-swordsman':('hero-roster','MAGIC SWORDSMAN',1.65,1.30,1.50),
 'ranger':('hero-roster','RANGER',1.60,1.25,1.43),
 'explorer':('hero-roster','EXPLORER',1.65,1.25,1.40),
 'master-thief':('hero-roster','MASTER THIEF',1.55,1.22,1.40),
}
# Decorative microgeometry becomes broad color shapes rather than raised engraving.
REMOVE=re.compile(r'knuckle crease|carved strand|temple hair strand|hair strand|grip.*wire|coin embroidery|inlaid rune line|bracer luminous rune|mantle.*border|longcoat silver border|greave gilt ridge|sash silk folds|trouser drape fold|stole woven stripe|ankle winding|finger seam|hand-set rivet|etched|carved highlight|hair highlight|cape fold|grip wire|grip gold winding|filigree|stitch|embroidered|rune line|buckle recess|boot seam|chain link|individual beard|freckle|nostril|inner ear|cheekbone|cheek plane|lower lip highlight|jaw planes|eye socket|upper eyelid|cheek sculpt|defined jaw',re.I)

FACE_TILES={'pirate':0,'samurai':1,'ninja':2,'mage':3,'dragoon':4,'magic-swordsman':5,'ranger':6,'explorer':7,'master-thief':8}
FACE_PARTS=re.compile(r'eye|iris|pupil|brow|nose|mouth|lip|cheek|jaw|grin|smile|laugh line|beard|moustache|patch|ear inner',re.I)

def material(name,color):
 m=bpy.data.materials.new(name);m.use_nodes=True;n=m.node_tree.nodes.get('Principled BSDF');n.inputs['Base Color'].default_value=(*color,1);n.inputs['Roughness'].default_value=1;n.inputs['Specular IOR Level'].default_value=0;return m

def mesh_obj(name,verts,faces,mat,parent,col):
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update();o=bpy.data.objects.new(name,me);col.objects.link(o);o.data.materials.append(mat)
 if parent:o.parent=parent;o.matrix_parent_inverse=parent.matrix_world.inverted()
 return o

def reshape(o,fn):
 world=o.matrix_world.copy();inv=world.inverted()
 for v in o.data.vertices:v.co=inv@fn(world@v.co)

def role(o):return o.get('role',o.name.split('.')[0])
def ancestor(o,prefix):
 while o:
  if role(o).startswith(prefix):return o
  o=o.parent
 return None

def depth(o):
 n=0
 while o.parent:n+=1;o=o.parent
 return n

def sculpt_head(skull,hero):
 # Purpose-built cheek/jaw loops replace the source's vertically stretched sphere.
 # Keep the approved painted landmarks in the original world-space UV bounds.
 points=[skull.matrix_world@v.co for v in skull.data.vertices]
 lo=Vector(tuple(min(p[i] for p in points) for i in range(3)))
 hi=Vector(tuple(max(p[i] for p in points) for i in range(3)))
 skull['face_uv_bounds']=[lo.x,hi.x,lo.z,hi.z]
 cx=(lo.x+hi.x)/2;cy=(lo.y+hi.y)/2;rx=(hi.x-lo.x)/2
 front=cy-lo.y;back=hi.y-cy;height=hi.z-lo.z
 # z, half-width, forward depth, rear depth: round cranium, cheek, jaw, chin.
 rings=[(.14,.24,.52,.26),(.18,.43,.72,.40),(.28,.66,.88,.64),
        (.43,.88,.97,.84),(.60,.95,1.00,.99),(.76,.93,.95,.99),
        (.89,.76,.75,.80),(.97,.43,.40,.45)]
 if hero=='master-thief':
  rings=[(z,w*(1.04 if .18<=z<=.43 else 1),f,b) for z,w,f,b in rings]
 elif hero in ['mage','explorer']:
  rings=[(z,w*(.96 if .18<=z<=.43 else 1),f,b) for z,w,f,b in rings]
 verts=[];faces=[];segments=24
 for z,w,f,b in rings:
  for j in range(segments):
   a=j*math.tau/segments;s=math.sin(a);c=math.cos(a)
   x=cx+rx*w*math.copysign(abs(s)**.9,s)
   y=cy-front*f*c**.48 if c>=0 else cy+back*b*(-c)**.85
   # Original hair/helmet shells were fitted to the ellipsoidal upper cranium.
   # Blend back inside that envelope above the brows, preventing scalp poke-through.
   cap_blend=max(0,min(1,(z-.60)/.16))
   cap_radius=math.sqrt(max(0,1-(2*z-1)**2))
   x=x*(1-cap_blend)+(cx+rx*cap_radius*s)*cap_blend
   cap_y=cy-(front if c>=0 else back)*cap_radius*c
   y=y*(1-cap_blend)+cap_y*cap_blend
   verts.append((x,y,lo.z+height*z))
 for k in range(len(rings)-1):
  for j in range(segments):
   a=k*segments+j;b=k*segments+(j+1)%segments
   faces.append((a,b,b+segments,a+segments))
 bottom=len(verts);verts.append((cx,cy-.025,lo.z+height*.12))
 top=len(verts);verts.append((cx,cy,hi.z))
 for j in range(segments):
  faces.append((bottom,(j+1)%segments,j))
  a=(len(rings)-1)*segments+j;b=(len(rings)-1)*segments+(j+1)%segments
  faces.append((a,b,top))
 inv=skull.matrix_world.inverted();mesh=bpy.data.meshes.new('Sculpted cheek jaw and cranium')
 mesh.from_pydata([inv@Vector(p) for p in verts],[],faces);mesh.update()
 for mat in skull.data.materials:mesh.materials.append(mat)
 skull.data=mesh
 for p in mesh.polygons:p.use_smooth=True
 skull['head_shape']='Restrained cheeks, angular tapered jaw and short chin'

def frame_face_with_hair(skull,hero,head,coll):
 # Small solid locks frame the cheek silhouette; the painted eyes stay exposed.
 source_names={'pirate':'Swept back hair','mage':'Mage silver hair back',
  'magic-swordsman':'Silver hair crown','explorer':'Auburn hair crown',
  'master-thief':'Swept back chestnut hair'}
 source=next((o for o in coll.objects if o.name==source_names.get(hero)),None)
 if source:mat=source.data.materials[0]
 else:
  colors={'samurai':(.014,.010,.009),'ninja':(.008,.009,.017),
   'dragoon':(.012,.020,.028),'ranger':(.085,.035,.013)}
  mat=material(hero+' | Temple hair',colors[hero])
 xmin,xmax,zmin,zmax=skull['face_uv_bounds'];rx=(xmax-xmin)/2;h=zmax-zmin
 ps=[skull.matrix_world@v.co for v in skull.data.vertices]
 cy=(min(p.y for p in ps)+max(p.y for p in ps))/2
 front=cy-min(p.y for p in ps)
 tips={'pirate':.36,'samurai':.38,'ninja':.47,'mage':.27,'dragoon':.38,
       'magic-swordsman':.32,'ranger':.36,'explorer':.32,'master-thief':.39}
 for side in [-1,1]:
  # A faceted triangular cross-section gives each lock genuine volume.
  verts=[]
  for x,y,z,w,d in [(.77,-.50,.82,.18,.04),(.94,-.69,.61,.145,.047)]:
   center=Vector((side*x*rx,cy+y*front,zmin+z*h))
   verts.extend([center+Vector((side*dx,dy,0)) for dx,dy in [(-w*rx,0),(w*rx,0),(0,-d)]])
  verts.append(Vector((side*.77*rx,cy-.81*front,zmin+tips[hero]*h)))
  faces=[(0,2,1),(0,1,4,3),(1,2,5,4),(2,0,3,5),(3,4,6),(4,5,6),(5,3,6)]
  if side<0:faces=[tuple(reversed(f)) for f in faces]
  lock=mesh_obj('Face framing hair '+('L' if side<0 else 'R'),verts,faces,mat,head,coll)
  lock['art_direction']='Solid tapered temple lock matching existing hairstyle'
  # A small side tuft overlaps the upper ear, leaving the lobe and jewellery visible.
  ear=next((o for o in coll.objects if o.type=='MESH' and re.fullmatch(r'Ear(?:\.\d+)?',o.name)
            and sum((o.matrix_world@v.co).x for v in o.data.vertices)*side>0),None)
  if ear:
   ep=[ear.matrix_world@v.co for v in ear.data.vertices]
   outer=max(p.x*side for p in ep);ey=sum(p.y for p in ep)/len(ep)
   ez0=min(p.z for p in ep);ez1=max(p.z for p in ep)
   yf=min(p.y for p in ep)-.012;yb=max(p.y for p in ep)+.010
   verts=[]
   for x,z,spread in [(outer-.034,ez1+.085,.75),(outer+.009,ez1-.035,1.0)]:
    verts.extend([(side*(x-.038),ey+(y-ey)*spread,z) for y in [yf,yb]])
    verts.append((side*(x+.009),ey-.008,z))
   verts.append((side*(outer-.008),ey-.006,(ez0+ez1)/2+.008))
   faces=[(0,1,2),(0,3,4,1),(1,4,5,2),(2,5,3,0),(3,6,4),(4,6,5),(5,6,3)]
   if side>0:faces=[tuple(reversed(f)) for f in faces]
   tuft=mesh_obj('Ear framing hair '+('L' if side<0 else 'R'),verts,faces,mat,head,coll)
   tuft['art_direction']='Modest upper-ear coverage; approved face and fringe unchanged'
 # Fill the gaps between Swordsman's original long silver locks at the rear.
 if hero=='magic-swordsman':
  verts=[];faces=[];segments=12
  for z,w,depth in [(.29,.55,.62),(.48,.90,.96),(.70,.96,1.02),(.87,.76,.82)]:
   for j in range(segments+1):
    a=math.pi/2+j*math.pi/segments
    verts.append((rx*w*math.sin(a),cy-front*depth*math.cos(a)+.025,zmin+z*h))
  for k in range(3):
   for j in range(segments):
    a=k*(segments+1)+j;faces.append((a,a+1,a+segments+2,a+segments+1))
  layer=mesh_obj('Silver hair underlayer',verts,faces,mat,head,coll)
  for polygon in layer.data.polygons:polygon.use_smooth=True
  solid=layer.modifiers.new('Hair volume','SOLIDIFY');solid.thickness=.018
  bpy.context.view_layer.objects.active=layer;bpy.ops.object.modifier_apply(modifier=solid.name)

def build(hero):
 filename,tag,hs,bw,bd=PROFILES[hero]
 bpy.ops.wm.open_mainfile(filepath=str(SOURCE/'originals'/(filename+'.blend')))
 coll=next(c for c in bpy.data.collections if tag in c.name.upper())
 # Hidden collections retain stale evaluated matrices until explicitly enabled.
 for c in bpy.data.collections:c.hide_viewport=False;c.hide_render=False
 for o in bpy.data.objects:o.hide_set(False);o.hide_viewport=False
 bpy.context.view_layer.update()
 keep=set(coll.objects)
 for o in list(bpy.data.objects):
  if o not in keep:bpy.data.objects.remove(o,do_unlink=True)
 for c in list(bpy.data.collections):
  if c!=coll and not c.objects:bpy.data.collections.remove(c)
 bpy.context.view_layer.update()
 pivots={role(o):o for o in coll.objects if o.type=='EMPTY'}
 head=pivots['Head'];head_z=head.matrix_world.translation.z
 # Paint-like facial colors retain hero identity without realistic skin shading.
 for m in bpy.data.materials:
  if not m.use_nodes:continue
  n=m.node_tree.nodes.get('Principled BSDF')
  if not n:continue
  if hero=='magic-swordsman' and m.name.startswith('Swordsman |') and ('skin' in m.name.lower() or 'sculpt planes' in m.name.lower()):n.inputs['Base Color'].default_value=(.78,.61,.60,1)
  if m.name.lower() in ['ivory eye white','eye white','ivory','white'] or 'eye ivory' in m.name.lower() or 'eye warm white' in m.name.lower():n.inputs['Base Color'].default_value=(.96,.96,.91,1)
 # Head base sits close to the shoulders, as in the reference; maintain a real neck.
 head_base=1.47 if hero not in ['master-thief','pirate'] else 1.43
 def bodymap(p):
  x,y,z=p
  # Shorter shins, broad ribcage, continuous waist/pelvis volumes.
  nz=z*.82 if z<1 else .82+(z-1)*.80
  return Vector((x*bw,y*bd,nz))
 def headmap(p):return Vector((p.x*hs,p.y*hs,head_base+(p.z-head_z)*hs))
 if hero=='ninja':
  hood=next(o for o in coll.objects if 'Shinobi close hood' in o.name)
  verts=[v.co.copy() for v in hood.data.vertices]
  faces=[]
  for f in hood.data.polygons:
   c=hood.matrix_world@f.center
   if c.y<-.035 and c.z<2.125:continue
   faces.append(list(f.vertices))
  old_mats=list(hood.data.materials)
  new=bpy.data.meshes.new('Hood with real face opening');new.from_pydata(verts,[],faces)
  for m in old_mats:new.materials.append(m)
  hood.data=new
 # Save original transforms before repositioning hierarchical pivots.
 old_world={o:o.matrix_world.copy() for o in coll.objects}
 old_points={o:[o.matrix_world@v.co for v in o.data.vertices] for o in coll.objects if o.type=='MESH'}
 transforms={}
 for o in coll.objects:
  if o.type!='EMPTY':continue
  p=o.matrix_world.translation
  transforms[o]=headmap(p) if ancestor(o,'Head') else bodymap(p)
 # Structural rest pivots keep the existing actor's stable role names.
 for o in sorted(transforms,key=lambda x:depth(x)):
  m=old_world[o].copy();m.translation=transforms[o];o.matrix_world=m
 bpy.context.view_layer.update()
 removed=[]
 for o,points in list(old_points.items()):
  name=o.name.lower()
  facial_part=ancestor(o,'Head') and FACE_PARTS.search(name)
  ninja_underlay=hero=='ninja' and name.split('.')[0] in ['eye white','iris','pupil','confident eyebrow']
  if REMOVE.search(name) or facial_part or ninja_underlay or (hero=='ninja' and 'visible eye-window skin' in name):removed.append(o.name);bpy.data.objects.remove(o,do_unlink=True);continue
  if hero=='ninja' and 'faceted shinobi mask' in name:
   points=[Vector((p.x,(-.095 if p.y<-.15 else -.070),p.z)) if abs(p.x)>.12 else p for p in points]
  in_head=ancestor(o,'Head') is not None
  weapon=ancestor(o,'Weapon_')
  leg=ancestor(o,'Leg_')
  # Keep weapons rigid and preserve their native attack axes. Move grip to new hand.
  if weapon:
   origin=old_world[weapon].translation;new=transforms[weapon]
   mapped=[new+(p-origin) for p in points]
  elif in_head:
   mapped=[headmap(p) for p in points]
  else:
   mapped=[bodymap(p) for p in points]
   # Chunky feet and hands are remodeled locally; do not widen the entire actor.
   if leg and ('boot' in name or 'sole' in name or 'sabat' in name or 'shoe' in name or 'tabi' in name):
    pivot=bodymap(old_world[leg].translation)
    mapped=[Vector((pivot.x+(p.x-pivot.x)*1.26,p.y*1.18,p.z)) for p in mapped]
   if any(t in name for t in ['grasp','hand','fist','ninja glove']) and not any(t in name for t in ['handle','handguard']):
    center=sum(mapped,Vector())/len(mapped);mapped=[center+(p-center)*1.7 for p in mapped]
  if in_head and ('hair lock' in name or 'sidelock' in name):
   mid=sum(mapped,Vector())/len(mapped);mapped=[Vector((p.x,mid.y+(p.y-mid.y)*1.45,p.z)) for p in mapped]
  if hero in FACE_TILES and re.fullmatch(r'ear(?:\.\d+)?',name):
   mid=sum(mapped,Vector())/len(mapped)
   mapped=[mid+Vector(((p.x-mid.x)*.8,(p.y-mid.y)*.6,(p.z-mid.z)*.8)) for p in mapped]
   mapped=[p+Vector((-.008 if mid.x>0 else .008,0,0)) for p in mapped]
  inv=o.matrix_world.inverted()
  for v,p in zip(o.data.vertices,mapped):v.co=inv@p
  # Source bevel stacks inflate simple shapes into hundreds of reflective facets.
  for mod in list(o.modifiers):o.modifiers.remove(mod)
  # Use silhouette-preserving collapse only on dense round source primitives.
  o.data.calc_loop_triangles();tri=len(o.data.loop_triangles)
  if tri>24 and not any(t in name for t in ['carved face','carved head','captain head']):
   mod=o.modifiers.new('Broad low-poly planes','DECIMATE');mod.ratio=max(.04,min(1,24/tri))
   bpy.context.view_layer.objects.active=o
   bpy.ops.object.modifier_apply(modifier=mod.name)
  for p in o.data.polygons:p.use_smooth=True
 if hero in FACE_TILES:
  skull=next(o for o in coll.objects if o.type=='MESH' and any(t in o.name.lower() for t in ['carved face','carved head','captain head']))
  sculpt_head(skull,hero)
  seat_offset={'mage':.08,'samurai':.06}.get(hero,0)
  if seat_offset:
   # Seat the shorter jaw near the robe collar without altering animation pivots.
   for o in coll.objects:
    if o.type=='MESH' and ancestor(o,'Head'):
     reshape(o,lambda p:p+Vector((0,0,-seat_offset)))
   bounds=list(skull['face_uv_bounds']);bounds[2]-=seat_offset;bounds[3]-=seat_offset
   skull['face_uv_bounds']=bounds
  frame_face_with_hair(skull,hero,head,coll)
  if hero=='samurai':
   surface=BVHTree.FromPolygons([skull.matrix_world@v.co for v in skull.data.vertices],[list(f.vertices) for f in skull.data.polygons])
   for o in coll.objects:
    if o.type!='MESH' or not o.name.startswith('Chin silk tie'):continue
    points=[o.matrix_world@v.co for v in o.data.vertices]
    mid_y=sum(p.y for p in points)/len(points);inv=o.matrix_world.inverted()
    for v,p in zip(o.data.vertices,points):
     old_y=p.y;p.x*=.75;p.z+=.02
     hit,normal,index,dist=surface.ray_cast(Vector((p.x,-10,p.z)),Vector((0,1,0)))
     if hit:p.y=hit.y-.012+(old_y-mid_y)*.25
     else:
      hit,normal,index,dist=surface.find_nearest(p)
      p.y=hit.y-.012+(old_y-mid_y)*.25
     v.co=inv@p
 if hero=='ninja':
  skull=next(o for o in coll.objects if 'Carved head' in o.name)
  surface=BVHTree.FromPolygons([skull.matrix_world@v.co for v in skull.data.vertices],[list(f.vertices) for f in skull.data.polygons])
  for o in coll.objects:
   if o.type!='MESH' or not any(t in o.name for t in ['forehead plated crest','crest violet gem']):continue
   points=[o.matrix_world@v.co for v in o.data.vertices];back=max(p.y for p in points);inv=o.matrix_world.inverted()
   for v,p in zip(o.data.vertices,points):
    hit,normal,index,dist=surface.ray_cast(Vector((p.x,-10,p.z)),Vector((0,1,0)))
    if hit:p.y=hit.y-.006+p.y-back;v.co=inv@p
 if hero=='ninja':
  mask=next(o for o in coll.objects if 'Faceted shinobi mask' in o.name)
  bvh=BVHTree.FromPolygons([mask.matrix_world@v.co for v in mask.data.vertices],[list(f.vertices) for f in mask.data.polygons])
  for o in coll.objects:
   if o.type!='MESH' or not any(t in o.name for t in ['Mask violet folded seam','Mask breathing vent']):continue
   points=[o.matrix_world@v.co for v in o.data.vertices];back=max(p.y for p in points);inv=o.matrix_world.inverted()
   for v,p in zip(o.data.vertices,points):
    hit,normal,index,dist=bvh.ray_cast(Vector((p.x,-10,p.z)),Vector((0,1,0)))
    if hit:p.y=hit.y-.006+p.y-back;v.co=inv@p
 # A unified matte palette atlas removes the imported PBR lighting philosophy.
 mats=list({m for o in coll.objects if o.type=='MESH' for m in o.data.materials if m})
 mats.sort(key=lambda x:x.name)
 assert len(mats)<=64, 'Palette atlas capacity exceeded'
 colors=[]
 for m in mats:
  n=m.node_tree.nodes.get('Principled BSDF') if m.use_nodes else None
  c=list(n.inputs['Base Color'].default_value[:3]) if n else list(m.diffuse_color[:3])
  colors.append(c)
 # 128px nearest atlas: each swatch has a generous inset, so mipmaps cannot bleed.
 atlas=bpy.data.images.new(hero+' painted palette',width=128,height=128,alpha=False)
 pixels=[0.0]*(128*128*4)
 for y in range(128):
  for x in range(128):
   index=(y//16)*8+x//16;c=colors[index] if index<len(colors) else [.2,.2,.2]
   # Image pixel API accepts scene linear values; PNG is color-managed on save.
   i=(y*128+x)*4;pixels[i:i+4]=[*c,1]
 atlas.pixels=pixels;atlas.filepath_raw=str(OUT/'atlases'/(hero+'.png'));atlas.file_format='PNG';atlas.save();atlas.pack()
 mat=material(hero+' | Goemon matte painted palette',(1,1,1));nt=mat.node_tree;tex=nt.nodes.new('ShaderNodeTexImage');tex.image=atlas;tex.interpolation='Closest';nt.links.new(tex.outputs['Color'],nt.nodes['Principled BSDF'].inputs['Base Color'])
 for o in coll.objects:
  if o.type!='MESH':continue
  original=list(o.data.materials)
  for old_uv in list(o.data.uv_layers):o.data.uv_layers.remove(old_uv)
  uv=o.data.uv_layers.new(name='Painted palette')
  for face in o.data.polygons:
   mi=mats.index(original[face.material_index]);co=((mi%8+.5)/8,(mi//8+.5)/8)
   for li in face.loop_indices:uv.data[li].uv=co
   face.material_index=0
  o.data.materials.clear();o.data.materials.append(mat)
 # The actual face is a single UV-painted skull surface: no facial feature meshes.
 if hero in FACE_TILES:
  skull=next(o for o in coll.objects if o.type=='MESH' and any(t in o.name.lower() for t in ['carved face','carved head','captain head']))
  painted=bpy.data.images.load(str(OUT/'faces/painted-faces.png'),check_existing=True);painted.pack()
  face_mat=material(hero+' | Drawn face',(1,1,1));nt=face_mat.node_tree
  tex=nt.nodes.new('ShaderNodeTexImage');tex.image=painted;tex.interpolation='Linear'
  nt.links.new(tex.outputs['Color'],nt.nodes['Principled BSDF'].inputs['Base Color'])
  tile=FACE_TILES[hero];column=tile%3;row=tile//3
  def face_uv(u,v):return ((column+u)/3,(2-row+v)/3)
  points=[skull.matrix_world@v.co for v in skull.data.vertices]
  xmin,xmax,zmin,zmax=skull['face_uv_bounds']
  cy=sum(p.y for p in points)/len(points)
  # Broaden UV coverage slightly so the drawn features remain restrained on the face.
  skin_names=[m.name.lower() for m in mats]
  skin_indices={i for i,n in enumerate(skin_names) if any(t in n for t in ['skin','face planes','warm face','weathered peach','sculpt planes'])}
  for o in coll.objects:
   if o.type!='MESH':continue
   uv=o.data.uv_layers.active
   if o==skull:
    o.data.materials.clear();o.data.materials.append(face_mat)
    for f in o.data.polygons:
     center=o.matrix_world@f.center
     for li in f.loop_indices:
      p=o.matrix_world@o.data.vertices[o.data.loops[li].vertex_index].co
      u=(p.x-xmin)/(xmax-xmin);v=(p.z-zmin)/(zmax-zmin)
      uv.data[li].uv=face_uv(min(u,.90) if hero=='dragoon' else u,v) if center.y<cy else face_uv(.025,.975)
     f.material_index=0
    o['painted_face']=True
   else:
    # Match ears/neck/bare hands to the texture's skin; leave gloves and clothing intact.
    o.data.materials.append(face_mat)
    for f in o.data.polygons:
     co=uv.data[f.loop_start].uv
     mi=int(co.y*8)*8+int(co.x*8)
     if mi in skin_indices:
      f.material_index=1
      for li in f.loop_indices:uv.data[li].uv=face_uv(.025,.975)
 # Save source with individually editable clothing / anatomy / accessory components.
 for o in coll.objects:
  if o.type=='EMPTY':o.name=role(o)
 bpy.context.view_layer.update()
 for o in coll.objects:
  if o.type=='MESH':
   o['art_direction']='Goemon matte low-poly; original Rogue costume identity'
 source_path=SOURCE/(hero+'.blend')
 bpy.ops.wm.save_as_mainfile(filepath=str(source_path),compress=True)
 # Duplicate and batch per animated pivot, keeping the source parts editable.
 duplicates=[];mapping={}
 for o in list(coll.objects):
  d=o.copy();d.data=o.data.copy() if o.data else None;coll.objects.link(d);mapping[o]=d;duplicates.append(d)
 for o,d in mapping.items():
  d.parent=mapping.get(o.parent);d.matrix_parent_inverse=Matrix.Identity(4);d.matrix_basis=(o.parent.matrix_world.inverted()@o.matrix_world) if o.parent else o.matrix_world.copy()
 bpy.context.view_layer.update()
 groups={}
 for d in duplicates:
  if d.type=='MESH':groups.setdefault(d.parent,[]).append(d)
 for parent,objects in groups.items():
  bpy.ops.object.select_all(action='DESELECT')
  for o in objects:o.select_set(True)
  bpy.context.view_layer.objects.active=objects[0]
  bpy.ops.object.join();objects[0].name=role(parent)+'_Geometry'
 for o in mapping:o.name='SOURCE_'+o.name
 for o in duplicates:
  try:
   if o.type=='EMPTY':o.name=role(o)
  except ReferenceError:pass
 bpy.ops.object.select_all(action='DESELECT')
 export_objects=[o for o in coll.objects if o not in mapping]
 for o in export_objects:o.select_set(True)
 bpy.context.view_layer.objects.active=next(o for o in export_objects if o.type=='MESH')
 bpy.ops.export_scene.gltf(filepath=str(OUT/'models'/(hero+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_materials='EXPORT')
 triangles=sum(len(o.data.loop_triangles) for o in export_objects if o.type=='MESH')
 report={'hero':hero,'triangles':triangles,'mesh_batches':sum(o.type=='MESH' for o in export_objects),'source':str(source_path.relative_to(ROOT)),'removed_microdetails':removed,'head_scale':hs,'body_width':bw,'body_depth':bd,'pivot_roles':list(pivots),'face_method':'UV-painted skull' if hero in FACE_TILES else 'closed helmet'}
 report['head_shape']='Slimmer cheeks, tapered jaw and face-framing hair' if hero in FACE_TILES else 'Unchanged closed helmet'
 (OUT/(hero+'-build.json')).write_text(json.dumps(report,indent=2))
 print('STYLED',hero,triangles,'triangles',report['mesh_batches'],'batches',flush=True)

if __name__=='__main__':
 args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else list(PROFILES)
 # Preserve the approved pilots and the complete roster anatomy/hair direction.
 # The sculptors call build() for their base, so dispatch only at the CLI entry.
 sys.path.insert(0,str(ROOT/'tools'))
 from sculpt_rogue_pilot import PILOTS, build as build_pilot
 from sculpt_rogue_roster import build as build_roster
 from equip_rogue_roster import HEROES as EQUIPMENT_HEROES, build as build_equipment
 for hero in args:
  if hero in EQUIPMENT_HEROES:build_equipment(hero)
  elif hero in PILOTS:build_pilot(hero)
  else:build_roster(hero)
