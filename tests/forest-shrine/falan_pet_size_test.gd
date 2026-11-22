extends "res://tests/forest-shrine/freyja_villages_habaru_test.gd"

const Sprites=preload("res://scripts/forest/crowd/hound_sprites.gd")
const Pets=preload("res://scripts/forest/pet_catalog.gd")

func run():
 var model=load("res://scripts/forest/forest_model.gd").new()
 for source in [Pets,Habaru,Zombie,Captain,Grave,Ruby,Undersea,preload("res://scripts/forest/crowd/falan_frontier_sprites.gd"),preload("res://scripts/forest/crowd/slime_sprites.gd")]:
  var mesh:QuadMesh=source.make_mesh()
  var original_size=mesh.material.get_shader_parameter("enemy_size")
  if Dimensions.HEIGHTS.has(source.ROOT.trim_suffix("/").get_file()):
   var factors:PackedFloat32Array=mesh.material.get_shader_parameter("pet_scales")
   for skin in source.motions().variants.size():
    var box=Dimensions.body(source,skin)
    check(is_equal_approx(box.size.y,float(source.motions().variants[skin].standing_height)*factors[skin]),"Rendered standing height matches the fitted hitbox")
  var node=MultiMeshInstance3D.new();node.multimesh=MultiMesh.new();node.multimesh.mesh=mesh;root.add_child(node)
  for area in ["city","castle","east_gate","east_coast","south_gate","south_lakes","interior",""]:
   model.falan_area=area
   Sprites.apply_world_scale(node,model)
   check(node.get_instance_shader_parameter("use_world_pet_sizes")== (not area.is_empty()),"Every sprite family uses its species proportions only in the Explore world: "+area)
   check(mesh.material.get_shader_parameter("enemy_size")==original_size,"Shared source materials retain their original sizing")
  model.terrain_detail=model.FreyjaTerrain.ID
  Sprites.apply_world_scale(node,model)
  check(node.get_instance_shader_parameter("use_world_pet_sizes")==true,"The original Freyja terrain also uses the species proportions")
  model.terrain_detail=""
  node.free()
 var patrols=preload("res://scripts/forest/crowd/falan_frontier_sprites.gd")
 check(Dimensions.body(patrols,patrols.GOBLIN).size.y<Dimensions.KAZ_HEIGHT*.8,"Goblins remain substantially shorter than Kaz")
 check(Dimensions.body(patrols,patrols.TREE).size.y>Dimensions.KAZ_HEIGHT*1.8,"Trees retain a larger species silhouette")
 await super.run()

func check_frontier_patrols():
 game.tuning.invincible=true
 Tour.travel(game,Tour.outdoor_layout(get_meta("falan_venture"),"east_gate"),{"arrival":Vector2(3,242),"yaw":0.0})
 for i in 4:await physics_frame
 game.paused=true
 game.army_runtime.finish_integration()
 for i in game.model.waves.patrol_posts.size()+1:game.model.waves.tick(12.0,game.player.position)
 game.army_runtime.import_arrivals()
 game.crowd.present_army(game.army_runtime.render_snapshot(),[])
 check(game.model.enemies.size()>=20,"Simultaneous outdoor patrols use the species-sized renderer")
 verify_batches()
 verify_contacts()
 if DisplayServer.get_name()!="headless":
  DirAccess.make_dir_recursive_absolute(OUT+"Pet Size")
  await capture_species_lineup()
  var row:Dictionary=game.model.enemies.values().filter(func(enemy):return enemy.get("frontier_patrol",false))[0]
  var at:Vector3=game.army_runtime.unit_state(game.army_runtime.handles[row.id]).position
  game.paused=true
  for node in game.crowd.army.batches.values():
   if node.get_instance_shader_parameter("use_world_pet_sizes")!=null:node.set_instance_shader_parameter("use_world_pet_sizes",false)
  await shot("Pet Size/original-proportions",at+Vector3(0,8,18),at+Vector3.UP*2.5,58)
  for node in game.crowd.army.batches.values():Sprites.apply_world_scale(node,game.model)
  await shot("Pet Size/species-proportions",at+Vector3(0,8,18),at+Vector3.UP*2.5,58)
 game.paused=false
 for floor_id in [11003,Habaru.ROOM,Zombie.FINAL,Captain.ROOM,Grave.ROOM,Ruby.ROOM,Undersea.SOKIA]:
  Tour.travel(game,Tour.Indoor.layout(floor_id),{"arrival":Vector2.ZERO,"yaw":0.0})
  for i in 4:await physics_frame
  verify_batches()
  verify_contacts()
  var army=game.crowd.army
  var node=army.batch(Vector3i(Roles.SLIME,0,0))
  check(node.get_instance_shader_parameter("use_world_pet_sizes")==true,"New dungeon batches inherit species proportions: "+str(floor_id))
 print("FALAN_PET_SIZE_RESULT failures=",errors)

func verify_batches():
 var army=game.crowd.army
 for node in army.batches.values()+army.presentation.corpse_batches.values()+army.presentation.batches.values():
  var mesh=node.multimesh.mesh
  if mesh is QuadMesh and mesh.material is ShaderMaterial and mesh.material.shader in [preload("res://assets/materials/hound_crowd.gdshader"),preload("res://assets/materials/hound_afterimage.gdshader")]:
   check(node.get_instance_shader_parameter("use_world_pet_sizes")==true,"Living pets, corpses and body afterimages retain species proportions after travel")

func verify_contacts():
 var runtime=game.army_runtime
 runtime.finish_integration()
 for row in game.model.enemies.values():
  if not runtime.handles.has(row.id) or row.variant!=Roles.SLIME:continue
  var actor=runtime.enemy_target(row.id)
  var box=Dimensions.bounds(runtime.pet_geometry,row.variant,row.skin)
  check(actor.local_combat_box().is_equal_approx(box),"The player query uses the native species body")
  var collider:CollisionShape3D=actor.get_child(0)
  check(collider.shape.size.is_equal_approx(box.size),"The physics collider matches the species body")
  var at=actor.global_position
  var inside=at+Vector3(0,box.end.y-.01,0)
  check(actor.combat_segment_hit(inside-Vector3.RIGHT*10,inside+Vector3.RIGHT*10,0),"A hit just below the fitted top connects")
  var above=at+Vector3.UP*(box.end.y+.1)
  check(not actor.combat_segment_hit(above-Vector3.RIGHT*10,above+Vector3.RIGHT*10,0),"A hit above the fitted top misses")

func capture_species_lineup():
 var viewport=SubViewport.new();viewport.size=Vector2i(1800,700);viewport.own_world_3d=true
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var env=WorldEnvironment.new();env.environment=Environment.new()
 env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("202b36")
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE
 viewport.add_child(env)
 var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=11
 camera.position=Vector3(0,2.8,20);viewport.add_child(camera)
 var kaz:Sprite3D=game.player.model.sprite.duplicate();kaz.position.x=-11.25;viewport.add_child(kaz)
 var source=preload("res://scripts/forest/crowd/falan_frontier_sprites.gd")
 var names=["Kaz · 100%","Mini bat · 80%","Goblin · 70%","Bandit · 100%","Bee · 80%","Tree · 190%"]
 for index in names.size():
  var x=-11.25+index*4.5
  var label=Label3D.new();label.text=names[index];label.font_size=40;label.pixel_size=.009
  label.position=Vector3(x,-.65,1);viewport.add_child(label)
  if index==0:continue
  var skin=index-1
  var node=MultiMeshInstance3D.new();node.multimesh=MultiMesh.new()
  node.multimesh.transform_format=MultiMesh.TRANSFORM_3D;node.multimesh.use_custom_data=true
  node.multimesh.mesh=source.make_mesh();node.multimesh.instance_count=1
  node.multimesh.set_instance_transform(0,Transform3D(Basis.IDENTITY,Vector3(x,0,0)))
  node.multimesh.set_instance_custom_data(0,Color(skin,80,0,0));node.custom_aabb=AABB(Vector3(-20,-2,-2),Vector3(40,15,4))
  viewport.add_child(node);Sprites.apply_world_scale(node,game.model)
  var box=Dimensions.body(source,skin);var lines=ImmediateMesh.new();lines.surface_begin(Mesh.PRIMITIVE_LINES)
  var corners=[]
  for y in [box.position.y,box.end.y]:
   for z in [box.position.z,box.end.z]:
    for side in [box.position.x,box.end.x]:corners.append(Vector3(side+x,y,z))
  for pair in [[0,1],[0,2],[1,3],[2,3],[4,5],[4,6],[5,7],[6,7],[0,4],[1,5],[2,6],[3,7]]:
   lines.surface_add_vertex(corners[pair[0]]);lines.surface_add_vertex(corners[pair[1]])
  lines.surface_end()
  var wire=MeshInstance3D.new();wire.mesh=lines;var material=StandardMaterial3D.new()
  material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=Color("63d4ed");material.no_depth_test=true
  wire.material_override=material;viewport.add_child(wire)
 for i in 4:await process_frame
 await RenderingServer.frame_post_draw
 check(viewport.get_texture().get_image().save_png(OUT+"Pet Size/species-lineup.png")==OK,"Captured Kaz-relative species sizes and fitted hitboxes")
 viewport.queue_free()
