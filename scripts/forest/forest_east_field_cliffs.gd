extends RefCounted
## Original solid crags plus native sparse crest relief, batched only in the East branch.
const StoneRelief=preload("res://scripts/forest/forest_east_cliff_relief.gd")
const Native=preload("res://scripts/forest/forest_original_cliffs.gd")
const Regions=preload("res://scripts/forest/forest_freyja_regions.gd")
const VillageProps=preload("res://scripts/forest/forest_east_village_props.gd")
const Relief=preload("res://scripts/forest/forest_elsa_scenery.gd")
const Fit=preload("res://scripts/forest/forest_falan_proportions.gd")
const ROOT="res://assets/maps/falan/east_field_cliffs/"
static var meshes:Dictionary={}
static var edges:Dictionary={}
static var edge_texture:Texture2D
static var reverse_material:Material
static var prepared:Dictionary={}
static var walk_bits:PackedByteArray
static var field_bits:Dictionary={}
static var bank_heights:Dictionary={}
static var field_portals:Dictionary={}

static func owns(area:String,serial:int,tall:bool)->bool:
 return tall and area in ["east_gate","north_coast","alyut"] and serial in range(12536,12548) and Native.owns(serial)

static func edge_data()->Dictionary:
 if edges.is_empty():edges=data().graphics
 return edges

static func data()->Dictionary:
 if prepared.is_empty():prepared=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"data.json"))
 return prepared

static func field_bit(kind:String,cell:Vector2i)->bool:
 var source:Dictionary=data().field;var size_=Vector2i(source.size[0],source.size[1])
 if not Rect2i(Vector2i.ZERO,size_).has_point(cell):return false
 if not field_bits.has(kind):field_bits[kind]=Marshalls.base64_to_raw(source[kind]).decompress((size_.x*size_.y+7)>>3,FileAccess.COMPRESSION_DEFLATE)
 var index=cell.y*size_.x+cell.x
 return bool(field_bits[kind][index>>3]&(1<<(index&7)))

static func field_portal(cell:Vector2i)->bool:
 if field_portals.is_empty():
  for row in data().field.portal_cells:field_portals[Vector2i(row[0],row[1])]=true
 return field_portals.has(cell)

static func owned_field_cell(area:String,cell:Vector2i)->bool:
 var bounds:Array=data().field.owned_window
 if not Rect2i(bounds[0],bounds[1],bounds[2],bounds[3]).has_point(cell):return false
 var owner="north_coast" if cell.y<100 and cell.x>510 or cell.x>670 and cell.y<210 else "east_gate"
 return owner==area

static func bank_height(model,area:String,cell:Vector2i,frame:Transform2D)->float:
 var key=[area,cell]
 if bank_heights.has(key):return bank_heights[key]
 var samples=[]
 for radius in range(1,17):
  for direction in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT,Vector2i(-1,-1),Vector2i(1,-1),Vector2i(1,1),Vector2i(-1,1)]:
   var candidate=cell+direction*radius
   if not field_bit("walk",candidate) or not field_bit("land",candidate):continue
   var at=frame.inverse()*(Vector2(candidate)*3.)
   samples.append(model.surface_height(at.x,at.y))
  if not samples.is_empty():break
 var level=float(model.terrain.BANK_HEIGHT) if samples.is_empty() else float(samples.reduce(func(sum_,value):return sum_+value,0.))/samples.size()
 bank_heights[key]=maxf(level,float(model.terrain.WATER_HEIGHT)+.10)
 return bank_heights[key]

static func base_corner(key:Vector2i,cells:Dictionary)->float:
 var level=-INF
 for sign_ in [Vector2i(-1,-1),Vector2i(1,-1),Vector2i(1,1),Vector2i(-1,1)]:
  var cell=(key+sign_)/2
  if cells.has(cell):level=maxf(level,float(cells[cell]))
 return level

static func substrate(root:Node3D,groups:Dictionary,area:String,model):
 var frame=Regions.frame(area);var cells={};var chunks={};var footprint={};var extra={}
 for key in groups:
  var serial=int(key[0]);var graphic:Dictionary=Native.graphic(serial);var poses:Array=groups[key]
  for i in poses.size():
   var pose:Transform3D=poses[i];var center=Vector2i((frame*Vector2(pose.origin.x,pose.origin.z)/3.).round())
   var anchor=center-Vector2i((int(graphic.footprint[0])-1)/2,-(int(graphic.footprint[1])-1)/2)
   var eligible=[]
   for z in int(graphic.footprint[1]):
    for x in int(graphic.footprint[0]):
     var cell=anchor+Vector2i(x,-z)
     footprint[cell]=true
     if field_bit("blocked_land",cell) and not field_portal(cell):eligible.append(cell)
   if eligible.is_empty():continue
   var level=bank_height(model,area,center,frame)
   pose.origin.y=level;poses[i]=pose
   for cell:Vector2i in eligible:cells[cell]=maxf(float(cells.get(cell,-INF)),level)
 for original:Vector2i in footprint:
  for z in range(-1,2):
   for x in range(-1,2):
    var cell=original+Vector2i(x,z)
    if footprint.has(cell) or cells.has(cell) or not owned_field_cell(area,cell) or field_portal(cell) or not field_bit("hidden_land",cell):continue
    cells[cell]=bank_height(model,area,cell,frame);extra[cell]=true
 for cell:Vector2i in cells:
  var at=frame.inverse()*(Vector2(cell)*3.)
  var key=Vector2i(floori(at.x/96.),floori(at.y/96.))
  if not chunks.has(key):chunks[key]=[]
  chunks[key].append(cell)
 for key:Vector2i in chunks:
  var mesh_=SurfaceTool.new();mesh_.begin(Mesh.PRIMITIVE_TRIANGLES)
  var origin=Vector3(key.x*96.,0,key.y*96.);var bottom=float(model.terrain.WATER_HEIGHT)-2.
  for cell:Vector2i in chunks[key]:
   var top=[];var low=[]
   for sign_ in [Vector2i(-1,-1),Vector2i(1,-1),Vector2i(1,1),Vector2i(-1,1)]:
    var corner=cell*2+sign_;var at=frame.inverse()*(Vector2(corner)*1.5)
    top.append(Vector3(at.x,base_corner(corner,cells),at.y)-origin);low.append(Vector3(at.x,bottom,at.y)-origin)
   base_quad(mesh_,top[0],top[1],top[2],top[3]);base_quad(mesh_,low[3],low[2],low[1],low[0])
   for edge in 4:
    var next=(edge+1)%4;var neighbour=cell+[Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT][edge]
    if not cells.has(neighbour):base_quad(mesh_,low[edge],low[next],top[next],top[edge])
  var node=MeshInstance3D.new();node.name="EastNativeCliffSubstrate_%d_%d"%[key.x,key.y]
  node.position=origin;node.mesh=mesh_.commit();node.material_override=reverse_material
  node.set_meta("source_blocked_nonwater_cells",chunks[key]);node.set_meta("inferred_visual","Closed source-cliff substrate at neighbouring original land height; no terrain/navigation changes")
  root.add_child(node)
 root.set_meta("east_cliff_substrate_cells",cells.keys())
 root.set_meta("east_cliff_original_footprint",footprint.keys());root.set_meta("east_cliff_inferred_substrate_cells",extra.keys());root.set_meta("east_cliff_substrate_area",area)

static func base_quad(tool:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,d:Vector3):
 var normal=(c-a).cross(b-a).normalized()
 for p in [a,b,c,a,c,d]:tool.set_normal(normal);tool.add_vertex(p)

static func alyut_obstacles(model,plan:Array):
 var source:Dictionary=data().alyut
 if walk_bits.is_empty():walk_bits=Marshalls.base64_to_raw(source.walk).decompress((int(source.size[0])*int(source.size[1])+7)>>3,FileAccess.COMPRESSION_DEFLATE)
 var origin:Vector2=Regions.Sites.VILLAGES.alyut[2]
 for row in source.blocked_cliff_cells:
  var cell=Vector2i(row[0],row[1]);var index=cell.y*int(source.size[0])+cell.x
  if walk_bits[index>>3]&(1<<(index&7)):continue
  if source.protected_cells.has(row):continue
  var at=origin+Vector2(cell)*3.;var y:float=model.surface_height(at.x,at.y)
  plan.append(["archive_cliff",Transform3D.IDENTITY,AABB(Vector3(at.x-1.375,y-.05,at.y-1.375),Vector3(2.75,12.,2.75)),2400,cell])

static func mesh(serial:int)->Mesh:
 if meshes.has(serial):return meshes[serial]
 if reverse_material==null:
  reverse_material=load("res://scripts/forest/forest_freyja_destination_art.gd").cliff_material(false,true)
  reverse_material.shader=load(ROOT+"reverse.gdshader")
 var profile:Dictionary=Native.data()[str(serial)];var graphic:Dictionary=Native.graphic(serial)
 if int(graphic.footprint[0])==1:
  if edge_texture==null:edge_texture=load(ROOT+"native-edges.png")
  var g:Dictionary=edge_data()[str(serial)].duplicate(true);g.cut=[serial];g.depth=.12
  var crest:Mesh=Relief.relief_shape(g,edge_texture,edge_texture,g.outline)
  # An occlusion mask has no measurable back height; use its own family's calibrated painted-crag frame.
  var pixel_height=float(Native.data()[str(int(profile.paint_source))].pixel_height)
  var crest_mesh=Fit.transformed(crest,Transform3D(Basis.IDENTITY.scaled(Vector3(1,pixel_height/.045*.70,1))))
  # The sparse source only paints a crest. Reuse its family's rounded crag for a low, closed hidden spur.
  var family=int(profile.paint_source);var scale_=Vector3(1./3.,.70,1./3.);var family_profile:Dictionary=Native.data()[str(family)]
  var body:Mesh=Fit.transformed(Native.mesh(family,Native.graphic(family)),Transform3D(Basis.IDENTITY.scaled(scale_),-Vector3(family_profile.crown[0],0,family_profile.crown[2])*scale_))
  var combined=ArrayMesh.new();var retained=[]
  for part in [body,crest_mesh]:
   for slot in part.get_surface_count():
    var arrays_:Array=part.surface_get_arrays(slot)
    combined.add_surface_from_arrays(part.surface_get_primitive_type(slot),arrays_);retained.append(arrays_)
    combined.surface_set_material(combined.get_surface_count()-1,reverse_material if part==body else part.surface_get_material(slot))
  combined.set_meta("east_cpu_arrays",retained)
  meshes[serial]=combined
  meshes[serial].set_meta("native_border_crest",serial)
  meshes[serial].set_meta("inferred_hidden_spur",true)
 else:
  meshes[serial]=StoneRelief.mesh(serial,reverse_material)
 meshes[serial].set_meta("east_inferred_reverse",true)
 return meshes[serial]

static func alyut_placements(groups:Dictionary,model)->Array:
 groups.clear()
 var result=[];var footprint_cells={}
 var origin:Vector2=Regions.Sites.VILLAGES.alyut[2]
 var complete=load("res://scripts/forest/forest_east_alyut_source_completion.gd")
 var rows:Array=complete.cliff_rows() if complete.enabled() else VillageProps.data().audit
 for row in rows:
  if int(row.map)!=2400 or int(row.graphic) not in range(12536,12548):continue
  var serial=int(row.graphic);var graphic:Dictionary=Native.graphic(serial)
  var at=origin+Vector2(row.cell[0],row.cell[1])*3.+Vector2((int(graphic.footprint[0])-1)*1.5,-(int(graphic.footprint[1])-1)*1.5)
  append(groups,serial,Vector3(at.x,model.surface_height(at.x,at.y),at.y))
  for z in int(graphic.footprint[1]):
   for x in int(graphic.footprint[0]):footprint_cells[Vector2i(row.cell[0]+x,row.cell[1]-z)]=true
  result.append({"map":2400,"cell":row.cell,"graphic":serial,"footprint":graphic.footprint,"presentation":"native_border_crest" if int(graphic.footprint[0])==1 else "solid_measured_crag"})
 return [result,footprint_cells.size()]

static func source_basis(area:String)->Basis:
 # Godot Y rotation has the opposite sign to a2Drotation of the X/Z plane.
 return Basis(Vector3.UP,Regions.frame(area).get_rotation()) if area=="east_gate" else Basis.IDENTITY

static func build(root:Node3D,groups:Dictionary,area:String,model=null):
 if area=="alyut" and model!=null:
  var source=alyut_placements(groups,model)
  root.set_meta("east_native_cliff_source_map",2400);root.set_meta("east_native_cliff_source_placements",source[0]);root.set_meta("east_native_cliff_cells",source[1])
 if area in ["east_gate","north_coast"] and model!=null and not groups.is_empty():
  mesh(int(groups.keys()[0][0]))
  substrate(root,groups,area,model)
 var turn=source_basis(area)
 for key in groups:
  var poses:Array=groups[key];var serial:int=key[0]
  var node=MultiMeshInstance3D.new();node.name="EastNativeCliff_%d_%d_%d"%[serial,key[1],key[2]]
  node.multimesh=MultiMesh.new();node.multimesh.transform_format=MultiMesh.TRANSFORM_3D
  node.multimesh.mesh=mesh(serial);node.multimesh.instance_count=poses.size()
  for i in poses.size():node.multimesh.set_instance_transform(i,Transform3D(turn,poses[i].origin))
  node.set_meta("source_graphic",serial);node.set_meta("inferred_visual","Closed measured native crag backs; sparse native crest alpha relief")
  node.set_meta("east_cliff_area",area);node.set_meta("east_cliff_source_map",2400 if area=="alyut" else 100)
  var anchors=[];var foot:Array=Native.graphic(serial).footprint;var half=Vector2((foot[0]-1)*.5,-(foot[1]-1)*.5)
  for pose:Transform3D in poses:
   var point=Vector2(pose.origin.x,pose.origin.z);var source=(point-Regions.Sites.VILLAGES.alyut[2])/3.-half if area=="alyut" else Regions.frame(area)*point/3.-half
   anchors.append([roundi(source.x),roundi(source.y)])
  node.set_meta("east_cliff_source_anchors",anchors)
  root.add_child(node)

static func append(groups:Dictionary,serial:int,point:Vector3):
 var key=[serial,floori(point.x/96.),floori(point.z/96.)]
 if not groups.has(key):groups[key]=[]
 groups[key].append(Transform3D(Basis.IDENTITY,point))
