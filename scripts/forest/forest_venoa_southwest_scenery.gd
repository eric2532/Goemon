extends RefCounted
## Exact southwest source stations; existing nature, shore and native obstacle owners.
const Meadow=preload("res://scripts/forest/forest_wind_meadow_assets.gd")
const Ruby=preload("res://scripts/forest/forest_ruby_region_art.gd")
const Fit=preload("res://scripts/forest/forest_falan_proportions.gd")
const Regions=preload("res://scripts/forest/forest_freyja_regions.gd")
const Scenery=preload("res://scripts/forest/forest_scenery.gd")
static var data:Dictionary={}
static var meshes:Dictionary={}
static var tree_materials:Dictionary={}
static var flower_material:StandardMaterial3D

static func catalog()->Dictionary:
 if data.is_empty():data=JSON.parse_string(FileAccess.get_file_as_string("res://assets/maps/falan/venoa_field/scenery.json"))
 return data

static func tree_blocks(model)->Array:
 var rows=[]
 var frame=Regions.frame("south_lakes").inverse()
 for row in catalog().placements:
  if row.family!="tree":continue
  assert(not row.native_open,"Only source-blocked tree cells may own a trunk obstacle")
  var point:Vector2=frame*(Vector2(row.cell[0],row.cell[1])*3.)
  var box:AABB=Scenery.TREE
  box.position+=Vector3(point.x,model.surface_height(point.x,point.y),point.y)
  rows.append(["venoa_southwest_tree",Transform3D.IDENTITY,box,row.cell,row.serial])
 return rows

static func native_fit(mesh:Mesh,g:Dictionary)->Mesh:
 var b:Array=g.bounds
 var target=Rect2(g.origin[0]+b[0],g.origin[1]+b[1],b[2]-b[0],b[3]-b[1])
 return Fit.transformed(mesh,Fit.measure(Fit.mesh_points(mesh),"",Basis(Vector3.UP,PI*.5),target))

static func flower_mesh(serial:int,g:Dictionary)->Mesh:
 var tool=SurfaceTool.new();tool.begin(Mesh.PRIMITIVE_TRIANGLES)
 for part in Meadow.source(g.asset):
  var arrays:Array=part.mesh.surface_get_arrays(0)
  var colors:PackedColorArray=arrays[Mesh.ARRAY_COLOR]
  var indices:PackedInt32Array=arrays[Mesh.ARRAY_INDEX]
  var normal:Basis=part.transform.basis.inverse().transposed()
  for i in indices:
   var old:Color=colors[i];var leaf=old.g>old.r*1.1 and old.g>old.b*1.1
   var tint:Array=g.green if leaf else g.petals
   var shade=clampf(old.g/.26,.75,1.15)if leaf else .80+maxf(old.r,maxf(old.g,old.b))*.20
   tool.set_color(Color(tint[0]*shade,tint[1]*shade,tint[2]*shade))
   tool.set_normal((normal*arrays[Mesh.ARRAY_NORMAL][i]).normalized())
   tool.add_vertex(part.transform*arrays[Mesh.ARRAY_VERTEX][i])
 var mesh=native_fit(tool.commit(),g)
 if flower_material==null:
  # The existing native bouquet owner uses the same vertex-painted flower forms.
  flower_material=StandardMaterial3D.new();flower_material.vertex_color_use_as_albedo=true
  flower_material.vertex_color_is_srgb=true;flower_material.cull_mode=BaseMaterial3D.CULL_DISABLED;flower_material.roughness=.94
 mesh.surface_set_material(0,flower_material)
 return mesh

static func detail_mesh(serial:int,g:Dictionary)->Mesh:
 if not meshes.has(serial):
  if g.family=="flowers":meshes[serial]=flower_mesh(serial,g)
  else:
   var art=load("res://scripts/forest/forest_original_map_art.gd")
   var forms=load("res://scripts/forest/forest_original_map_solids.gd")
   if g.family=="shore":art.load_east()
   var source:Dictionary=art.data().graphics[str(serial)]
   assert(source.rgba_sha256==g.rgba_sha256,"The reused original prop paint must match the native graphic")
   if g.family=="shore":meshes[serial]=load("res://scripts/forest/forest_tina_ground.gd").bank_mesh(serial,source)
   else:meshes[serial]=native_fit(forms.mesh(serial,"stump",source,art.solid_texture(int(source.page))),g)
 return meshes[serial]

static func batch_tree(root:Node3D,serial:int,g:Dictionary,poses:Array):
 var first=root.get_child_count()
 for i in poses.size():poses[i]*=Ruby.tree_fit(serial)
 Meadow.batch(root,Meadow.crossgate_tree(serial),poses,true)
 for i in range(first,root.get_child_count()):
  var part=root.get_child(i)
  if part.get_meta("crossgate_tree_part","")=="Canopy"and part.material_override is ShaderMaterial:
   if not tree_materials.has(serial):
    var material:ShaderMaterial=part.material_override.duplicate()
    var tint:Array=g.crown_linear_tint
    material.set_shader_parameter("foliage_tint",Vector3(tint[0],tint[1],tint[2]))
    tree_materials[serial]=material
   part.material_override=tree_materials[serial]

static func build(parent:Node3D,model):
 var root=Node3D.new();root.name="VenoaSouthwestSourceScenery";parent.add_child(root)
 var frame=Regions.frame("south_lakes").inverse()
 var groups={}
 var anchors=[]
 for row in catalog().placements:
  var serial=int(row.serial);var cell=Vector2(row.cell[0],row.cell[1]);var point:Vector2=frame*(cell*3.)
  assert(model.terrain.mask_bounds().has_point(point),"A source anchor must remain within its recovered native owner")
  anchors.append([int(cell.x),int(cell.y),serial])
  if not groups.has(serial):groups[serial]=[[],[]]
  var pose=Transform3D(Basis.IDENTITY,Vector3(point.x,model.surface_height(point.x,point.y),point.y))
  if row.family=="shore":
   # Reuse the native cap/descending-face form between the preserved land and water.
   # This visual fit neither raises the terrain nor supplies collision/support.
   var top:float=maxf(model.terrain.WATER_HEIGHT+2.10,pose.origin.y)
   for offset in [Vector2(-1.5,-1.5),Vector2(1.5,-1.5),Vector2(-1.5,1.5),Vector2(1.5,1.5)]:
    top=maxf(top,model.surface_height(point.x+offset.x,point.y+offset.y))
   pose.origin.y=top+.035
   pose.basis=Basis.IDENTITY.scaled(Vector3(1,(pose.origin.y-model.terrain.WATER_HEIGHT)/2.10,1))
  groups[serial][0].append(pose)
  groups[serial][1].append(row.cell)
 for serial in groups:
  var g:Dictionary=catalog().graphics[str(serial)];var poses:Array=groups[serial][0]
  var first=root.get_child_count()
  if g.family=="tree":
   batch_tree(root,serial,g,poses)
  else:
   var part=MultiMeshInstance3D.new();part.name="NativeSouthwest_"+str(serial)
   part.multimesh=MultiMesh.new();part.multimesh.transform_format=MultiMesh.TRANSFORM_3D
   part.multimesh.mesh=detail_mesh(serial,g);part.multimesh.instance_count=poses.size()
   for i in poses.size():part.multimesh.set_instance_transform(i,poses[i])
   part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if g.family=="flowers"else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
   root.add_child(part)
  for i in range(first,root.get_child_count()):
   root.get_child(i).set_meta("venoa_southwest_serial",serial)
   root.get_child(i).set_meta("venoa_southwest_cells",groups[serial][1])
 root.set_meta("venoa_southwest_anchors",anchors)
 root.set_meta("venoa_southwest_counts",catalog().counts)
 # Source water props remain beyond the land mask; they add no support/collision.
 var offshore=Node3D.new();offshore.name="OriginalWaterFlowers";root.add_child(offshore)
 var water_anchors=[]
 for row in catalog().get("offshore_placements",[]):
  var serial=int(row.serial);var cell=Vector2(row.cell[0],row.cell[1]);var point:Vector2=frame*(cell*3.)
  var first=offshore.get_child_count();var g:Dictionary=catalog().graphics[str(serial)]
  var pose=Transform3D(Basis.IDENTITY,Vector3(point.x,model.terrain.WATER_HEIGHT,point.y))
  if row.family=="tree":batch_tree(offshore,serial,g,[pose])
  else:
   var part=MultiMeshInstance3D.new();part.name=("NativeWaterFlower_"if row.family=="flowers"else"NativeWaterProp_")+str(serial)
   part.multimesh=MultiMesh.new();part.multimesh.transform_format=MultiMesh.TRANSFORM_3D
   part.multimesh.mesh=detail_mesh(serial,g);part.multimesh.instance_count=1
   part.multimesh.set_instance_transform(0,pose)
   part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
   offshore.add_child(part)
  for i in range(first,offshore.get_child_count()):
   var part=offshore.get_child(i)
   part.set_meta("source_cell",row.cell);part.set_meta("source_serial",serial)
  water_anchors.append([int(cell.x),int(cell.y),serial])
 offshore.set_meta("source_anchors",water_anchors)
