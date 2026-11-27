extends RefCounted
## Source-anchored appearance only; the existing terrain/collision owner is unchanged.
const Meadow=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
static var data:Dictionary={}
static var fits:Dictionary={}
static var saplings:Dictionary={}
static var sapling_materials:Dictionary={}
static var cliff_cells:Dictionary={}
static var source_round_parts:Dictionary={}
static var source_plant_material:StandardMaterial3D

static func source_round_piece(tool:SurfaceTool,at:Vector3,basis:Basis,size_:Vector3,color:Color,large:bool=false,painting:Image=null,g:Dictionary={}):
 if not source_round_parts.has(large):
  # Same rounded garden leaf/petal primitive; small buds use a bounded lower-detail variant.
  var sphere=SphereMesh.new();sphere.radius=.5;sphere.height=1.
  sphere.radial_segments=16 if large else 8;sphere.rings=8 if large else 2
  source_round_parts[large]=sphere.get_mesh_arrays()
 var arrays:Array=source_round_parts[large]
 var pose=Transform3D(basis.scaled_local(size_),at);var normal=pose.basis.inverse().transposed()
 for index in arrays[Mesh.ARRAY_INDEX]:
  var point:Vector3=pose*arrays[Mesh.ARRAY_VERTEX][index];var tint=color
  if painting!=null:
   var px=clampi(roundi((point.x+point.z)*32./3.-float(g.origin[0])),0,painting.get_width()-1)
   var py=clampi(roundi((point.z-point.x)*8.-point.y*10.-float(g.origin[1])),0,painting.get_height()-1)
   var sample=painting.get_pixel(px,py)
   if sample.a>.5 and maxf(sample.r,maxf(sample.g,sample.b))>.18:tint=sample
  tool.set_color(tint);tool.set_normal((normal*arrays[Mesh.ARRAY_NORMAL][index]).normalized());tool.add_vertex(point)

static func finish_source_plant(tool:SurfaceTool)->Mesh:
 if source_plant_material==null:
  source_plant_material=StandardMaterial3D.new();source_plant_material.vertex_color_use_as_albedo=true
  source_plant_material.vertex_color_is_srgb=true;source_plant_material.roughness=.94
 var mesh=tool.commit();mesh.surface_set_material(0,source_plant_material);return mesh

static func source_flower_mesh(serial:int,g:Dictionary)->Mesh:
 var harbor=load("res://scripts/forest/forest_tina_harbor_details.gd")
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for leaf in g.source_leaves:
  var pixel=Vector2(leaf.pixel[0],leaf.pixel[1])
  var height=.10+(float(g.bounds[3])-pixel.y)*.025 if g.recipe=="stem_bouquet"else .07
  var at:Vector3=harbor.point(pixel,height,g)
  var rgb:Array=leaf.rgb;var span:Array=leaf.bounds
  var angle=atan2(pixel.y-float(g.size[1])*.5,pixel.x-float(g.size[0])*.5)
  source_round_piece(tool,at,Basis(Vector3.UP,angle),Vector3(maxf(2.,span[2])*.0663,.065,maxf(2.,span[3])*.0884),Color(rgb[0],rgb[1],rgb[2]))
 for bloom in g.source_blooms:
  var pixel=Vector2(bloom.pixel[0],bloom.pixel[1]);var tall:bool=g.recipe=="stem_bouquet"
  var height=maxf(.35,(float(g.bounds[3])-pixel.y)*.03)if tall else .15+(float(g.bounds[3])-pixel.y)*.004
  var at:Vector3=harbor.point(pixel,height,g);var rgb:Array=bloom.rgb
  var radius=.04+sqrt(float(bloom.pixels))*.012
  source_round_piece(tool,at,Basis.IDENTITY,Vector3(radius*2.,radius*.75,radius*2.),Color(rgb[0],rgb[1],rgb[2]))
  if tall:
   var base=Vector3(at.x,.035,at.z);var delta=at-base
   var green:Array=g.green
   source_round_piece(tool,(base+at)*.5,Basis(Quaternion(Vector3.UP,delta.normalized())),Vector3(.02,delta.length(),.02),Color(green[0],green[1],green[2]))
 var mesh=finish_source_plant(tool);mesh.set_meta("source_bloom_groups",g.source_blooms.size())
 return mesh

static func source_daisy_mesh(g:Dictionary)->Mesh:
 var harbor=load("res://scripts/forest/forest_tina_harbor_details.gd")
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var painting=Image.create_from_data(g.size[0],g.size[1],false,Image.FORMAT_RGBA8,Marshalls.base64_to_raw(g.source_rgba))
 var cx=float(g.size[0])*.5;var cy=float(g.size[1])*.45
 var right=Vector3(1,0,1).normalized();var up=Vector3(.52981294,.66226618,-.52981294).normalized()
 var normal=right.cross(up).normalized();var height=float(g.size[1])*.45*.06629126*up.y+.12
 var centre:Vector3=harbor.point(Vector2(cx,cy),height,g)
 var green:Array=g.green
 var stem_base=Vector3.ZERO
 for leaf in g.source_leaves:
  var at:Vector3=harbor.point(Vector2(leaf.pixel[0],leaf.pixel[1]),.07,g)
  stem_base+=at/float(g.source_leaves.size())
  source_round_piece(tool,at,Basis.IDENTITY,Vector3(.27,.08,.43),Color(green[0],green[1],green[2]))
 var stem=centre-normal*.15-stem_base
 source_round_piece(tool,stem_base+stem*.5,Basis(Quaternion(Vector3.UP,stem.normalized())),Vector3(.035,stem.length(),.035),Color(green[0],green[1],green[2]))
 var rgb:Array=g.petals
 for petal in 10:
  var angle=petal*TAU/10.;var radial=right*cos(angle)-up*sin(angle)
  var at=centre+radial*(float(g.size[0])*.32*.06629126)
  source_round_piece(tool,at,Basis(radial,normal,radial.cross(normal)),Vector3(g.size[0]*.019,.16,g.size[0]*.011),Color(rgb[0],rgb[1],rgb[2]),true,painting,g)
 var color:Array=g.centre
 source_round_piece(tool,centre+normal*.08,Basis(right,normal,right.cross(normal)),Vector3(g.size[0]*.023,.32,g.size[0]*.023),Color(color[0],color[1],color[2]),true,painting,g)
 var mesh=finish_source_plant(tool);mesh.set_meta("source_petals",10);mesh.set_meta("native_source_paint",g.rgba_sha256)
 return mesh

static func source_tree_fit(g:Dictionary)->Transform3D:
 var points:Array[Vector3]=[]
 var fit=load("res://scripts/forest/forest_falan_proportions.gd")
 var turn=Transform3D(Basis(Vector3.UP,-PI*.25),Vector3.ZERO)
 for part in Meadow.source(g.asset):points.append_array(fit.mesh_points(part.mesh,turn*part.transform))
 var b:Array=g.bounds
 return fit.measure(points,"",Basis(Vector3.UP,PI*.5),Rect2(g.origin[0]+b[0],g.origin[1]+b[1],b[2]-b[0],b[3]-b[1]))*turn

static func build_additions(parent:Node3D,key:String,model,prepared:Dictionary)->Node3D:
 # Explicit setup-only inputs; ordinary callers and their route/culling spans stay unchanged.
 assert(prepared.maps.has(key))
 var root=Node3D.new();root.name="WesternRouteSourceAdditions";parent.add_child(root)
 var frame=preload("res://scripts/forest/forest_freyja_regions.gd").frame(key)
 var groups={};var anchors=[]
 for row in prepared.maps[key]:
  var serial=int(row.serial);var cell=Vector2(row.cell[0],row.cell[1]);var point:Vector2=frame.inverse()*(cell*3.)
  assert(model.terrain.mask_bounds().has_point(point),"Source additions must use an existing measured owner")
  # Reuse the Meadow batcher's local96m culling bounds without dropping any source station.
  var group=Vector3i(serial,floori(point.x/96.),floori(point.y/96.))
  if not groups.has(group):groups[group]=[[],[]]
  var pose=Transform3D(Basis(Vector3.UP,frame.get_rotation()),Vector3(point.x,model.surface_height(point.x,point.y),point.y))
  if row.recipe=="shore":
   var top:float=maxf(model.terrain.WATER_HEIGHT+2.10,pose.origin.y)
   for offset in [Vector2(-1.5,-1.5),Vector2(1.5,-1.5),Vector2(-1.5,1.5),Vector2(1.5,1.5)]:top=maxf(top,model.surface_height(point.x+offset.x,point.y+offset.y))
   pose.origin.y=top+.035;pose.basis=pose.basis.scaled(Vector3(1,(pose.origin.y-model.terrain.WATER_HEIGHT)/2.10,1))
  groups[group][0].append(pose);groups[group][1].append(row.cell);anchors.append([int(cell.x),int(cell.y),serial])
 for group in groups:
  var serial:int=group.x;var g:Dictionary=prepared.graphics[str(serial)];var poses:Array=groups[group][0]
  var first=root.get_child_count()
  if g.recipe=="tree":
   var values:Array=g.prepared_fit
   var native=Transform3D(Basis(Vector3(values[0],values[1],values[2]),Vector3(values[3],values[4],values[5]),Vector3(values[6],values[7],values[8])),Vector3(values[9],values[10],values[11]))
   for i in poses.size():poses[i]*=native
   var tint:Array=g.crown_linear_tint
   Meadow.batch(root,g.asset,poses,true,0.,Color(tint[0],tint[1],tint[2]))
  else:
   var node=MultiMeshInstance3D.new();node.name="SourceAdded_"+str(serial)
   node.multimesh=MultiMesh.new();node.multimesh.transform_format=MultiMesh.TRANSFORM_3D
   node.multimesh.mesh=load(g.prepared_mesh);node.multimesh.instance_count=poses.size()
   for i in poses.size():node.multimesh.set_instance_transform(i,poses[i])
   if g.family=="flowers":node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   root.add_child(node)
  var cells:Array=groups[group][1]
  for i in range(first,root.get_child_count()):
   root.get_child(i).set_meta("source_addition_serial",serial);root.get_child(i).set_meta("source_addition_cells",cells)
 root.set_meta("source_addition_anchors",anchors)
 return root

static func catalog()->Dictionary:
 if data.is_empty():data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/west_route_scenery.json"))
 return data

static func source_cliff_owned(model,serial:int,anchor:Vector2i)->bool:
 if not model.has_meta("source_cliff_study"):return false
 var study:Dictionary=model.get_meta("source_cliff_study")
 return model.falan_area==study.area and study.stations.has(Vector3i(anchor.x,anchor.y,serial))

static func source_house_owned(model,site:int)->bool:
 if not model.has_meta("source_cliff_study"):return false
 var study:Dictionary=model.get_meta("source_cliff_study")
 return model.falan_area==study.area and study.get("house_sites",{}).has(site)

static func build_source_cliffs(parent:Node3D,key:String,model,prepared:Dictionary)->Node3D:
 var row:Dictionary=prepared.maps[key];var size_=Vector2i(prepared.size[0],prepared.size[1]);var count_=size_.x*size_.y;var placements=[]
 for item in row.cliffs+row.entrances:
  var cell=Vector2i(item[0],item[1]);placements.append([0,0,Vector2.ZERO,int(item[2]),count_+cell.y*size_.x+cell.x,cell])
 var frame=preload("res://scripts/forest/forest_freyja_regions.gd").frame(key);var zero=frame.inverse()*Vector2.ZERO
 var root=Node3D.new();root.name="FullSourceCliffStudy";parent.add_child(root)
 root.transform=Transform3D(Basis(Vector3.UP,frame.get_rotation()),Vector3(zero.x,2,zero.y))
 if row.has("prepared_chunks"):
  for chunk in row.prepared_chunks:
   var node=MeshInstance3D.new();node.name=chunk.name;node.position=Vector3(chunk.position[0],chunk.position[1],chunk.position[2]);node.mesh=load(chunk.mesh);root.add_child(node)
  root.set_meta("recovered_cliff_cells",row.prepared_cells.map(func(cell):return Vector2i(cell[0],cell[1])))
  root.set_meta("recovered_cliff_chunks",row.prepared_chunks.size());root.set_meta("source_cliff_anchors",row.cliffs)
  return root
 root.set_meta("western_route_area",key);root.set_meta("western_route_height_model",model)
 var context=prepared.duplicate(false);context.texture=load(prepared.texture)
 load("res://scripts/forest/forest_original_cliffs.gd").build(root,placements,size_,row.walk.hex_decode(),Vector2.ZERO,100,Vector2i.ZERO,context)
 root.remove_meta("western_route_height_model");root.set_meta("source_cliff_anchors",row.cliffs)
 return root

static func contains(key:String,source:Vector2)->bool:
 var maps:Dictionary=catalog().maps
 if not maps.has(key):return false
 var cell=Vector2i(source.round())
 for row in maps[key].spans:
  if cell.y==int(row[0]) and cell.x>=int(row[1]) and cell.x<=int(row[2]):return true
 return false

static func contains_cliff(key:String,source:Vector2)->bool:
 if not catalog().maps.has(key):return false
 if not cliff_cells.has(key):
  var cells={}
  for row in catalog().maps[key].cliff_fill:cells[Vector2i(row[0],row[1])]=true
  cliff_cells[key]=cells
 return cliff_cells[key].has(Vector2i(source.round()))

static func outdoor_point(area:String,at:Vector2)->Vector2:
 return preload("res://scripts/forest/forest_freyja_regions.gd").frame(area)*at/3.0

static func tree_source(serial:int)->int:
 if serial>=11600:return 10058 if serial<11622 else 10085
 return 10058 if serial<=10074 else 10085 if serial<10088 else 10088

static func tree_fit(serial:int)->Basis:
 if fits.has(serial):return fits[serial]
 var asset=Meadow.crossgate_tree(tree_source(serial));var points=[]
 var rotation_=Basis(Vector3.UP,-PI*.25)
 for part in Meadow.source(asset):
  var box:AABB=part.mesh.get_aabb()
  for x in [box.position.x,box.end.x]:
   for y in [box.position.y,box.end.y]:
    for z in [box.position.z,box.end.z]:points.append(rotation_*(part.transform*Vector3(x,y,z)))
 fits[serial]=fit_points(serial,points,rotation_)
 return fits[serial]

static func fit_points(serial:int,points:Array,rotation_:Basis=Basis.IDENTITY)->Basis:
 var g:Dictionary=catalog().graphics[str(serial)]
 var width=float(g.bounds[2])-float(g.bounds[0]);var top=float(g.origin[1])+float(g.bounds[1])
 var left=INF;var right=-INF
 for p:Vector3 in points:
  var x=(p.x+p.z)*32.0/3.0;left=minf(left,x);right=maxf(right,x)
 var horizontal=width/(right-left)
 var vertical=INF
 for p:Vector3 in points:
  if p.y>.1:vertical=minf(vertical,((p.z-p.x)*8.0*horizontal-top)/(p.y*9.977753))
 return rotation_.scaled(Vector3(horizontal,vertical,horizontal))

static func build(root:Node3D,key:String,model=null,exclude_tree:Callable=Callable()):
 if not catalog().maps.has(key):return
 var groups={}
 var original=load("res://scripts/forest/forest_original_maps.gd")
 var outdoor=key in ["freyja","west_lakes"]
 var frame=preload("res://scripts/forest/forest_freyja_regions.gd").frame(key) if outdoor else Transform2D.IDENTITY
 for row in catalog().maps[key].trees:
  var serial=int(row[2]);var source=Vector2(row[0],row[1]);var at:Vector2
  if exclude_tree.is_valid() and exclude_tree.call(source):continue
  if outdoor:at=frame.inverse()*(source*3)
  else:at=original.source_point(original.runtime_id(int(key)),Vector2i(source))
  var y:float=model.surface_height(at.x,at.y) if outdoor else 0.0
  var basis=Basis.IDENTITY if serial>=11622 else tree_fit(serial)
  if outdoor:basis=Basis(Vector3.UP,frame.get_rotation())*basis
  var palette=int(catalog().graphics[str(serial)].get("palette",0))
  var group=Vector3i(serial,2,0) if serial>=11622 else Vector3i(tree_source(serial),3 if serial>=11609 else int(serial>=11600),palette)
  if not groups.has(group):groups[group]=[]
  groups[group].append(Transform3D(basis,Vector3(at.x,y,at.y)))
 var before=root.get_child_count()
 for group in groups:
  if group.y==2:batch_saplings(root,group.x,groups[group])
  elif group.y in [1,3]:
   load("res://scripts/forest/forest_frostpass_art.gd").snowy_grove(root,groups[group],group.x,"WesternRouteNativeSnowTrees")
   for part in root.get_child(root.get_child_count()-1).get_children():
    if part.get_meta("crossgate_tree_part","")=="Canopy":part.material_override.set_shader_parameter("snow_whiteness",.96 if group.y==3 else .54)
  else:
   var tint:Array=catalog().palettes[group.z]
   Meadow.batch(root,Meadow.crossgate_tree(group.x),groups[group],true,0.0,Color(tint[0],tint[1],tint[2]))
 for i in range(before,root.get_child_count()):root.get_child(i).set_meta("western_route_source_trees",true)
 root.set_meta("western_route_tree_count",catalog().maps[key].trees.size())
 if outdoor:
  cliffs(root,key,model)
  details(root,key,model)
  banks(root,key,model)

static func sapling_point(serial:int,p:Array,depth:float=0.0)->Vector3:
 var g:Dictionary=catalog().graphics[str(serial)]
 var u=(float(p[0])+float(g.origin[0]))*3/32
 var delta=depth*sqrt(2.0)
 return Vector3((u-delta)*.5,(delta*8-float(p[1])-float(g.origin[1]))/9.977753,(u+delta)*.5)

static func sapling(serial:int,calm:bool=false)->Mesh:
 var key=Vector2i(serial,int(calm))
 if saplings.has(key):return saplings[key]
 var original=load("res://scripts/forest/forest_original_maps.gd")
 var g:Dictionary=original.Art.data().graphics[str(serial)]
 var row:Dictionary=catalog().graphics[str(serial)]
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 var snow=SurfaceTool.new();snow.begin(Mesh.PRIMITIVE_TRIANGLES)
 var lamps=original.Forms.Lamps
 lamps.prepare_primitives()
 var segments=[];var supports=0
 for branch in row.branches:
  for i in range(branch.size()-1):
   var a=sapling_point(serial,branch[i]);var b=sapling_point(serial,branch[i+1])
   lamps.rod(tool,a,b,.09+.20*(1.0-float(i)/branch.size()));segments.append([a,b])
 for i in row.snow_clusters.size():
  var cluster:Array=row.snow_clusters[i]
  var at=sapling_point(serial,cluster,sin(i*2.39996)*.55)
  if calm:
   var nearest:Vector3=segments[0][0];var distance=INF
   for segment in segments:
    var point=Geometry3D.get_closest_point_to_segment(at,segment[0],segment[1])
    if point.distance_squared_to(at)<distance:nearest=point;distance=point.distance_squared_to(at)
   if distance>.24*.24:
    lamps.rod(tool,nearest,at-Vector3.UP*.06,.028);supports+=1
  lamps.oval(snow,at,Vector3(.95,.28,.80)*(.65+.35*float(cluster[2])))
 var texture=original.Art.solid_texture(int(g.page))
 if calm:
  var result=ArrayMesh.new()
  for slot in 2:
   var mesh:Mesh=tool.commit() if slot==0 else snow.commit()
   if not sapling_materials.has(slot):
    var material=original.Forms.Source.material(texture).duplicate()
    material.set_shader_parameter("use_base_texture",false);material.set_shader_parameter("original_palette",false)
    material.set_shader_parameter("base_color",Color("70614d") if slot==0 else Color("d2e0e6"))
    material.set_shader_parameter("surface_kind",0.0 if slot==0 else 5.0)
    sapling_materials[slot]=material
   result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,mesh.surface_get_arrays(0))
   result.surface_set_material(slot,sapling_materials[slot])
  result.set_meta("snow_twig_connections",supports)
  saplings[key]=result;return result
 var skin=original.Forms.Source.new([Rect2(g.rect[0],g.rect[1],g.rect[2],g.rect[3]),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],texture,1.0/9.977753)
 original.Forms.append(skin,tool.commit())
 original.Forms.append(skin,snow.commit())
 saplings[key]=skin.finish()
 return saplings[key]

static func batch_saplings(root:Node3D,serial:int,poses:Array,calm:bool=false):
 var node=MultiMeshInstance3D.new();node.name="WesternRouteNativeSapling_%d"%serial
 node.multimesh=MultiMesh.new();node.multimesh.transform_format=MultiMesh.TRANSFORM_3D;node.multimesh.mesh=sapling(serial,calm);node.multimesh.instance_count=poses.size()
 for i in poses.size():node.multimesh.set_instance_transform(i,poses[i])
 root.add_child(node)

static func details(root:Node3D,key:String,model):
 var original=load("res://scripts/forest/forest_original_maps.gd")
 var frame=preload("res://scripts/forest/forest_freyja_regions.gd").frame(key)
 var groups={}
 for row in catalog().maps[key].details:
  var serial=int(row[2]);var family:String=row[3]
  var native:Dictionary=catalog().graphics[str(serial)]
  var g:Dictionary=native.graphic if native.has("graphic") else original.Art.data().graphics[str(serial)]
  var texture=load("res://assets/maps/falan/west_route_details.png") if native.has("graphic") else original.Art.solid_texture(int(g.page))
  var mesh=original.Forms.mesh(serial,family,g,texture)
  if not groups.has(serial):groups[serial]=[mesh,[]]
  var pose_key=Vector2i(serial,2)
  if not fits.has(pose_key):
   var points=[]
   for slot in mesh.get_surface_count():
    for p in mesh.surface_get_arrays(slot)[Mesh.ARRAY_VERTEX]:points.append(p)
   fits[pose_key]=fit_points(serial,points)
  var at=frame.inverse()*(Vector2(row[0],row[1])*3)
  groups[serial][1].append(Transform3D(Basis(Vector3.UP,frame.get_rotation())*fits[pose_key],Vector3(at.x,model.surface_height(at.x,at.y),at.y)))
 for serial in groups:
  var node=MultiMeshInstance3D.new();node.name="WesternRouteNativeDetail_%d"%serial
  node.multimesh=MultiMesh.new();node.multimesh.transform_format=MultiMesh.TRANSFORM_3D;node.multimesh.mesh=groups[serial][0];node.multimesh.instance_count=groups[serial][1].size()
  for i in groups[serial][1].size():node.multimesh.set_instance_transform(i,groups[serial][1][i])
  root.add_child(node)
 root.set_meta("western_route_detail_count",catalog().maps[key].details.size())

static func cliffs(root:Node3D,key:String,model):
 var row:Dictionary=catalog().maps[key]
 var native=load("res://scripts/forest/forest_original_cliffs.gd")
 var size_=Vector2i(row.bounds[2],row.bounds[3]);var start=Vector2i(row.bounds[0],row.bounds[1])
 var placements=[];var cells=size_.x*size_.y
 for item in row.cliffs:
  var cell=Vector2i(item[0],item[1])-start
  placements.append([0,0,Vector2.ZERO,int(item[2]),cells+cell.y*size_.x+cell.x,cell])
 var frame=preload("res://scripts/forest/forest_freyja_regions.gd").frame(key)
 var zero=frame.inverse()*Vector2.ZERO
 var field=Node3D.new();field.name="WesternRouteSourceCliffs";root.add_child(field)
 field.set_meta("western_route_area",key)
 field.set_meta("western_route_height_model",model)
 field.transform=Transform3D(Basis(Vector3.UP,frame.get_rotation()),Vector3(zero.x,2,zero.y))
 native.build(field,placements,size_,row.walk.hex_decode(),Vector2(start)*3,100,start)
 field.remove_meta("western_route_height_model")

static func banks(root:Node3D,key:String,model):
 var rows:Array=catalog().maps[key].banks
 if rows.is_empty():return
 var frame=preload("res://scripts/forest/forest_freyja_regions.gd").frame(key).inverse()
 var mesh=SurfaceTool.new();mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
 var source=load("res://scripts/forest/forest_freyja_destination_art.gd")
 for row in rows:source.coast_bank(mesh,model,frame,Vector2(row[0],row[1]),int(row[2]))
 var material=preload("res://scripts/forest/forest_falan_room_art.gd").painted_atlas(preload("res://assets/maps/falan/undersea_coast_banks.png"))
 material.set_shader_parameter("alpha_cutout",true)
 var node=MeshInstance3D.new();node.name="WesternRouteNativeShoreBanks"
 node.mesh=mesh.commit();node.material_override=material
 node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 root.add_child(node)
 root.set_meta("western_route_bank_count",rows.size())
