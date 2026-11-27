extends RefCounted
## Static bridge geometry and one world-space water surface for the Freyja test.
const Terrain=preload("res://scripts/forest/forest_freyja_terrain.gd")
const Fort=preload("res://scripts/forest/forest_stone_fort.gd")
const Frontier=preload("res://scripts/forest/forest_falan_frontier.gd")
const Art=preload("res://scripts/forest/forest_art.gd")
const ARCHIVE_AREAS=["freyja","west_lakes","east_gate","south_gate","east_coast","north_coast","south_lakes","sokia_coast","sokia_desert","ghana_road","ghana_north_road","kili","venoa","il_village","laruka","alyut","ghana"]

static var tile_arrays:Dictionary={}

static func ground_tiles(atlas:Texture2D)->Texture2DArray:
 if tile_arrays.has(atlas):return tile_arrays[atlas]
 # Filter each recovered tile separately so distant mip levels cannot mix adjacent artwork.
 var image=atlas.get_image()
 assert(image.get_width()==32*36 and image.get_height()%36==0)
 var images:Array[Image]=[]
 for y in image.get_height()/36:
  for x in 32:
   var tile=image.get_region(Rect2i(x*36+2,y*36+2,32,32))
   tile.generate_mipmaps();images.append(tile)
 var texture=Texture2DArray.new()
 var error=texture.create_from_images(images)
 assert(error==OK,"Cannot prepare the recovered ground tiles")
 tile_arrays[atlas]=texture
 return texture

static func build(root:Node3D,ground:ShaderMaterial,terrain,map_scale:float,city_defenses:bool=true):
 var bounds:Rect2=terrain.mask_bounds()
 var mask:Texture2D=terrain.mask_texture()
 var exterior:Dictionary=Frontier.Gates.EXTERIORS.get(terrain.variant,{})
 var bounds_uniform=Vector4(bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y)
 ground.set_shader_parameter("detail_mask",mask)
 ground.set_shader_parameter("detail_bounds",bounds_uniform)
 ground.set_shader_parameter("clip_archive_land",Frontier.FRAMES.has(terrain.variant) or Terrain.Sokia.owns(terrain.variant))
 preload("res://scripts/forest/forest_freyja_residual_art.gd").clipping(ground,terrain,false)
 Terrain.Sokia.northeast_clip_material(ground,terrain,true)
 if terrain.variant in ARCHIVE_AREAS:archive_surface(ground,terrain)
 if terrain.variant in ["freyja","west_lakes"]:ground.set_shader_parameter("archive_floor_weight",1.0)
 if terrain.variant=="east_gate":
  var plot=Terrain.Regions.TOMATO_PLOT
  ground.set_shader_parameter("tomato_plot",Vector4(plot.position.x,plot.position.y,plot.end.x,plot.end.y))
 if terrain.variant=="castle":
  ground.set_shader_parameter("use_courtyard_paving",true)
  var courtyard_sampler="city_paving_atlas" if RenderingServer.get_current_rendering_method()=="gl_compatibility" else "courtyard_paving"
  ground.set_shader_parameter(courtyard_sampler,preload("res://assets/maps/falan/castle_courtyard_paving.png"))
 elif terrain.variant=="city" or Frontier.FRAMES.has(terrain.variant):
  ground.set_shader_parameter("use_city_paving",true)
  if terrain.variant!="city":
   var frame:Transform2D=Frontier.FRAMES[terrain.variant]
   ground.set_shader_parameter("city_gate_frame",Vector4(frame.origin.x,frame.origin.y,frame.x.x,frame.x.y))
   ground.set_shader_parameter("city_gate_paving_end",terrain.bridge_bounds().position.y-9.0)
  var city_mask:Texture2D=Terrain.SURFACES.city[0]
  ground.set_shader_parameter("city_paving_bounds",Vector4(-403.5,-439.5,city_mask.get_width()*3.0,city_mask.get_height()*3.0))
  ground.set_shader_parameter("city_paving_index",load("res://assets/maps/falan/city_paving_index.png"))
  ground.set_shader_parameter("city_paving_atlas",load("res://assets/maps/falan/city_paving_atlas.png"))
 if terrain.variant in Terrain.Regions.TOMATO_LAND:
  ground.set_shader_parameter("use_mountain_surface",true)
  return
 var water=PlaneMesh.new()
 var extend_shore=(not exterior.is_empty() or Terrain.Regions.Data.RIDGES.has(terrain.variant)) and terrain.variant not in ARCHIVE_AREAS
 var island=terrain.variant in ["castle","il_village","laruka","alyut"]
 water.size=Vector2.ONE*3400.0 if island or extend_shore else bounds.size
 var water_material=ShaderMaterial.new()
 water_material.shader=preload("res://assets/maps/freyja_west_gate/water.gdshader")
 var city_fort=load("res://scripts/forest/forest_falan_fortifications.gd") if terrain.variant=="city" else null
 var river_bridge:Rect2=terrain.il_bridge_bounds()
 var water_mask=mask
 var water_bounds=bounds
 if Terrain.Sokia.owns(terrain.variant) or terrain.variant=="ghana":
  water_mask=load("res://assets/maps/falan/sokia/scenery/ghana-water.png") if terrain.variant=="ghana" else Terrain.Sokia.WATER
  var zero:Vector2=Terrain.Regions.Sites.VILLAGES.ghana[2]-Vector2.ONE*1.5 if terrain.variant=="ghana" else Terrain.Regions.frame(terrain.variant).inverse()*Vector2(-1.5,-1.5)
  water_bounds=Rect2(zero,water_mask.get_size()*3.)
  water.size=water_bounds.size
  ground.set_shader_parameter("use_native_land_visibility",true)
  ground.set_shader_parameter("native_land_visibility",water_mask)
  ground.set_shader_parameter("native_visibility_bounds",Vector4(water_bounds.position.x,water_bounds.position.y,water_bounds.size.x,water_bounds.size.y))
 elif terrain.variant=="south_lakes":
  # Blank source cells get an ocean backdrop only; native ground/support stay local.
  water_mask=Terrain.VenoaField.OCEAN_BACKDROP
  var source_zero:Vector2=Terrain.Regions.frame(terrain.variant).inverse()*Vector2(-1.5,-1.5)
  water_bounds=Rect2(source_zero,water_mask.get_size()*3.)
  water.size=water_bounds.size
  ground.set_shader_parameter("use_native_land_visibility",true)
  ground.set_shader_parameter("native_land_visibility",Terrain.VenoaField.VISIBILITY)
  ground.set_shader_parameter("native_visibility_bounds",bounds_uniform)
 else:
  ground.set_shader_parameter("use_native_land_visibility",false)
 if city_fort:water_mask=city_fort.water_mask(mask,bounds.position+Vector2.ONE*1.5)
 elif river_bridge.has_area():
  water_mask=preload("res://scripts/forest/forest_falan_fortifications.gd").water_mask(mask,terrain.mask_origin(),[river_bridge])
 water_material.set_shader_parameter("layout_mask",water_mask)
 water_material.set_shader_parameter("bounds",Vector4(water_bounds.position.x,water_bounds.position.y,water_bounds.size.x,water_bounds.size.y)*map_scale)
 water_material.set_shader_parameter("island",island)
 water_material.set_shader_parameter("extend_shore",extend_shore)
 if terrain.variant in ARCHIVE_AREAS:
  archive_surface(water_material,terrain)
  if terrain.variant=="south_lakes":water_material.set_shader_parameter("freyja_ground_index",load(Terrain.VenoaField.OCEAN_INDEX_PATH))
  water_material.set_shader_parameter("map_scale",map_scale)
 if terrain.variant in ["alyut","north_coast"]:
  var complete=load("res://scripts/forest/forest_east_alyut_source_completion.gd")
  if complete.enabled():complete.apply_materials(ground,water_material,terrain)
 if Terrain.Regions.private_source_context!=null:
  if Terrain.Regions.private_source_context.standalone(terrain.variant):water.size=bounds.size
  Terrain.Regions.private_source_context.apply_materials(ground,water_material,terrain)
 var center=bounds.get_center()
 var water_center=water_bounds.get_center()
 var surface=Geo.mesh(root,water,Vector3(water_center.x,Terrain.WATER_HEIGHT,water_center.y),water_material)
 surface.name="FreyjaWater"
 surface.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 var support_size:Vector2=bounds.size if Terrain.Sokia.owns(terrain.variant) or terrain.variant=="south_lakes" else water.size
 var river_ground=Art.solid(root,Vector3(center.x,Terrain.WATER_HEIGHT-.10,center.y),
  Vector3(support_size.x,.20,support_size.y),1,"stone")
 river_ground.name="WaterWalkingGround"
 if terrain.bridge_bounds().has_area():
  bridge(root,terrain.bridge_bounds(),exterior)
 if river_bridge.has_area():il_bridge(root,ground,terrain)
 if city_fort:
  var pond=PlaneMesh.new()
  pond.size=Terrain.CITY_POND.size
  var pond_center=Terrain.CITY_POND.get_center()
  var pond_surface=Geo.mesh(root,pond,Vector3(pond_center.x,Terrain.CITY_POND_WATER,pond_center.y),water_material)
  pond_surface.name="FalanLilyPond"
  pond_surface.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  Art.solid(root,Vector3(pond_center.x,Terrain.CITY_POND_WATER-.10,pond_center.y),
   Vector3(Terrain.CITY_POND.size.x,.20,Terrain.CITY_POND.size.y),1,"stone").name="PondWalkingGround"
  if city_defenses:city_fort.build(root,ground)

static func archive_surface(material:ShaderMaterial,terrain):
 if Terrain.Regions.CONNECTED_VILLAGES.has(terrain.variant) and (Terrain.Regions.private_source_context==null or not Terrain.Regions.private_source_context.suppress_joined(terrain.variant)):
  var village:String=Terrain.Regions.CONNECTED_VILLAGES[terrain.variant]
  var local=Transform2D(0.0,-Terrain.Regions.Sites.VILLAGES[village][2])*Terrain.Regions.village_transform(village).inverse()
  var grass:Vector2=(Frontier.Il if village=="il_village" else Frontier.Alyut).GRASS_TILE
  material.set_shader_parameter("use_connected_village",true)
  material.set_shader_parameter("connected_village_frame",Vector4(local.origin.x,local.origin.y,local.x.x,local.x.y))
  material.set_shader_parameter("connected_village_mask",Terrain.Regions.village_mask(village))
  material.set_shader_parameter("connected_village_index",Terrain.Regions.village_ground_index(village))
  material.set_shader_parameter("connected_village_atlas",ground_tiles(Terrain.Regions.village_ground_atlas(village)))
  material.set_shader_parameter("connected_village_grass",Vector4(grass.x/255.0,grass.y/255.0,0,1))
 var frame:Transform2D=Transform2D(0.0,-Terrain.Regions.Sites.VILLAGES[terrain.variant][2]) if terrain.variant in ["kili","venoa","il_village","laruka","alyut","ghana"] else Terrain.Regions.frame(terrain.variant)
 material.set_shader_parameter("use_freyja_surface",true)
 if terrain.variant in ["east_gate","east_coast","north_coast"]:
  # Original Freyja grass graphic 5045 fills blank land in both gameplay and village views.
  material.set_shader_parameter("freyja_grass_tile",Vector4(0,2.0/255.0,0,1))
 material.set_shader_parameter("freyja_frame",Vector4(frame.origin.x,frame.origin.y,frame.x.x,frame.x.y))
 var sokia=Terrain.Sokia.owns(terrain.variant)
 material.set_shader_parameter("freyja_ground_index",preload("res://assets/maps/falan/sokia_ground_index.png")
  if sokia else preload("res://assets/maps/falan/freyja_ground_index.png"))
 material.set_shader_parameter("freyja_ground_atlas",ground_tiles(preload("res://assets/maps/falan/sokia_ground_atlas.png")
  if sokia else preload("res://assets/maps/falan/freyja_ground_atlas.png")))
 if Terrain.Regions.private_source_context!=null and Terrain.Regions.private_source_context.host(terrain.variant):
  material.set_shader_parameter("freyja_ground_index",Terrain.Regions.private_source_context.field_ground_index())
  material.set_shader_parameter("freyja_ground_atlas",ground_tiles(Terrain.Regions.private_source_context.field_ground_atlas()))
 if terrain.variant in ["kili","venoa","il_village","alyut","ghana"]:
  material.set_shader_parameter("freyja_ground_index",Terrain.Regions.village_ground_index(terrain.variant))
  material.set_shader_parameter("freyja_ground_atlas",ground_tiles(Terrain.Regions.village_ground_atlas(terrain.variant)))
 if terrain.variant=="laruka":
  material.set_shader_parameter("freyja_ground_index",preload("res://assets/maps/falan/il_laruka/laruka_ground_index.png"))
  material.set_shader_parameter("freyja_ground_atlas",ground_tiles(preload("res://assets/maps/falan/il_laruka/laruka_ground_atlas.png")))
 if terrain.bridge_bounds().has_area():
  material.set_shader_parameter("freyja_surface_start",terrain.bridge_bounds().end.y)

static func il_bridge(root:Node3D,ground:ShaderMaterial,terrain):
 var source:Rect2=Terrain.IL_BRIDGE_SOURCE
 var local=Terrain.Regions.frame(terrain.variant).inverse()
 var deck=SurfaceTool.new()
 deck.begin(Mesh.PRIMITIVE_TRIANGLES)
 for z in 3:
  for x in 7:
   for corner:Vector2 in [Vector2.ZERO,Vector2.RIGHT,Vector2.DOWN,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]:
    # Overlap the adjacent terrain triangles beneath the original grass approach.
    var at=local*(source.position-Vector2(1.5,0)+(Vector2(x,z)+corner)*3.0)
    deck.set_normal(Vector3.UP)
    deck.add_vertex(Vector3(at.x,terrain.height(at.x,at.y)+.015,at.y))
 var span=Node3D.new()
 span.name="IlRiverBridge"
 root.add_child(span)
 Geo.mesh(span,deck.commit(),Vector3.ZERO,ground,true).name="ArchivedGrassDeck"
 var center:Vector2=local*source.get_center()
 var along:Vector2=local.basis_xform(Vector2.RIGHT)
 var arch=Geo.mesh(span,arch_mesh(source.size.y),Vector3(center.x,terrain.height(center.x,center.y)-5.25,center.y),
  Fort.material(Color("b9b59a")))
 arch.name="OriginalSingleArch"
 arch.rotation.y=atan2(along.x,along.y)
 arch.scale.z=source.size.x/12.0

static func bridge(root:Node3D,b:Rect2,exterior:Dictionary):
 var deck_y=Terrain.BANK_HEIGHT
 var center=b.get_center()
 var stone=Fort.material(Color("9caa9c"))
 var coping=Fort.material(Color("b3baa5"),false)
 var flagstones=Fort.material(Color("9ea797"),false).duplicate()
 flagstones.set_shader_parameter("use_castle_stone",true)
 flagstones.set_shader_parameter("castle_stone_texture",preload("res://assets/models/environments/wind_meadow/buildings/wall_section_architecture_paint.png"))
 var bridge_root=Node3D.new()
 bridge_root.name="FreyjaStoneBridge"
 root.add_child(bridge_root)
 Geo.box(bridge_root,Vector3(center.x,deck_y-.38,center.y),Vector3(b.size.x,.76,b.size.y),flagstones)
 Art.solid(bridge_root,Vector3(center.x,deck_y-.38,center.y),Vector3(b.size.x,.76,b.size.y),1,"stone")
 var arch_count=roundi(b.size.y/12.0)
 var span=b.size.y/arch_count
 var arch=arch_mesh(b.size.x)
 for i in arch_count:
  var unit=Geo.mesh(bridge_root,arch,Vector3(center.x,0,b.position.y+span*(i+.5)),stone)
  unit.scale.z=span/12.0
 var teeth=preload("res://scripts/forest/forest_static_boxes.gd").new()
 for x in [b.position.x-.6,b.end.x+.6]:
  var rail_center=Vector3(x,deck_y+.6,center.y)
  var rail_size=Vector3(1.2,1.2,b.size.y)
  Geo.box(bridge_root,rail_center,rail_size,stone)
  Art.solid(bridge_root,rail_center,rail_size,1,"stone")
  Geo.box(bridge_root,rail_center+Vector3.UP*.7,Vector3(1.45,.23,b.size.y),coping)
  if exterior.is_empty():
   for i in int(b.size.y/4.0):
    var pos=Vector3(x,deck_y+1.65,b.position.y+2.0+i*4.0)
    teeth.add(pos,Vector3(1.3,.8,1.55),coping)
 if not exterior.is_empty():
  for at:Vector2 in exterior.posts:
   var p=Vector3(at.x+(-.6 if at.x<center.x else .6),deck_y,at.y)
   teeth.add(p+Vector3.UP*.89,Vector3(2.12,1.78,2.12),stone)
   for i in 4:
    var width=2.21-i*.43
    teeth.add(p+Vector3.UP*(1.84+i*.22),Vector3(width,.22,width),coping)
  var lamps=[]
  for at:Vector2 in exterior.lamps:
   # Keep the original lamp stations clear of the walk-through center lane.
   var x=b.position.x+.95 if at.y<center.y else b.end.x-.95
   lamps.append(Transform3D(Basis.IDENTITY,Vector3(x,deck_y,at.y)))
  preload("res://scripts/forest/forest_falan_lamps.gd").batch(bridge_root,10424,lamps)
 teeth.build(bridge_root)

static func arch_mesh(width:float,rim:Material=null)->ArrayMesh:
 var profile=PackedVector2Array([Vector2(-6,0)])
 for i in 13:
  var theta=PI*float(i)/12.0
  profile.append(Vector2(-4.75*cos(theta),4.75*sin(theta)))
 profile.append(Vector2(6,0))
 var mesh=SurfaceTool.new()
 mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
 mesh.set_smooth_group(-1)
 var half=width*.5
 for i in profile.size()-1:
  var a=profile[i]
  var b=profile[i+1]
  var left_a=Vector3(-half,a.y,a.x)
  var left_b=Vector3(-half,b.y,b.x)
  var right_a=Vector3(half,a.y,a.x)
  var right_b=Vector3(half,b.y,b.x)
  quad(mesh,left_a,left_b,Vector3(-half,5.25,b.x),Vector3(-half,5.25,a.x))
  quad(mesh,right_b,right_a,Vector3(half,5.25,a.x),Vector3(half,5.25,b.x))
  quad(mesh,left_b,left_a,right_a,right_b)
 mesh.generate_normals()
 var result=mesh.commit()
 if rim!=null:
  mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
  mesh.set_smooth_group(-1)
  mesh.set_material(rim)
  for i in range(1,13):
   var a=profile[i]
   var b=profile[i+1]
   var outer_a=a*1.11
   var outer_b=b*1.11
   quad(mesh,Vector3(-half-.035,a.y,a.x),Vector3(-half-.035,b.y,b.x),Vector3(-half-.035,outer_b.y,outer_b.x),Vector3(-half-.035,outer_a.y,outer_a.x))
   quad(mesh,Vector3(half+.035,b.y,b.x),Vector3(half+.035,a.y,a.x),Vector3(half+.035,outer_a.y,outer_a.x),Vector3(half+.035,outer_b.y,outer_b.x))
  mesh.generate_normals()
  mesh.commit(result)
 return result

static func quad(mesh:SurfaceTool,a:Vector3,b:Vector3,c:Vector3,d:Vector3):
 for p in [a,c,b,a,d,c]:mesh.add_vertex(p)
