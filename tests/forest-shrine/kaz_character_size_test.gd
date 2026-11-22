extends "res://tests/forest-shrine/pet_size_gameplay_test.gd"

const Proportions=preload("res://scripts/character_proportions.gd")
const Dimensions=preload("res://scripts/forest/crowd/pet_dimensions.gd")
const Roster=preload("res://scripts/rogue_roster.gd")
const SIZE_OUT="res://build/Other Files/Asset Toolkit/Kaz Character Sizes/"
var reviewed=false
func character_skins()->Array:
 return Dimensions.CHARACTER_BODY_PIXELS.keys().map(func(key):return Pets.skin(key))
func simultaneous_skins()->Array:return [Pets.skin("v3:341"),Pets.skin("ch1:71"),Pets.skin("puk3:206"),Pets.skin("joy:773"),Pets.skin("joy-ex:821")]
func run():
 var factors=Dimensions.scales(Pets.ROOT,Pets.motions())
 var geometry=Dimensions.geometry(null)
 var authored:Array=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/crossgate/companions/catalog.json")).profiles
 for skin in Pets.COUNT:
  var box=Dimensions.companion_body(skin)
  check(Dimensions.bounds(geometry,19,skin).is_equal_approx(box),"Native contact body shares pet size: "+Pets.title(skin))
  check(is_equal_approx(geometry[Dimensions.offset(19,skin)+6],factors[skin]),"Native reach shares render scale: "+Pets.title(skin))
  if Dimensions.CHARACTER_BODY_PIXELS.has(Pets.key(skin)):
   var pixels:float=Dimensions.CHARACTER_BODY_PIXELS[Pets.key(skin)]
   check(is_equal_approx(pixels*Roles.HOUND_PIXEL_SIZE*Roles.HOUND_SCALE*factors[skin],Proportions.GOEMON_HEIGHT),"Reviewed character artwork matches Kaz: "+Pets.title(skin))
   check(is_equal_approx(box.size.y,Proportions.GOEMON_HEIGHT),"Character pet combat height matches Kaz: "+Pets.title(skin))
  elif skin>=82:
   var row:Array=authored[skin-82].body
   check(is_equal_approx(factors[skin],authored[skin-82].visual_scale) and box.is_equal_approx(AABB(Vector3(row[0],row[1],row[2]),Vector3(row[3]-row[0],row[4]-row[1],row[5]-row[2]))),"Animal and monster pet retains authored size: "+Pets.title(skin))
 var runtime=load("res://scripts/forest/crowd/army_runtime.gd").new();runtime.configure(null)
 for skin in character_skins():
  check(skin>=82,"Reviewed character key exists in the saved catalog")
  var box=Dimensions.companion_body(skin)
  var actor=load("res://scripts/forest/crowd/army_enemy_target.gd").new()
  actor.runtime=runtime;actor.handle=runtime.spawn(90000+skin,0,19,Vector3.ZERO,3000,.5)
  actor.variant=19;actor.body_override=box;root.add_child(actor)
  check(actor.get_child(0).shape.size.is_equal_approx(box.size),"Character pet physics matches its prepared body")
  for axis in [Vector3.UP,Vector3.RIGHT,Vector3.BACK]:
   var edge=box.get_center()+axis*box.size*.5
   var along=Vector3.RIGHT if axis==Vector3.UP else Vector3.UP
   check(actor.combat_segment_hit(edge-axis*.02-along*20,edge-axis*.02+along*20,0),"Inside resized character body connects")
   check(not actor.combat_segment_hit(edge+axis*.02-along*20,edge+axis*.02+along*20,0),"Outside resized character body misses")
  runtime.despawn(actor.handle);actor.free()
 runtime.clear();runtime.free()
 await super.run()
func equip_pack(skins:Array,loadouts:Array):
 await super.equip_pack(skins,loadouts)
 if reviewed:return
 reviewed=true
 var p=game.player
 for id in Roster.selection_ids():
  p.select_character(id);fresh()
  var model=p.model
  check(is_equal_approx(model.standing_height(),Proportions.GOEMON_HEIGHT),"Selectable fighter matches Kaz: "+Roster.name_for(id))
  for skin in Roster.skin_catalog(id):
   if Roster.is_shin(id):model.set_shin_skin(skin)
   elif Roster.has_variant_skins(id):model.set_variant_skin(skin)
   else:model.set_kaz_skin(skin)
   check(is_equal_approx(model.sprite.pixel_size*Proportions.crossgate_body_pixels(id,skin),Proportions.GOEMON_HEIGHT),"Selected skin refreshes Kaz height: %d / %d"%[id,skin])
 p.select_character(34);p.model.set_kaz_skin(p.model.Skins.DEFAULT);fresh()
 p.model.show_frame(0,"0:4",0)
 if DisplayServer.get_name()!="headless":
  var selected=character_skins()
  for first in range(0,selected.size(),4):
   var pack=selected.slice(first,mini(first+4,selected.size()))
   await capture_lineup(pack,first/4)
 await super.equip_pack(skins,loadouts)
 p.position=home+Vector3.RIGHT*30
func capture_lineup(pack:Array,batch:int):
 var mesh=Pets.make_mesh(pack.map(func(skin):return Pets.key(skin)))
 var viewport=SubViewport.new();viewport.size=Vector2i(1600,700);viewport.own_world_3d=true
 viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;root.add_child(viewport)
 var env=WorldEnvironment.new();env.environment=Environment.new()
 env.environment.background_mode=Environment.BG_COLOR;env.environment.background_color=Color("202b36")
 env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.environment.ambient_light_color=Color.WHITE;viewport.add_child(env)
 var camera=Camera3D.new();camera.projection=Camera3D.PROJECTION_ORTHOGONAL;camera.size=9
 camera.position=Vector3(0,2.7,20);viewport.add_child(camera)
 var kaz:Sprite3D=game.player.model.sprite.duplicate();kaz.position.x=-8;viewport.add_child(kaz)
 for index in pack.size()+1:
  var x=-8+index*4.0
  var label=Label3D.new();label.text="Kaz" if index==0 else Pets.label(pack[index-1]);label.font_size=32;label.pixel_size=.009
  label.position=Vector3(x,-1.2,1);viewport.add_child(label)
  if index==0:continue
  var node=MultiMeshInstance3D.new();node.multimesh=MultiMesh.new()
  node.multimesh.transform_format=MultiMesh.TRANSFORM_3D;node.multimesh.use_custom_data=true
  node.multimesh.mesh=mesh;node.multimesh.instance_count=1
  node.multimesh.set_instance_transform(0,Transform3D(Basis.IDENTITY,Vector3(x,0,0)))
  node.multimesh.set_instance_custom_data(0,Color(pack[index-1],80,0,0))
  node.custom_aabb=AABB(Vector3(-20,-5,-5),Vector3(40,20,10));viewport.add_child(node)
 await frames(4);await RenderingServer.frame_post_draw
 DirAccess.make_dir_recursive_absolute(SIZE_OUT)
 check(viewport.get_texture().get_image().save_png(SIZE_OUT+"characters-%d.png"%batch)==OK,"Captured Kaz and four character pets without summon effects")
 viewport.queue_free();await frames(2)
func capture(name_:String):
 if DisplayServer.get_name()=="headless":return
 DirAccess.make_dir_recursive_absolute(SIZE_OUT)
 game.army_runtime.flush_presentation();game.forest_ui.sync();await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(SIZE_OUT+name_+".png")==OK,"Captured "+name_)
