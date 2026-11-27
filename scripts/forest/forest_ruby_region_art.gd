extends RefCounted
## Source-sized vegetation at native anchors. Existing owners keep all physical shapes.
const Fit=preload("res://scripts/forest/forest_falan_proportions.gd")
const Meadow=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const Fence=preload("res://scripts/forest/forest_scenery.gd")
static var data:Dictionary={}
static var fits:Dictionary={}
static var leaf_materials:Dictionary={}
static var walls:Dictionary={}
static var wall_meshes:Dictionary={}
static var caves:Dictionary={}
static var cave_meshes:Dictionary={}
static var annex_data:Dictionary={}
static var annex_meshes:Dictionary={}
static var palm_materials:Dictionary={}
static var palm_shader:Shader
static var palm_meshes:Dictionary={}
static var native_surface:Shader

static func source_surface(paint:ShaderMaterial)->ShaderMaterial:
 if native_surface==null:
  native_surface=Shader.new()
  native_surface.code=paint.shader.code.replace("if(falan_source_visibility)source_camera=","if(falan_source_projection)source_camera=").replace("if(falan_source_visibility)source_weight=","if(falan_source_projection)source_weight=")
 paint.shader=native_surface
 return paint
static func catalog()->Dictionary:
 if data.is_empty():
  data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/black_prayer/region-trees.json"))
  var coast=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/sokia/scenery/vegetation.json"))
  data.areas.merge(coast.areas,true);data.graphics.merge(coast.graphics,false)
 return data

static func contains(model,point:Vector2)->bool:
 var area:String=model.falan_area
 if not catalog().areas.has(area):return false
 var bounds=catalog().areas[area].bounds
 if bounds==null:return true
 var region=load("res://scripts/forest/forest_freyja_regions.gd")
 var cell:Vector2=region.frame(area)*point/3.
 return cell.x>=bounds[0] and cell.x<=bounds[2] and cell.y>=bounds[1] and cell.y<=bounds[3]

static func measured(serial:int,points:Array[Vector3])->Transform3D:
 if fits.has(serial):return fits[serial]
 var g:Dictionary=catalog().graphics[str(serial)];var b:Array=g.bounds
 var target=Rect2(g.origin[0]+b[0],g.origin[1]+b[1],b[2]-b[0],b[3]-b[1])
 fits[serial]=Fit.measure(points,"",Basis(Vector3.UP,PI*.5),target)
 return fits[serial]

static func palm_fit(serial:int)->Transform3D:
 return measured(serial,Fit.mesh_points(load("res://scripts/forest/forest_sokia_details.gd").palm(serial)))

static func palm_shape(serial:int)->Mesh:
 if palm_meshes.has(serial):return palm_meshes[serial]
 var details=load("res://scripts/forest/forest_sokia_details.gd");var raw:Mesh=details.palm(serial)
 var profile:Array=details.Data.PALMS[serial]
 if not profile[5].is_empty() or details.Data.PALM_FRONDS.has(serial):return raw
 var pose=palm_fit(serial);var crown:Vector3=pose*details.crown_point(serial)
 var arrays=raw.surface_get_arrays(0);var points:Array[Vector3]=[]
 var vertices:PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var normals:PackedVector3Array=arrays[Mesh.ARRAY_NORMAL]
 var tile:Vector2=details.Data.TILES["leaf_"+str(serial)]
 for i in vertices.size():
  if arrays[Mesh.ARRAY_TEX_UV2][i]==tile:points.append(pose*vertices[i]-crown)
 # Fit the source crown separately so a correct whole-tree box cannot hide overlong drooping fronds.
 # shortcut: One view fixes bounds, not frond depth; replace this fit when original multi-view evidence is available.
 var depth_basis=Basis.IDENTITY
 var depth_step=Basis(Vector3(.75,0,.25),Vector3.UP,Vector3(.25,0,.75))
 var ground:Array[Vector3]=[]
 for p in points:ground.append(Vector3(p.x,0,p.z))
 var ground_bounds=Fit.projected_bounds(ground,Transform3D(Basis(Vector3.UP,PI*.5),Vector3.ZERO))
 while ground_bounds.size.y*(profile[1]/.031)/ground_bounds.size.x>=profile[2]/.031:
  depth_basis=depth_step*depth_basis;ground.clear()
  for i in points.size():points[i]=depth_step*points[i];ground.append(Vector3(points[i].x,0,points[i].z))
  ground_bounds=Fit.projected_bounds(ground,Transform3D(Basis(Vector3.UP,PI*.5),Vector3.ZERO))
 var fitted=Fit.measure(points,"",Basis(Vector3.UP,PI*.5),Rect2(0,0,profile[1]/.031,profile[2]/.031))
 var leaf_basis=fitted.basis*depth_basis
 var adjust=pose.affine_inverse()*Transform3D(leaf_basis,crown-leaf_basis*crown)*pose
 assert((adjust*details.crown_point(serial)).distance_to(details.crown_point(serial))<.001,"Crown fitting must keep the trunk attachment")
 var normal=adjust.basis.inverse().transposed()
 for i in vertices.size():
  if arrays[Mesh.ARRAY_TEX_UV2][i]!=tile:continue
  vertices[i]=adjust*vertices[i];normals[i]=(normal*normals[i]).normalized()
 arrays[Mesh.ARRAY_VERTEX]=vertices;arrays[Mesh.ARRAY_NORMAL]=normals
 points.clear()
 for i in vertices.size():
  if arrays[Mesh.ARRAY_TEX_UV2][i]==tile:points.append(pose*vertices[i])
 var measured_crown=Fit.projected_bounds(points,Transform3D(Basis(Vector3.UP,PI*.5),Vector3.ZERO))
 assert(measured_crown.size.distance_to(Vector2(profile[1]/.031,profile[2]/.031))<.05,"The fitted crown must retain its measured source dimensions")
 var mesh=ArrayMesh.new();mesh.add_surface_from_arrays(raw.surface_get_primitive_type(0),arrays);mesh.surface_set_material(0,raw.surface_get_material(0))
 mesh.set_meta("native_crown_pixels",Vector2(profile[1]/.031,profile[2]/.031))
 palm_meshes[serial]=mesh
 return mesh

static func tree_fit(serial:int)->Transform3D:
 var points:Array[Vector3]=[];var turn=Transform3D(Basis(Vector3.UP,-PI*.25),Vector3.ZERO)
 if fits.has(serial):return fits[serial]*turn
 for part in Meadow.source(Meadow.crossgate_tree(serial)):points.append_array(Fit.mesh_points(part.mesh,turn*part.transform))
 return measured(serial,points)*turn

static func fence_fit(serial:int)->Transform3D:
 var turn=Transform3D(Basis(Vector3.UP,PI*.5 if serial in [11363,11368,11370] else 0.),Vector3.ZERO)
 if fits.has(serial):return fits[serial]*turn
 var points:Array[Vector3]=[]
 for part in Meadow.source(Fence.asset("fence")):points.append_array(Fit.mesh_points(part.mesh,turn*part.transform))
 return measured(serial,points)*turn

static func wall_mesh(serial:int,source:Mesh)->Mesh:
 if wall_meshes.has(serial):return wall_meshes[serial]
 if walls.is_empty():walls=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/black_prayer/kili-walls.json"))
 var g:Dictionary=walls[str(serial)];var r:Array=g.rect;var origin=Vector2(g.origin[0],g.origin[1])
 var atlas:Texture2D=load("res://assets/maps/falan/black_prayer/kili-walls.png")
 var mesh=ArrayMesh.new()
 for slot in source.get_surface_count():
  var arrays=source.surface_get_arrays(slot)
  var native=SurfaceTool.new();native.begin(Mesh.PRIMITIVE_TRIANGLES)
  var hidden=SurfaceTool.new();hidden.begin(Mesh.PRIMITIVE_TRIANGLES)
  var counts=[0,0];var indices=arrays[Mesh.ARRAY_INDEX]
  var indexed=indices is PackedInt32Array and not indices.is_empty()
  for j in (indices.size() if indexed else arrays[Mesh.ARRAY_VERTEX].size()):
   var i=indices[j] if indexed else j
   var p:Vector3=arrays[Mesh.ARRAY_VERTEX][i];var n:Vector3=arrays[Mesh.ARRAY_NORMAL][i]
   # Only the two recorded stone faces use projected paint; solid backs/caps keep native tile paint.
   var visible=n.x<-.01 or n.z>.01
   var tool:SurfaceTool=native if visible else hidden
   tool.set_normal(n)
   if visible:
    var pixel=Vector2((p.x+p.z)*Fit.HORIZONTAL,(p.z-p.x)*Fit.FLOOR-p.y*Fit.VERTICAL)-origin
    pixel=pixel.clamp(Vector2.ONE*.5,Vector2(r[2],r[3])-Vector2.ONE*.5)
    tool.set_uv((Vector2(r[0],r[1])+pixel)/atlas.get_size())
   else:
    tool.set_uv(arrays[Mesh.ARRAY_TEX_UV][i]);tool.set_uv2(arrays[Mesh.ARRAY_TEX_UV2][i])
   tool.add_vertex(p);counts[0 if visible else 1]+=1
  for side in 2:
   if counts[side]==0:continue
   var part=(native if side==0 else hidden).commit()
   mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,part.surface_get_arrays(0))
   mesh.surface_set_material(mesh.get_surface_count()-1,Fit.Source.material(atlas) if side==0 else source.surface_get_material(slot))
 wall_meshes[serial]=mesh
 return mesh

static func cave_mesh(serial:int)->Mesh:
 if cave_meshes.has(serial):return cave_meshes[serial]
 var g:Dictionary=caves.graphics[str(serial)];var profile:Dictionary=g.profile;var r:Array=g.rect
 var atlas:Texture2D=load(g.get("atlas","res://assets/maps/falan/black_prayer/region-cave-walls.png"))
 var skin=Fit.Source.new([Rect2(r[0],r[1],r[2],r[3]),-Vector2(g.origin[0],g.origin[1]),Vector2.ONE,0],atlas,profile.pixel_height)
 var parts=load("res://scripts/forest/forest_tina_building_details.gd")
 var points=[];var pixels=[]
 for p in profile.vertices:points.append(Vector3(p[0],p[1],p[2]))
 for p in profile.uv_pixels:pixels.append(Vector2(p[0],p[1]))
 for level in 6:
  for side in 16:
   var i=level*16+side;var j=level*16+(side+1)%16
   parts.painted_quad(skin,points[j],points[j+16],points[i+16],points[i],[pixels[j],pixels[j+16],pixels[i+16],pixels[i]])
 var crown=Vector3(profile.crown[0],profile.crown[1],profile.crown[2]);var top=Vector2(profile.crown_uv[0],profile.crown_uv[1])
 for side in 16:
  var a=96+side;var b=96+(side+1)%16
  var normal:Vector3=(crown-points[a]).cross(points[b]-points[a]).normalized()
  for i in 3:
   var vertex:Vector3=[points[a],points[b],crown][i];var pixel:Vector2=[pixels[a],pixels[b],top][i]
   skin.surface.set_normal(normal);skin.surface.set_uv((Vector2(r[0],r[1])+pixel)/atlas.get_size());skin.surface.add_vertex(vertex)
 skin.surface.generate_normals()
 var raw=skin.finish();var b:Array=g.bounds
 var fit=Fit.measure(Fit.mesh_points(raw),"",Basis(Vector3.UP,PI*.5),Rect2(g.origin[0]+b[0],g.origin[1]+b[1],b[2]-b[0],b[3]-b[1]))
 var mesh=Fit.transformed(raw,fit)
 var rgb:Array=g.fallback_rgb
 var paint=Fit.material("",Transform3D(Basis(Vector3.UP,PI*.5),Vector3.ZERO),true,atlas,Rect2(r[0],r[1],r[2],r[3]),load(g.get("mask","res://assets/maps/falan/black_prayer/region-cave-mask.png")),Color(rgb[0],rgb[1],rgb[2]),null,Rect2(g.origin[0],g.origin[1],r[2],r[3]))
 paint.set_shader_parameter("original_palette",true)
 paint.set_shader_parameter("falan_source_contour",true)
 paint=source_surface(paint)
 if serial>=213080 and serial<=213115:
  # Native Great Wind wall silhouettes keep depth; the established stone kit covers
  # faces that the one-view sprite cannot texture without stretching its cracks.
  paint=load("res://scripts/forest/forest_stone_fort.gd").material(Color(rgb[0],rgb[1],rgb[2]),false)
 mesh.surface_set_material(0,paint)
 cave_meshes[serial]=mesh
 return mesh

static func build_cave_walls(root:Node3D,id:int,model=null):
 if caves.is_empty():
  caves=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/black_prayer/region-cave-walls.json"))
  var coast=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/sokia/scenery/cliffs.json"))
  caves.maps.merge(coast.maps,true);caves.graphics.merge(coast.graphics,false)
 if not caves.maps.has(str(id)):return
 var indoor=load("res://scripts/forest/forest_falan_interior.gd")
 var outdoor=id in [2100,100,300]
 var floor_=[] if outdoor else indoor.floor_info(id)
 var frame=Transform2D.IDENTITY
 if outdoor:
  var regions=load("res://scripts/forest/forest_freyja_regions.gd")
  frame=Transform2D(0.,regions.Sites.VILLAGES.venoa[2]) if id==2100 else regions.frame(model.falan_area).inverse()
 var size_:Vector2i=Vector2i.ZERO if outdoor else floor_[0]
 var origin:Vector2=Vector2.ZERO if outdoor else floor_[1]
 var bits=PackedByteArray() if outdoor else floor_[2].hex_decode()
 var turn=Basis(Vector3(frame.x.x,0,frame.x.y),Vector3.UP,Vector3(frame.y.x,0,frame.y.y))
 var groups={}
 for row in caves.maps[str(id)]:
  var cell=Vector2i(row[0],row[1]);var serial=int(row[2])
  if id==100 and load("res://scripts/forest/forest_west_route_scenery.gd").source_cliff_owned(model,serial,cell):continue
  if id==300 and not contains(model,frame*(Vector2(cell)*3.)):continue
  if caves.graphics[str(serial)].get("void_only",false):continue
  if not outdoor and indoor.open_cell(bits,size_,cell.x,cell.y):continue
  if not groups.has(serial):groups[serial]=[]
  var point:Vector2=frame*(Vector2(cell)*3.) if outdoor else origin+Vector2(cell)*3.
  groups[serial].append(Transform3D(turn,Vector3(point.x,model.surface_height(point.x,point.y) if outdoor else 0.,point.y)))
 var count=0
 for serial in groups:
  var node=MultiMeshInstance3D.new();node.name="RubyRegionNativeCaveWall_"+str(serial)
  node.multimesh=MultiMesh.new();node.multimesh.transform_format=MultiMesh.TRANSFORM_3D;node.multimesh.mesh=cave_mesh(serial)
  node.multimesh.instance_count=groups[serial].size()
  for i in groups[serial].size():node.multimesh.set_instance_transform(i,groups[serial][i]);count+=1
  root.add_child(node)
 root.set_meta("ruby_region_native_cave_walls",count)

static func finish(root:Node3D,model):
 if model.falan_area in ["venoa","south_lakes"]:
  build_cave_walls(root,{"venoa":2100,"south_lakes":100}[model.falan_area],model)
 var interior:bool=model.falan_area=="interior"
 var prayer=load("res://scripts/forest/forest_black_prayer.gd")
 if interior and model.falan_floor==13001:
  build_cave_walls(root,13001)
  load("res://scripts/forest/forest_sokia_great_wind_floor.gd").build(root,load("res://scripts/forest/forest_falan_interior.gd").floor_info(13001)[1])
  for node in root.find_children("*","MeshInstance3D",true,false):
   if node.name in ["ArchivedCaveRockWalls","ArchivedUnderseaEdges","VenoaStoneCrags","ArchivedRoomFloor","ArchivedCavePools"]:node.hide()
  return
 if interior and (model.falan_floor in [15003,15004,15005] or prayer.owns(model.falan_floor)):
  build_cave_walls(root,model.falan_floor)
  if model.falan_floor==15004:build_annex(root)
  var native_height=138.0/Fit.VERTICAL
  var materials={}
  for node in root.find_children("*","MeshInstance3D",true,false):
   if caves.maps.has(str(model.falan_floor)) and node.name in ["ArchivedCaveRockWalls","ArchivedUnderseaEdges"]:
    node.hide() # Native object volumes replace the older boundary strips, without touching their colliders.
   if node.name=="ArchivedCaveRockWalls":node.scale.y=native_height/10.
   elif node.name=="ArchivedUnderseaEdges":node.scale.y=native_height/8.46
   elif node.name=="VenoaStoneCrags":node.scale.y=native_height/6.35
   elif "Ceiling" in node.name:node.position.y+=native_height-8.5
   var material:Material=node.material_override
   if material is ShaderMaterial and material.shader.resource_path.get_file() in ["habaru_ceiling.gdshader","forest_painterly_surface.gdshader"]:
    if not materials.has(material):
     var owned:ShaderMaterial=material.duplicate();owned.set_shader_parameter("route_finish",0.)
     materials[material]=owned
    node.material_override=materials[material]
  return
 if model.falan_area not in ["kili","ghana"] and not load("res://scripts/forest/forest_sokia_scenery.gd").owns(model.falan_area):return
 for node in root.find_children("NativeSokiaPalm_*","MultiMeshInstance3D",true,false):
  var inside=true
  for i in node.multimesh.instance_count:
   var p:Vector3=node.multimesh.get_instance_transform(i).origin
   if not contains(model,Vector2(p.x,p.z)):inside=false;break
  if not inside:continue
  node.multimesh.mesh=palm_shape(int(node.get_meta("source_graphic")))
  var source:ShaderMaterial=node.multimesh.mesh.surface_get_material(0)
  if not palm_materials.has(source):
   if palm_shader==null:
    palm_shader=Shader.new();palm_shader.code=source.shader.code.replace("render_mode cull_back;","render_mode cull_disabled;")
   var material:ShaderMaterial=source.duplicate();material.shader=palm_shader;palm_materials[source]=material
  node.material_override=palm_materials[source]
 for node in root.find_children("*","MeshInstance3D",true,false):
  var serial=int(node.get_meta("kili_wall_graphic",0))
  if serial>=11230 and serial<=11250:node.mesh=wall_mesh(serial,node.mesh)

static func build_annex(root:Node3D):
 if annex_data.is_empty():annex_data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/black_prayer/undersea-annex.json"))
 var forms=load("res://scripts/forest/forest_original_map_solids.gd")
 var original=load("res://scripts/forest/forest_original_map_art.gd")
 var atlas:Texture2D=load("res://assets/maps/falan/black_prayer/undersea-annex.png")
 var mask:Texture2D=load("res://assets/maps/falan/black_prayer/undersea-annex-mask.png")
 for row in annex_data.placements:
  var serial=int(row[2]);var g:Dictionary=annex_data.graphics[str(serial)]
  if not annex_meshes.has(serial):
   var source:Dictionary=original.data().graphics.get(str(serial),g)
   var family:String=forms.kind(serial,false,source)
   var source_paint:Texture2D=original.solid_texture(int(source.page)) if source.has("page") else atlas
   if family=="floor" and source.has("page"):source_paint=load(original.ROOT+original.data().pages[int(source.page)])
   var cache_key=[serial,family];var cached=forms.meshes.has(cache_key)
   var raw:Mesh=forms.mesh(serial,family,source,source_paint)
   if not cached:forms.meshes.erase(cache_key) # This route keeps only its owned painted derivative.
   assert(raw!=null,"A native guard-area prop must have a reusable solid form")
   var b:Array=g.bounds;var r:Array=g.rect
   var target=Rect2(g.origin[0]+b[0],g.origin[1]+b[1],b[2]-b[0],b[3]-b[1])
   var fit:Transform3D
   if raw.get_aabb().size.y>.001:fit=Fit.measure(Fit.mesh_points(raw),"",Basis(Vector3.UP,PI*.5),target)
   else:
    var before=Fit.projected_bounds(Fit.mesh_points(raw),Transform3D(Basis(Vector3.UP,PI*.5),Vector3.ZERO))
    var scale_=target.size.x/before.size.x;var delta=target.get_center()-before.get_center()*scale_
    fit=Transform3D(Basis.IDENTITY.scaled(Vector3(scale_,1,scale_)),Vector3((delta.x/Fit.HORIZONTAL-delta.y/Fit.FLOOR)*.5,0,(delta.x/Fit.HORIZONTAL+delta.y/Fit.FLOOR)*.5))
   var mesh=Fit.transformed(raw,fit);var rgb:Array=g.fallback_rgb
   var paint=Fit.material("",Transform3D(Basis(Vector3.UP,PI*.5),Vector3.ZERO),true,atlas,Rect2(r[0],r[1],r[2],r[3]),mask,Color(rgb[0],rgb[1],rgb[2]),null,Rect2(g.origin[0],g.origin[1],r[2],r[3]))
   paint.set_shader_parameter("original_palette",true);paint.set_shader_parameter("falan_source_contour",true)
   for slot in mesh.get_surface_count():mesh.surface_set_material(slot,source_surface(paint))
   annex_meshes[serial]=mesh
  var node=MeshInstance3D.new();node.mesh=annex_meshes[serial]
  node.name="NativeUnderseaAnnex_"+str(serial);node.position=Vector3(-45+row[0]*3,0,-75+row[1]*3)
  node.set_meta("source_cell",Vector2i(row[0],row[1]));node.set_meta("source_graphic",serial);node.set_meta("ruby_undersea_annex",true);root.add_child(node,true)

static func build(root:Node3D,model):
 var area:String=model.falan_area
 if not catalog().areas.has(area):return
 var regions=load("res://scripts/forest/forest_freyja_regions.gd")
 var frame=Transform2D(0.,regions.Sites.VILLAGES[area][2]) if area in ["venoa","kili","ghana"] else regions.frame(area).inverse()
 var groups={};var count=0
 var fences=[]
 for row in catalog().areas[area].fences:
  var serial=int(row[2]);var g:Dictionary=catalog().graphics[str(serial)]
  var span=Vector2(g.span[0],g.span[1]);var cell=Vector2(row[0],row[1])+Vector2((span.x-1)*.5,-(span.y-1)*.5)
  var point:Vector2=frame*(cell*3.)
  if not model.terrain.mask_bounds().has_point(point):continue
  fences.append(Transform3D(Basis.IDENTITY,Vector3(point.x,model.surface_height(point.x,point.y),point.y))*fence_fit(serial))
 if not fences.is_empty():Meadow.batch(root,Fence.asset("fence"),fences)
 for row in catalog().areas[area].trees:
  var serial=int(row[2]);var point:Vector2=frame*(Vector2(row[0],row[1])*3.)
  if serial>=11188 or not model.terrain.mask_bounds().has_point(point):continue
  if not groups.has(serial):groups[serial]=[]
  var at=Vector3(point.x,model.surface_height(point.x,point.y),point.y)
  groups[serial].append(Transform3D(Basis.IDENTITY,at)*tree_fit(serial));count+=1
 for serial in groups:
  var first=root.get_child_count()
  Meadow.batch(root,Meadow.crossgate_tree(serial),groups[serial],true)
  for index in range(first,root.get_child_count()):
   var part=root.get_child(index)
   if part is MultiMeshInstance3D:
    part.set_meta("ruby_region_tree",serial)
    if part.get_meta("crossgate_tree_part","")=="Canopy" and part.material_override is ShaderMaterial:
     if not leaf_materials.has(serial):
      var material:ShaderMaterial=part.material_override.duplicate()
      var native=10058 if serial<10074 else 10085 if serial<10088 else 10088
      var source:Array=catalog().graphics[str(serial)].leaf_rgb;var base:Array=catalog().palettes[str(native)]
      material.set_shader_parameter("foliage_tint",Vector3(source[0]/base[0],source[1]/base[1],source[2]/base[2]))
      leaf_materials[serial]=material
     part.material_override=leaf_materials[serial]
 root.set_meta("ruby_region_native_trees",count)
 root.set_meta("ruby_region_native_fences",fences.size())
