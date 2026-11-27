extends RefCounted
## Route-owned presentation; original maps keep travel, native collision and NPCs.
const Art=preload("res://scripts/forest/forest_original_map_art.gd")
const Forms=preload("res://scripts/forest/forest_original_map_solids.gd")
const Fit=preload("res://scripts/forest/forest_falan_proportions.gd")
const Meadow=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const Harbor=preload("res://scripts/forest/forest_tina_harbor_details.gd")
const Parts=preload("res://scripts/forest/forest_falan_fort_parts.gd")
const Civic=preload("res://scripts/forest/forest_falan_civic_exterior.gd")
const Ground=preload("res://scripts/forest/forest_tina_ground.gd")
const Travel=preload("res://scripts/forest/forest_travel_stone_art.gd")
static var data:Dictionary={}
static var walls:Dictionary={}
static var meshes:Dictionary={}
static var tree_fits:Dictionary={}
static var scopes:Dictionary={}

static func catalog()->Dictionary:
 if data.is_empty():
  data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/university_route/scenery.json"))
  var region=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/snow_region/scenery.json"))
  data.graphics.merge(region.graphics,true)
  for key in region.maps:
   if not data.maps.has(key):data.maps[key]=region.maps[key];continue
   data.maps[key].spans.append_array(region.maps[key].spans)
   var anchors={}
   for row in data.maps[key].placements:anchors[Vector2i(row[0],row[1])]=true
   for row in region.maps[key].placements:
    if not anchors.has(Vector2i(row[0],row[1])):data.maps[key].placements.append(row)
 return data

static func contains(source:int,cell:Vector2i)->bool:
 var key=str(source)
 if not catalog().maps.has(key):return false
 if not scopes.has(key):
  var rows={}
  for span in catalog().maps[key].spans:
   var y=int(span[0])
   if not rows.has(y):rows[y]=[]
   rows[y].append(Vector2i(span[1],span[2]))
  scopes[key]=rows
 return scopes[key].has(cell.y) and scopes[key][cell.y].any(func(span):return cell.x>=span.x and cell.x<=span.y)

static func native_fit(model:Mesh,serial:int)->Mesh:
 var g:Dictionary=catalog().graphics[str(serial)];var b:Array=g.bounds
 var target=Rect2(float(g.origin[0])+b[0],float(g.origin[1])+b[1],b[2]-b[0],b[3]-b[1])
 var pose=Fit.measure(Fit.mesh_points(model),"",Basis(Vector3.UP,PI*.5),target)
 return Fit.transformed(model,pose)

static func owns(source:int,serial:int,cell:Vector2i)->bool:
 if not contains(source,cell) or not catalog().graphics.has(str(serial)):return false
 if source==4000 and Forms.Cliffs.continuous(serial):return true
 if shore(serial):return true
 if serial in Travel.ROTATIONS:return true
 return serial in range(11317,11363) or serial in range(11363,11391) or serial in Parts.Data.PARTS or serial==10604 or serial in [10401,10402,10422,10426,10427,10428,10452,10453,10456,10463,10466,10467,10626,10627,10628,10629,10630,10671] or serial in range(11625,11711) or serial in range(12160,12500) or serial in range(13500,13540)

static func shore(serial:int)->bool:
 return Ground.shore(serial) or serial in range(12602,12674) or Art.data().graphics[str(serial)].get("shore_bank",false)

static func mesh(source:int,serial:int,g:Dictionary)->Mesh:
 if serial==10604:return null
 if source==4000 and Forms.Cliffs.continuous(serial):return null
 if meshes.has(serial):return meshes[serial]
 var model:Mesh
 if shore(serial):model=Ground.bank_mesh(serial,g)
 elif serial in Travel.ROTATIONS:
  var name_="Lectern" if serial in [17235,17236] else "Post" if serial==17241 else "Crescent"
  for part in Meadow.source(Travel.KIT):
   if part.name!=name_:continue
   var pose=Transform3D(Basis(Vector3.UP,-PI*.5+Travel.ROTATIONS[serial]),Vector3.ZERO)*part.transform
   model=native_fit(Fit.transformed(part.mesh,pose),serial);break
 elif serial in Parts.Data.PARTS:
  # The city kit measures these exact serials; convert its station anchor and map axes.
  var reference:Rect2=Parts.Data.PARTS[serial][1]
  var shift=Vector2(g.origin[0],g.origin[1])-reference.position
  var u=shift.x/Fit.HORIZONTAL;var v=shift.y/Fit.FLOOR
  var anchor=Vector3((u-v)*.5,0,(u+v)*.5)
  model=Fit.transformed(Parts.prepare(serial),Transform3D(Basis(Vector3.UP,-PI*.5),anchor))
 elif serial in range(11317,11333) or serial in [10466,10467]:model=wall_mesh(serial,g)
 else:
  var family=Forms.kind(serial,false,g)
  if family=="flowers":family="leafy_stems"
  var texture=Art.solid_texture(int(g.page))
  model=Forms.mesh(serial,family,g,texture)
  if family=="snowdrift":
   model=model.duplicate()
   var snow_material=Forms.Source.material(texture).duplicate()
   snow_material.set_shader_parameter("use_base_texture",false)
   snow_material.set_shader_parameter("original_palette",false)
   snow_material.set_shader_parameter("base_color",Color("ccdce4"))
   snow_material.set_shader_parameter("emission_color",Color("ccdce4"))
   snow_material.set_shader_parameter("emission_strength",.28)
   for slot in model.get_surface_count():model.surface_set_material(slot,snow_material)
  # Preserve the established readable prop sizes; full-sprite fitting enlarged
  # small plants and fence posts several times relative to the playable character.
  if family in ["leafy_stems","leafy_shrub","conifer_shrub","flowers","fern","grass"]:
   model=model.duplicate()
   var material=ShaderMaterial.new();material.shader=preload("res://scripts/forest/forest_snow_region_plants.gdshader")
   var native:Dictionary=catalog().graphics[str(serial)]
   material.set_shader_parameter("leaf_color",Color(native.color[0],native.color[1],native.color[2]))
   material.set_shader_parameter("snow_amount",native.snow_fraction)
   material.set_shader_parameter("height",model.get_aabb().end.y)
   for slot in model.get_surface_count():model.surface_set_material(slot,material)
 meshes[serial]=model
 return model

static func wall_mesh(serial:int,g:Dictionary)->Mesh:
 if walls.is_empty():walls=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/university_route/walls.json"))
 var record:Dictionary=walls[str(serial)]
 assert(record.source_rgba_sha256==g.rgba_sha256,"Regenerate route wall contours")
 var axis=Vector3.RIGHT if record.along_x else Vector3.BACK
 var profile=PackedVector2Array();var low=INF
 for pixel in record.outline:
  var across=(float(pixel[0])+float(g.origin[0]))*3/32
  var p=axis*across
  var y=((p.z-p.x)*8-float(pixel[1])-float(g.origin[1]))*.1
  profile.append(Vector2(across,y));low=minf(low,y)
 for i in profile.size():profile[i].y-=low
 var depth=.72;var normal=axis.cross(Vector3.UP)
 var shape=Forms.Shapes.extrude(profile,depth)
 var turn=Basis(Vector3.UP,atan2(-axis.z,axis.x));var origin=-normal*depth*.5
 var hedge=serial in [10466,10467]
 var native=Harbor.skin(g);var edge=Harbor.skin(g) if hedge else Harbor.structure();var arrays=shape.surface_get_arrays(0)
 if hedge:edge.texture=Art.solid_texture(int(g.page))
 for i in arrays[Mesh.ARRAY_VERTEX].size():
  var p:Vector3=turn*arrays[Mesh.ARRAY_VERTEX][i]+origin;var n:Vector3=turn*arrays[Mesh.ARRAY_NORMAL][i]
  if arrays[Mesh.ARRAY_NORMAL][i].z>.9:
   native.projected_vertex(p,n,p+Vector3.UP*low)
  elif hedge:edge.projected_vertex(p,n,p-normal*p.dot(normal)+Vector3.UP*low)
  else:
   var uv=Vector2(p.x,p.z) if absf(n.y)>.5 else Vector2(p.x+p.z,-p.y)
   edge.surface.set_normal(n);edge.surface.set_uv(uv/1.5);edge.surface.set_uv2(edge.tiles.tina_ruin_stone);edge.surface.add_vertex(p)
 return native_fit(Forms.Tina.join(native.finish(),edge.finish(),Transform3D.IDENTITY),serial)

static func guild(root:Node3D,at:Vector3):
 var facade=Civic.build(root,Vector3.ZERO,[1092,"falan_townhouse",0,Vector2.ZERO,Vector3.ONE])
 facade.name="RecoveredUniversityGuild_10604"
 facade.rotation.y=0
 var points:Array[Vector3]=[]
 for p in Fit.node_points(facade):points.append(facade.transform*p)
 var g:Dictionary=catalog().graphics["10604"];var b:Array=g.bounds
 var target=Rect2(float(g.origin[0])+b[0],float(g.origin[1])+b[1],b[2]-b[0],b[3]-b[1])
 var pose=Fit.measure(points,"",Basis(Vector3.UP,PI*.5),target)
 facade.transform=Transform3D(Basis.IDENTITY,at)*pose*facade.transform

static func tree_fit(serial:int)->Transform3D:
 if tree_fits.has(serial):return tree_fits[serial]
 var source=10058 if serial<10074 or serial in range(11600,11622) else 10085 if serial<10088 else 10088
 var rotation_=Basis(Vector3.UP,-PI*.25);var points:Array[Vector3]=[]
 for part in Meadow.source(Meadow.crossgate_tree(source)):
  points.append_array(Fit.mesh_points(part.mesh,Transform3D(rotation_,Vector3.ZERO)*part.transform))
 var g:Dictionary=catalog().graphics[str(serial)];var b:Array=g.bounds
 var target=Rect2(float(g.origin[0])+b[0],float(g.origin[1])+b[1],b[2]-b[0],b[3]-b[1])
 var pose=Fit.measure(points,"",Basis(Vector3.UP,PI*.5),target)
 tree_fits[serial]=pose*Transform3D(rotation_,Vector3.ZERO)
 return tree_fits[serial]

static func build(root:Node3D,source:int,crop_origin:Vector2i,origin:Vector2,size_:Vector2i,bits:PackedByteArray,placements:Array):
 if not catalog().maps.has(str(source)):return
 var groups={};var original=load("res://scripts/forest/forest_original_maps.gd")
 if source in [400,402,4000,4300,4400,15522]:
  var water=original.state(original.runtime_id(source)).duplicate()
  water.raw=water.raw.duplicate()
  for y in size_.y:
   for x in size_.x:
    if not contains(source,Vector2i(x,y)+crop_origin):water.raw.encode_u16(20+(y*size_.x+x)*2,0)
  Ground.water_backing(root,water)
 for row in catalog().maps[str(source)].placements:
  var serial=int(row[2])
  if serial==10604:
   var point:Vector2=original.source_point(original.runtime_id(source),Vector2i(row[0],row[1]))
   guild(root,Vector3(point.x,0,point.y));continue
  if not(serial in range(10050,10100) or serial in range(11600,11625)):continue
  var cell=Vector2i(row[0],row[1])
  if not Rect2i(crop_origin,size_).has_point(cell):continue
  if not groups.has(serial):groups[serial]=[]
  var at:Vector2=original.source_point(original.runtime_id(source),cell)
  var pose=Transform3D(Basis.IDENTITY,Vector3(at.x,0,at.y))
  if serial>=11622:pose.basis=Basis.IDENTITY
  else:pose*=tree_fit(serial)
  if serial<11622:
   pose.basis=Basis.IDENTITY.scaled(Vector3(1,.62,1))*pose.basis
   pose.origin.y*=.62
  groups[serial].append(pose)
 for serial in groups:
  if serial>=11622:
   load("res://scripts/forest/forest_west_route_scenery.gd").batch_saplings(root,serial,groups[serial],true);continue
  var native=10058 if serial<10074 or serial>=11600 else 10085 if serial<10088 else 10088
  var before=root.get_child_count()
  if serial>=11600:
   load("res://scripts/forest/forest_frostpass_art.gd").snowy_grove(root,groups[serial],native,"UniversityRouteSnowTrees")
   for part in root.get_child(root.get_child_count()-1).get_children():
    if part.get_meta("crossgate_tree_part","")=="Canopy":
     part.material_override.set_shader_parameter("snow_amount",.88 if serial>=11609 else .56)
     part.material_override.set_shader_parameter("snow_whiteness",.96 if serial>=11609 else .70)
  else:Meadow.batch(root,Meadow.crossgate_tree(native),groups[serial],true)
  for i in range(before,root.get_child_count()):
   var node=root.get_child(i);node.set_meta("university_route_trees",serial)
   var parts=[node] if node is MultiMeshInstance3D else node.find_children("*","MultiMeshInstance3D",true,false)
   for part in parts:
    # Keep the editable tree's coherent bark/leaf UVs. Projecting one flat sprite
    # onto every leaf made snowy crowns look torn from normal follow cameras.
    if part.get_meta("crossgate_tree_part","")=="Canopy":
     # Owned overrides keep the same anchors/counts and shared master geometry.
     part.material_override=part.material_override.duplicate()
     part.material_override.set_shader_parameter("calm_scenery",true)
     part.material_override.set_shader_parameter("strength",.009)
 if source==4000:
  var cliffs=placements.filter(func(p):return p[4]>=size_.x*size_.y and contains(source,p[5]+crop_origin) and Forms.Cliffs.continuous(int(p[3])))
  var rock=Node3D.new();rock.name="UniversityRouteJenovaCliffs";root.add_child(rock)
  Forms.Cliffs.build(rock,cliffs,size_,bits,origin,source,crop_origin)
  rock.scale.y=1.0/(.045*Fit.VERTICAL)
