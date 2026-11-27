extends RefCounted
## One process-only dispatcher, activated solely by Regions.private_source_context.
const Il=preload("res://scripts/forest/forest_east_il_low_context.gd")
const Alyut=preload("res://scripts/forest/forest_east_alyut_source_context.gd")
const ROOT="res://build/Other Files/Asset Toolkit/East Gate Region/Village Props/Cliff Audit/Source Context Audit/Prototype/"
static var host_owner:Script
static var restored_field:Dictionary={}
static var field_textures:Dictionary={}
static var water_backings:Dictionary={}
static var host_readiness:Dictionary={}
static func host_ready()->bool:
 if host_owner==null:return false
 var key=[host_owner,str(field_restore_data().raw_sha256)]
 if host_readiness.has(key):return host_readiness[key]
 var methods={}
 for method:Dictionary in host_owner.get_script_method_list():methods[str(method.name)]=true
 for name_ in ["ready","configure_model","add_navigation","build","prepare_world","can_travel","apply_materials","scene_handoff","reset"]:
  if not methods.has(name_):host_readiness[key]=false;return false
 host_readiness[key]=host_owner.ready(field_restore_data());return host_readiness[key]
static func reset():
 var owned_atlas:Texture2D=field_textures.get("freyja_ground_atlas.png")
 if owned_atlas!=null:load("res://scripts/forest/forest_freyja_art.gd").tile_arrays.erase(owned_atlas)
 if host_owner!=null:
  for method:Dictionary in host_owner.get_script_method_list():
   if str(method.name)=="reset":host_owner.reset();break
 host_owner=null;restored_field={};field_textures.clear();water_backings.clear();host_readiness.clear();Il.manifest={};Il.shore={};Alyut.manifest={}
static func field_restore_data()->Dictionary:
 if restored_field.is_empty():restored_field=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"field100-restore.json"))
 return restored_field
static func field_texture(name_:String)->Texture2D:
 if not field_textures.has(name_):
  var image=Image.load_from_file(ROOT+name_);var texture=ImageTexture.create_from_image(image);texture.set_meta("source_cpu_image",image);field_textures[name_]=texture
 return field_textures[name_]
static func field_ground_index()->Texture2D:return field_texture("freyja_ground_index.png")
static func field_ground_atlas()->Texture2D:return field_texture("freyja_ground_atlas.png")
static func image_sha(image:Image)->String:
 var hash_=HashingContext.new();hash_.start(HashingContext.HASH_SHA256);hash_.update(image.get_data());return hash_.finish().hex_encode()
static func bank_rows(source:int)->Array:
 if source==2400:return Alyut.data().banks
 if Il.shore.is_empty():Il.shore=JSON.parse_string(FileAccess.get_file_as_string(Il.ROOT+"Whole Shore Candidate/banks.json"))
 return Il.shore.rows
static func water_backing(source:int,terrain,original:Texture2D,bounds:Vector4,scale_:float)->Texture2D:
 var image:Image=original.get_meta("source_cpu_image") if original.has_meta("source_cpu_image") else original.get_image()
 var digest=image_sha(image);var key=[source,digest,bounds,scale_]
 if water_backings.has(key):return water_backings[key]
 var proposal:Dictionary=Alyut.data() if source==2400 else Il.data();var size_=Vector2i(proposal.size[0],proposal.size[1]);var cloned=image.duplicate();var cells=[];var bank_cells={}
 var rect=Rect2(bounds.x,bounds.y,bounds.z,bounds.w);var source_cells:Array=proposal.cells
 for row:Dictionary in bank_rows(source):
  var cell=Vector2i(row.source_cell[0],row.source_cell[1]);var raw:Array=source_cells[cell.y*size_.x+cell.x]
  assert(int(raw[2]) in range(5000,5009),"Only original source-water bank backgrounds receive a water backing")
  var at=source_point(source,cell);var pixel=Vector2i((((at*scale_-rect.position)/rect.size)*Vector2(image.get_size())).floor())
  assert(Rect2i(Vector2i.ZERO,image.get_size()).has_point(pixel),"Source bank backing stays in the existing water material frame")
  var color=cloned.get_pixelv(pixel);color.r=1.;color.a=1.;cloned.set_pixelv(pixel,color);cells.append(pixel);bank_cells[cell]=true
 assert(cells.size()==(117 if source==2400 else 393),"Every original native bank retains source-water behind its alpha")
 var neighbors={}
 if source==2400:
  for cell:Vector2i in bank_cells:
   for dy in [-1,0,1]:
    for dx in [-1,0,1]:
     var other=cell+Vector2i(dx,dy)
     if not Rect2i(Vector2i.ZERO,size_).has_point(other) or bank_cells.has(other):continue
     var raw:Array=source_cells[other.y*size_.x+other.x]
     if int(raw[2]) not in range(5000,5009):continue
     assert(not raw[5],"Standalone town-water ring cannot contain an original-open route")
     var at=source_point(source,other);var pixel=Vector2i((((at*scale_-rect.position)/rect.size)*Vector2(image.get_size())).floor())
     assert(cloned.get_pixelv(pixel).r>.5 and cloned.get_pixelv(pixel).a>.5,"All original town-water neighbors stay visible, including the six separate field overlaps")
     neighbors[other]=true
  assert(neighbors.size()==82,"Standalone town uses all82 native adjacent water cells")
 assert(image_sha(image)==digest,"The original source/ground mask is immutable")
 var texture=ImageTexture.create_from_image(cloned);texture.set_meta("source_cpu_image",cloned);texture.set_meta("original_mask_sha256",digest);texture.set_meta("source_bank_water_cells",cells);texture.set_meta("source_water_neighbors",neighbors.keys());texture.set_meta("source_map",source)
 water_backings[key]=texture;return texture
static func apply_materials(_ground:ShaderMaterial,water:ShaderMaterial,terrain):
 if host(terrain.variant):
  if host_owner!=null and host_owner.has_method("apply_materials"):host_owner.apply_materials(_ground,water,terrain)
  return
 if not standalone(terrain.variant):return
 var source=2000 if terrain.variant=="il_village" else 2400
 if int(water.get_meta("source_private_water_map",-1))==source:return
 var original:Texture2D=water.get_shader_parameter("layout_mask")
 water.set_shader_parameter("layout_mask",water_backing(source,terrain,original,water.get_shader_parameter("bounds"),float(water.get_shader_parameter("map_scale"))))
 water.set_shader_parameter("island",false);water.set_meta("source_private_water_map",source)
static func standalone(area:String)->bool:return area in ["il_village","alyut"]
static func host(area:String)->bool:return area in ["east_gate","north_coast"]
static func suppress_joined(area:String)->bool:return host(area)
static func owns(model)->bool:return Il.owns(model) or Alyut.owns(model)
static func suppress_entry_chests(model)->bool:return owns(model)
static func source_id(model)->int:return 2000 if model.falan_area=="il_village" else 2400 if model.falan_area=="alyut" else 100 if host(model.falan_area) else -1
static func source_point(source:int,cell:Vector2i)->Vector2:return Il.point(cell) if source==2000 else Alyut.point(cell)
static func can_travel(source:int,cell:Vector2i)->bool:
 if source==2000:return Il.can_travel(cell)
 if source==2400:return Alyut.Full.source_open(cell)
 return host_ready() and host_owner.can_travel(source,cell,field_restore_data())
static func layout(source:int,cell:Vector2i)->Dictionary:
 var regions=load("res://scripts/forest/forest_freyja_regions.gd")
 return regions.layout("il_village" if source==2000 else "alyut" if source==2400 else load("res://scripts/forest/forest_east_region.gd").source_area(100,cell))
static func arrival_yaw(game,source:int)->float:return Il.arrival_yaw(game,source) if source==2000 or source==100 and Il.owns(game.model) else game.camera_rig.yaw
static func configure_model(model):
 if model.falan_area=="il_village":Il.configure_model(model)
 elif model.falan_area=="alyut":Alyut.configure_model(model)
 elif host(model.falan_area):
  assert(host_ready(),"Private source100 terrain/material/navigation products must be prepared before entering its scene")
  host_owner.configure_model(model,field_restore_data())
static func add_navigation(nav:Dictionary,model):
 if Il.owns(model):Il.add_navigation(nav,model)
 elif Alyut.owns(model):Alyut.add_navigation(nav,model)
 elif host(model.falan_area) and host_owner!=null:host_owner.add_navigation(nav,model)
static func build_banks(root:Node3D,model):
 if Il.owns(model):Il.build_banks(root,model)
 elif Alyut.owns(model):Alyut.build_banks(root,model)
static func build_host(root:Node3D,model):
 if host(model.falan_area) and host_owner!=null:host_owner.build(root,model)
static func prepare_world(world,player):
 if Il.owns(world.model):Il.prepare_world(world,player)
 elif Alyut.owns(world.model):Alyut.prepare_world(world,player)
 elif host(world.model.falan_area) and host_owner!=null:host_owner.prepare_world(world,player)
static func scene_handoff(game,before:Vector2,at:Vector2)->Dictionary:
 if not host(game.model.falan_area) or not host_ready() or not host_owner.owns(game.model):return {}
 var collider:CollisionShape3D=game.player.body_shape
 var radius=0.
 if collider.shape is CapsuleShape3D:
  radius=collider.shape.radius*maxf(collider.global_basis.x.length(),collider.global_basis.z.length())
 elif collider.shape is BoxShape3D:
  radius=Vector2(collider.shape.size.x*collider.global_basis.x.length(),collider.shape.size.z*collider.global_basis.z.length()).length()*.5
 else:return {}
 # Only the actual player initiates a scene handoff. Existing Tour owns followers;
 # their actual native edge/movement proof remains a separate required contract.
 return host_owner.scene_handoff(game.model,before,at,radius/game.model.falan_scale)
static func links_model(model)->Array:
 var source=source_id(model)
 if source<0:return []
 return load("res://scripts/forest/forest_east_region.gd").links_source(source,model.seed_value,model.falan_area if source==100 else "")
static func merge_links(model,legacy:Array)->Array:
 if owns(model):return legacy.filter(func(link):return link.to not in ["freyja_door","freyja_return","freyja_outside","city","castle","interior"])
 return legacy
static func npc_sources(model)->Array:
 var source=source_id(model);return [source] if source>0 else []
static func arrived(game):
 var source=source_id(game.model)
 if source!=100:return
 var context={};load("res://scripts/forest/forest_east_events.gd").source_context(game,context,100)
 game.set_meta("east_private_auto_position",{"source":100,"cell":context.cell})
static func automatic_previous(game,source:int,cell:Vector2i)->Dictionary:
 var previous:Dictionary=game.get_meta("east_private_auto_position",{"source":source,"cell":cell})
 game.set_meta("east_private_auto_position",{"source":source,"cell":cell});return previous
static func automatic_entered(previous:Dictionary,source:int,cell:Vector2i,bounds:Array)->bool:
 var rect=Rect2i(bounds[0],bounds[1],bounds[2]-bounds[0]+1,bounds[3]-bounds[1]+1)
 return int(previous.get("source",source))==source and rect.has_point(cell) and not rect.has_point(previous.get("cell",cell))
