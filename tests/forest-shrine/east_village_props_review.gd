extends "res://tests/forest-shrine/il_chief_review.gd"
## Native prop coverage plus the actual village owner from connected gameplay-camera corners.
const Props=preload("res://scripts/forest/forest_east_village_props.gd")
const PROP_OUT="res://build/Other Files/Asset Toolkit/East Gate Region/Village Props/"
var review_area="il_village"
var mesh_audit=[]

func run():
 root.size=Vector2i(1440,900);phase="VillageProps"
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PROP_OUT))
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW+phase))
 for key in Props.data().graphics:
  var serial=int(key);var g:Dictionary=Props.data().graphics[key]
  if g.mode=="flowering_tree":
   check(not g.crowns.is_empty(),"Native flowering tree retains its measured individual crowns: "+key);continue
  var mesh:Mesh=Props.mesh(serial)
  check(mesh!=null and mesh.get_surface_count()>0 and mesh.get_aabb().size.length()>0,"Every native Il/Alyut prop resolves a prepared visual: "+key)
  var triangles=0
  for surface in mesh.get_surface_count():
   var arrays=mesh.surface_get_arrays(surface);var indices=arrays[Mesh.ARRAY_INDEX]
   triangles+=(indices.size() if indices is PackedInt32Array and not indices.is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
  mesh_audit.append({"graphic":serial,"mode":g.mode,"source_bounds":g.bounds,"source_footprint":g.footprint,"mesh_aabb":var_to_str(mesh.get_aabb()),"triangles":triangles,"surfaces":mesh.get_surface_count()})
 check(Props.data().areas.il_village.size()==213 and Props.data().areas.alyut.size()==218,"Every selected source prop is placed, with existing building/tree/gate/cliff owners excluded")
 check(Props.data().graphics["11044"].mode=="well_housing" and Props.data().graphics["11072"].mode=="roofed_well","Both original Il well graphics use fitted solid geometry")
 check(Props.mesh(11044).get_aabb().position.y<.02,"The complete well housing retains its ground supports and rear wall")
 check(Props.data().graphics["12172"].mode=="flowering_tree" and Props.data().graphics["12175"].mode=="flora","Flowering trees and flower stalks cannot fall through to a generic box")
 for id in [11022,11023]:
  var cart:Mesh=Props.mesh(id)
  check(cart.get_meta("source_spoked_wheels",0)==2 and cart.get_aabb().size.y<3. and cart.get_aabb().position.y>=-.02,"Native cart has two source-sized spoked wheels grounded below the tipped deck: "+str(id))
 for id in [11019,11020,11021,11094]:check(closed_top(Props.mesh(id)),"Hay has a closed source bundle top instead of a hollow vessel: "+str(id))
 for id in [11143,11145,11146]:check(Props.mesh(id).get_aabb().size.y<5.,"Reused measured stockade uses the village height frame: "+str(id))
 for id in [11143,11145,11146]:check(measured_uv(id),"Stockade keeps original front UVs and world-sized reverse timber/stone tiles: "+str(id))
 for id in [11143,11145,11146]:check(Props.mesh(id).get_meta("source_round_timber_count",0)==(4 if id==11143 else 3),"Stockade rear retains the observed native round-log count and cut caps: "+str(id))
 check(Props.mesh(11014).get_meta("solid_source_logstore",false) and Props.mesh(11014).get_aabb().size.y<4.,"The large source woodpile has a solid low roof and complete logs instead of an upright sprite board")
 await prop_source_axis(11044);await prop_source_axis(11082)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/east-village-props-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit()
 game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 game.model.team_progression.cards_enabled=false;game.tuning.invincible=true;game.player.set_auto_attack(false)
 game.camera_rig.set_process(false);game.camera_rig.set_process_unhandled_input(false)
 await open_area("east_gate");await site(2000,"il_village")
 await prop_views("il-well-housing",Vector2i(46,94),Vector2i(54,90),Vector2i(49,91))
 await prop_views("il-chief-garden",Vector2i(47,93),Vector2i(39,81),Vector2i(50,86))
 await prop_views("il-stone-well",Vector2i(45,52),Vector2i(53,47),Vector2i(48,48))
 review_area="alyut";anchor_cells.clear()
 await open_area("north_coast");await site(2400,"alyut")
 await prop_views("alyut-stable",Vector2i(51,44),Vector2i(63,35),Vector2i(60,41))
 await prop_views("alyut-farm-cart",Vector2i(64,36),Vector2i(70,35),Vector2i(67,33))
 await prop_views("alyut-south-cart",Vector2i(31,61),Vector2i(37,58),Vector2i(33,58))
 report();print("EAST_VILLAGE_PROPS_RESULT checks=",checks," failures=",errors," captures=",captures.size());await finish()

func closed_top(mesh:Mesh)->bool:
 var box=mesh.get_aabb();var at=Vector3(box.get_center().x,box.end.y+1.,box.get_center().z)
 for slot in mesh.get_surface_count():
  var arrays=mesh.surface_get_arrays(slot);var vertices=arrays[Mesh.ARRAY_VERTEX]
  for i in range(0,vertices.size(),3):
   if Geometry3D.ray_intersects_triangle(at,Vector3.DOWN,vertices[i],vertices[i+1],vertices[i+2])!=null:return true
 return false

func measured_uv(id:int)->bool:
 var g:Dictionary=Props.data().graphics[str(id)];var raw:Mesh=Props.Forms.mesh(id,Props.Forms.kind(id,false,g),g,Props.texture);var placed:Mesh=Props.mesh(id)
 for slot in raw.get_surface_count():
  var arrays=raw.surface_get_arrays(slot);var actual=placed.surface_get_arrays(slot)[Mesh.ARRAY_TEX_UV]
  var paint=raw.surface_get_material(slot);var tile:Variant=paint.get_shader_parameter("atlas_tile_pixels") if paint is ShaderMaterial else 0.
  var tiled=(tile is float or tile is int) and tile>0
  var index=0
  for i in arrays[Mesh.ARRAY_TEX_UV].size():
   if tiled and Props.timber_tile(arrays[Mesh.ARRAY_TEX_UV2][i]):continue
   var expected:Vector2=arrays[Mesh.ARRAY_TEX_UV][i];var normal:Vector3=arrays[Mesh.ARRAY_NORMAL][i]
   if tiled and absf(normal.y)<=maxf(absf(normal.x),absf(normal.z)):expected.y*=.045/Props.Forms.Street.Harbor.PIXEL_HEIGHT
   if index>=actual.size() or not expected.is_equal_approx(actual[index]):return false
   index+=1
  if index!=actual.size():return false
 return true

func prop_source_axis(serial:int):
 var g:Dictionary=Props.data().graphics[str(serial)];var viewport=SubViewport.new()
 viewport.size=Vector2i(g.rect[2]*2,g.rect[3]*2);viewport.own_world_3d=true;viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var stage=Node3D.new();viewport.add_child(stage)
 var environment=WorldEnvironment.new();environment.environment=Environment.new();environment.environment.background_mode=Environment.BG_COLOR;environment.environment.background_color=Color("273039")
 environment.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;environment.environment.ambient_light_color=Color.WHITE;environment.environment.ambient_light_energy=.9;stage.add_child(environment)
 var light=DirectionalLight3D.new();light.rotation_degrees=Vector3(-50,-35,0);light.light_energy=.45;stage.add_child(light)
 var node=MeshInstance3D.new();node.mesh=Props.mesh(serial);node.scale.y=1./(.045*Props.Fit.VERTICAL);stage.add_child(node)
 var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=g.rect[3]/(sqrt(2.)*Props.Fit.HORIZONTAL);stage.add_child(camera)
 var target=Props.source_point(g,Vector2(g.rect[2],g.rect[3])*.5)
 camera.position=target+Vector3(-1,1.603567,1).normalized()*100;camera.look_at(target);camera.current=true
 if DisplayServer.get_name()!="headless":
  for i in 8:await process_frame
  await RenderingServer.frame_post_draw
  check(viewport.get_texture().get_image().save_png(PROP_OUT+"source-axis-"+str(serial)+".png")==OK,"Saved native-axis prop comparison: "+str(serial))
 captures.append({"name":"source-axis-"+str(serial),"source_graphic":serial,"camera":var_to_str(camera.transform),"source_size":[g.rect[2],g.rect[3]],"height_frame":"Reference-only source Euclidean camera; gameplay retains the existing village .045 world/pixel vertical frame."})
 viewport.queue_free();for i in 4:await process_frame

func village_cell(cell:Vector2i)->Vector2:
 var origin:Vector2=Tour.Regions.Sites.VILLAGES[review_area][2]
 return Tour.Regions.village_transform(review_area)*(origin+Vector2(cell)*3.0)

func open_cell(cell:Vector2i)->bool:
 var size_=Vector2i(90,120) if review_area=="il_village" else Vector2i(100,100)
 if not Rect2i(Vector2i.ZERO,size_).has_point(cell):return false
 if not anchor_cells.has(cell):
  var p=village_cell(cell);anchor_cells[cell]=game.model.terrain.disk_clear(Vector3(p.x,0,p.y),.55)
 return anchor_cells[cell]

func prop_views(label:String,preferred:Vector2i,other:Vector2i,target:Vector2i):
 var first=walkable_anchor(preferred);var second=walkable_anchor(other)
 check(connected_anchors(first,second),"Review corners share an original walkable component: "+label)
 for i in 2:
  var cell=first if i==0 else second;var p=village_cell(cell);await position_at(p)
  var facing=(village_cell(target)-p).normalized()
  await gameplay_capture(label+("-normal" if i==0 else "-second"),"Normal gameplay camera above original source walk-grid cell %s, %s"%[cell,review_area],atan2(-facing.x,-facing.y))

func report():
 var file=FileAccess.open(PROP_OUT+"review.json",FileAccess.WRITE)
 file.store_string(JSON.stringify({"checks":checks,"failures":errors,"captures":captures,"observations":observations,"mesh_audit":mesh_audit,"source_inventory":"assets/maps/falan/east_village_props/data.json","inferred_visuals":["Hidden well/stable sides, roof depth, rails and timber using existing coastal pieces","Existing silverleaf tree masters fitted to individually measured original flowering crowns","Shared planter brick and shrub volume","Native fine-prop cutouts with inferred shallow edge depth"],"preserved_owners":["Original source cells/footprints","Existing doors and route graph","Existing collision and navigation","Existing chief solid module","Laruka/West region art"]},"  "));file.close()
