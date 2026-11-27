extends SceneTree
## Private source/terrain and actual runtime texture-array inputs, without gameplay enrollment.
const Context=preload("res://scripts/forest/forest_east_source_context_review.gd")
const Town=preload("res://scripts/forest/forest_east_alyut_source_context.gd")
const Art=preload("res://scripts/forest/forest_freyja_art.gd")
const Events=preload("res://scripts/forest/forest_east_events.gd")
const Fresh=preload("res://tests/forest-shrine/east_review_sources.gd")
const OUT=Context.ROOT
var checks=0
var failures=[]
var water_contracts=0
class TownModel:
 extends RefCounted
 var falan_area="alyut"
 var terrain
 var falan_road=""
 var navigation_region:Rect2i
class PreflightOnly:
 extends RefCounted
 static func can_travel(_source:int,_cell:Vector2i,_restore:Dictionary)->bool:return true
func _initialize():call_deferred("run")
func check(okay:bool,label:String):
 checks+=1
 if not okay:failures.append(label);push_error(label)
func image_texture(path:String)->Texture2D:return ImageTexture.create_from_image(Image.load_from_file(path))
func water_contract(terrain,source:int,expected:int):
 var original:Texture2D=terrain.mask_texture();var image:Image=terrain.mask_image();var bytes=image.get_data();var covered=terrain.covered.duplicate();var heights=terrain.heights.to_byte_array();var bounds:Rect2=terrain.mask_bounds()
 var material=ShaderMaterial.new();material.shader=load("res://assets/maps/freyja_west_gate/water.gdshader");material.set_shader_parameter("layout_mask",original);material.set_shader_parameter("bounds",Vector4(bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y)*1.3);material.set_shader_parameter("map_scale",1.3);material.set_shader_parameter("island",true)
 Context.apply_materials(ShaderMaterial.new(),material,terrain)
 var backing:Texture2D=material.get_shader_parameter("layout_mask");var updated:Image=backing.get_meta("source_cpu_image");var cells:Array=backing.get_meta("source_bank_water_cells");var selected={}
 check(backing!=original and cells.size()==expected,"Separate immutable water backing covers original source banks "+str(source))
 for cell:Vector2i in cells:
  selected[cell]=true;check(updated.get_pixelv(cell).r==1. and updated.get_pixelv(cell).a==1.,"Native bank retains visible water behind alpha "+str(Vector3i(source,cell.x,cell.y)))
 for y in image.get_height():
  for x in image.get_width():
   if not selected.has(Vector2i(x,y)):check(image.get_pixel(x,y)==updated.get_pixel(x,y),"Water-only backing preserves every other source pixel "+str(Vector3i(source,x,y)))
 check(image.get_data()==bytes and covered==terrain.covered and heights==terrain.heights.to_byte_array(),"Water material leaves source mask/native coverage/heights immutable "+str(source))
 check(material.get_shader_parameter("island")==false,"Private source water does not invent ocean over void "+str(source))
 if source==2400:check(backing.get_meta("source_water_neighbors").size()==82,"Standalone Town retains all82native water neighbors without joined overlaps")
 Context.apply_materials(ShaderMaterial.new(),material,terrain);check(material.get_shader_parameter("layout_mask")==backing,"Same-source backing setup is idempotent "+str(source))
 water_contracts+=1
func run():
 var paths=["scripts/forest/forest_east_source_context_review.gd","scripts/forest/forest_east_alyut_source_context.gd","scripts/forest/forest_east_il_low_source.gd","scripts/forest/forest_freyja_art.gd","scripts/forest/freyja_surface.gdshaderinc","assets/maps/falan/freyja_ground_atlas.png","assets/maps/falan/freyja_ground_index.png",String(OUT+"alyut2400-data.json").trim_prefix("res://"),String(OUT+"field100-restore.json").trim_prefix("res://"),String(OUT+"100.dat").trim_prefix("res://"),String(OUT+"freyja_ground_atlas.png").trim_prefix("res://"),String(OUT+"freyja_ground_index.png").trim_prefix("res://"),"tests/forest-shrine/east_source_context_input_test.gd"]
 paths.append(String(OUT+"alyut2400-mask.png").trim_prefix("res://"))
 paths.append_array(["scripts/forest/forest_east_il_low_context.gd","build/Other Files/Asset Toolkit/East Gate Region/Il Source Completion/Low Source Candidate/data.json","build/Other Files/Asset Toolkit/East Gate Region/Il Source Completion/Whole Shore Candidate/banks.json","assets/maps/falan/east_region/il_source_completion/mask.png","assets/maps/freyja_west_gate/water.gdshader"])
 var before=Fresh.snapshot(paths);var proposal=Town.data();var model=TownModel.new();Town.configure_model(model)
 Context.host_owner=PreflightOnly
 check(not Context.host_ready() and not Context.can_travel(100,Vector2i(549,43)),"A preflight-only source100 delegate cannot approve a warp before concrete terrain/material/navigation setup")
 Context.host_owner=null
 check(proposal.land_bank_height==6. and proposal.water_height==2.,"Standalone2400 preserves published6m land/2m water datum")
 check(Town.owns(model) and model.terrain.variant=="alyut","One reused source terrain owns standalone2400")
 check(model.terrain.mask_origin()==Vector2(-150,-150) and model.terrain.mask_image().get_size()==Vector2i(100,100),"Private2400 mask and origin use the exact standalone source frame")
 var bits=Marshalls.base64_to_raw(proposal.walk_bits);var center_pass=0;var clear_edges=0;var all_edges=0;var bank_cells={};var void100=0;var emitted=0
 for row:Dictionary in proposal.banks:bank_cells[Vector2i(row.source_cell[0],row.source_cell[1])]=true
 for row:Array in proposal.cells:
  var cell=Vector2i(row[0],row[1]);var at=Town.point(cell)
  if int(row[2])==100:
   void100+=1;check(not row[5] and model.terrain.mask_image().get_pixelv(cell).a==0.,"Closed sourceBG100 has no visible ground or water mask "+str(cell))
   check(model.terrain.height(at.x,at.y)==(6. if int(row[3])>=1000 else 0.),"SourceBG100 only retains the existing6m datum for closed art anchors "+str(cell))
  if int(row[2]) not in [0,100] and int(row[2]) not in range(5000,5009):emitted+=1
  if row[5]:
   var okay=model.terrain.disk_clear(Vector3(at.x,6.,at.y),.60/1.3)
   check(okay,"Native2400 open center has real disc support "+str(cell));center_pass+=int(okay)
  else:
   check(not bool(bits[(cell.y*100+cell.x)>>3]&(1<<((cell.y*100+cell.x)&7))),"Native2400 closed source bit retained "+str(cell))
  if not bank_cells.has(cell):continue
  for step in [Vector2i.UP,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.LEFT]:
   var next=cell+step
   if not Rect2i(0,0,100,100).has_point(next):continue
   var i=next.y*100+next.x
   if not bool(bits[i>>3]&(1<<(i&7))):continue
   all_edges+=1;var okay=true;var end=Town.point(next)
   for index in 21:
    var p=at.lerp(end,index/20.)
    for radius in [.25,.49679,.60]:okay=okay and model.terrain.disk_clear(Vector3(p.x,6.,p.y),radius/1.3)
   check(okay,"Native2400 bank adjacency retains support "+str(cell)+"→"+str(next));clear_edges+=int(okay)
 check(center_pass==4597 and all_edges==351 and clear_edges==351,"All4597 town centers and351 directed bank adjacencies remain supported")
 var mesh_arrays:Array=model.terrain.mesh().get_meta("source_surface_arrays")
 check(void100==4098 and mesh_arrays[Mesh.ARRAY_VERTEX].size()==emitted*6,"Visible mesh emits only source dryBG cells; all4098closedBG100quads are absent")
 water_contract(model.terrain,2400,117)
 var il_terrain=Context.Il.Field.new();il_terrain.setup(Context.Il.data());water_contract(il_terrain,2000,393)
 check(water_contracts==2,"Both actual source-water material contracts completed without an early return")
 var previous={"source":100,"cell":Vector2i(549,43)};var bounds=[549,43,549,43]
 check(not Context.automatic_entered(previous,100,Vector2i(549,43),bounds),"Exact tide arrival held at549,43 does not reenter")
 check(not Context.automatic_entered(previous,100,Vector2i(550,43),bounds),"Leaving the original tide cell does not warp")
 check(Context.automatic_entered({"source":100,"cell":Vector2i(550,43)},100,Vector2i(549,43),bounds),"Returning from outside enters the original tide cell without a nudge")
 for phase in 4:
  check(Events.warp_phase("0|16501|39|34|14||0|0|||||",phase)==(phase!=0),"Actor9 original mask14 phase "+str(phase))
  check(Events.warp_phase("0|16502|39|34|1||0|0|||||",phase)==(phase==0),"Actor10 original mask1 phase "+str(phase))
 var field=Context.field_restore_data();var original=image_texture("res://assets/maps/falan/freyja_ground_atlas.png");var appended=Context.field_ground_atlas()
 var old_array:Texture2DArray=Art.ground_tiles(original);var new_array:Texture2DArray=Art.ground_tiles(appended)
 await process_frame
 await process_frame
 check(old_array.get_layers()==544 and new_array.get_layers()==576,"Runtime tile-array layer IDs are stable despite appended image height")
 var legacy_index=Image.load_from_file("res://assets/maps/falan/freyja_ground_index.png");var slots={}
 for y in legacy_index.get_height():
  for x in legacy_index.get_width():
   var pixel=legacy_index.get_pixel(x,y)
   if pixel.a>.5:slots[roundi(pixel.r*255.)+roundi(pixel.g*255.)*32]=true
 check(slots.size()==532,"The actual legacy index references532 unchanged floor layers")
 var uv_samples=0;var resource_layers=0
 for slot:int in slots:
  var old:Image=old_array.get_layer_data(slot);var current:Image=new_array.get_layer_data(slot)
  if old==null or current==null:
   check(false,"The active renderer cannot read back actual texture-array layer "+str(slot)+"; use the Metal launcher for sampling proof");break
  check(true,"Runtime retains layer data for source slot "+str(slot))
  resource_layers+=1;check(old.get_size()==Vector2i(32,32) and old.get_data()==current.get_data(),"Runtime layer pixels and generated mip chain remain exact "+str(slot))
  for y in [0,1,4,8,16,24,28,30,31]:
   for x in [0,1,4,8,16,24,28,30,31]:
    check(old.get_pixel(x,y)==current.get_pixel(x,y),"Native shader UV-grid sample remainsRGBA exact "+str(Vector3i(slot,x,y)));uv_samples+=1
 var shader=FileAccess.get_file_as_string("res://scripts/forest/freyja_surface.gdshaderinc")
 check(shader.contains("cell.x+cell.y*32.0") and shader.contains("(.5+square*31.0)/32.0"),"Shader uses unchanged layer encoding and per-layer UVs, independent of atlas image height")
 check(field.ground.added[0].graphic==5250 and field.ground.added[0].slot==544,"New native5250 begins beyond every old image row and padding slot")
 check(resource_layers==532 and uv_samples==532*81,"All532actual legacy layers and their43,092native UV-grid samples are checked")
 check(Art.tile_arrays.get(original)==old_array and Art.tile_arrays.get(appended)==new_array,"Legacy and owned private arrays have distinct actual cache keys")
 var old_field=field;var old_town=Town.data();var source_cells=model.terrain.proposal.cells.size()
 Context.reset()
 check(Art.tile_arrays.get(original)==old_array and not Art.tile_arrays.has(appended),"Teardown removes only the owned private atlas cache entry and preserves legacy array identity")
 check(Context.field_textures.is_empty() and Context.restored_field.is_empty() and Context.water_backings.is_empty() and Context.host_owner==null,"Private owner/data/texture/backing caches are released")
 check(not old_field.is_empty() and not old_town.is_empty() and model.terrain.proposal.cells.size()==source_cells,"Teardown releases cache ownership without mutating in-use immutable source dictionaries")
 var changed=Fresh.changed(before);check(changed.is_empty(),"Private input proof sources remained current")
 var report={"checks":checks,"failures":failures,"source_hashes":before,"source_changed_during_run":changed,"source_open_centers":center_pass,"bank_directed_edges":clear_edges,"runtime_legacy_texture_array_layers_checked":resource_layers,"legacy_shader_uv_grid_samples":uv_samples,"scope":"Private source-sized2400 support and runtime ground texture-array/input contracts. No shared flag, gameplay scene, native movement, player/NPC proof or visual acceptance. Exact tide standstill/leave/reenter tests cover the proposed movement-edge predicate; actual transition timing remains pending."}
 var file=FileAccess.open(OUT+"input-contracts.json",FileAccess.WRITE);file.store_string(JSON.stringify(report," "));file.close()
 print("EAST_SOURCE_CONTEXT_INPUT checks=",checks," failures=",failures.size()," town_centers=",center_pass," bank_edges=",clear_edges," texture_layers=",resource_layers," UVsamples=",uv_samples)
 quit(failures.size())
