extends "res://scripts/recovered_goemon_gameplay_tests.gd"

const Qi=preload("res://scripts/qigong_combat.gd")
const Skills=preload("res://scripts/spells/skill_balance.gd")
const Roles=preload("res://scripts/forest/forest_enemy_roles.gd")
const OUT="res://build/Other Files/Asset Toolkit/Qi Skill Selection/Character Casting/"
const DT=1.0/60
var home=Vector3(-120,0,125)
var shots:Array=[]

func spawn(offset:Vector3)->Ninja:
 var at=home+offset;at.y=game.model.surface_height(at.x,at.z)
 var row=game.model.waves.spawn_enemy(0,at);row.hp=1000000;row.max_hp=row.hp
 game.army_runtime.import_arrivals();game.army_runtime.sync_targets()
 return game.army_runtime.enemy_target(row.id)

func capture(name_:String):
 if DisplayServer.get_name()=="headless":return
 game.forest_ui.sync();await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+name_+".png")==OK,"Captured "+name_)

func run():
 create_timer(240).timeout.connect(func():printerr("SKILL_SIZE_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUT);root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 var p=game.player;var army=game.army_runtime;var rewards=game.model.team_progression
 game.set_process(false);army.set_process(false);army.set_physics_process(false);game.exploration_loot.set_process(false);game.camera_rig.set_process(false);game.camera_rig.set_physics_process(false)
 for node in [game,p,game.camera_rig,game.forest_ui]:
  node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true
 home.y=game.model.surface_height(home.x,home.z)+.05;game.model.update_vision(home)
 game.training_dummy.position=home+Vector3.DOWN*100
 var pool=Qi.Pool.service(game)
 pool.launched.connect(func(shot):shot.set_physics_process(false);shots.append(shot))
 game.camera_rig.camera.global_position=home+Vector3(4,8,18);game.camera_rig.camera.look_at(home+Vector3(2,2,-4))
 game.model.waves.crossgate_pet_test=true;army.refresh_kits()
 var slime_at=home+Vector3(0,0,-4);slime_at.y=game.model.surface_height(slime_at.x,slime_at.z)
 var slime=game.model.waves.spawn_enemy(Roles.SLIME,slime_at);slime.hp=1000000;slime.max_hp=slime.hp
 army.import_arrivals();army.sync_targets();game.crowd.present_army(army.render_snapshot(),[])
 for id in p.RogueRoster.CROSSGATE:
  p.select_character(id);fresh();p.position=home;p.velocity=Vector3.ZERO
  for spell in [Qi.ID,Qi.MAZE_QI,Qi.MOON_ID]:
   var kit=p.spell_loadout._instance(spell).controller
   for stacks in [0,20]:
    rewards.skill_food_stacks=stacks
    kit.clear_cooldowns();kit.start_cast()
    var glow:Sprite3D=kit.charge_fx
    var cell=glow.texture.get_size()/Vector2(glow.hframes,glow.vframes)
    var multiplier=2.0 if stacks else 1.0
    check(is_equal_approx(maxf(cell.x,cell.y)*glow.pixel_size*glow.global_basis.get_scale().x,Skills.BASE_DIAMETER*(91.0/357.0)*multiplier),"Fighter %d %s: original level-one shine and food growth"%[id,spell])
    check(glow.global_position.is_equal_approx(p.model.qi_blast_chest()),"Fighter %d %s: shine starts at body centre"%[id,spell])
    if spell==Qi.MOON_ID:kit.release_moon()
    else:kit.release_volley()
    var shot=shots[0]
    if spell==Qi.MOON_ID:
     check(is_equal_approx(Qi.Moon.VISUAL_LENGTH*shot.skill_factor("size"),Skills.BASE_DIAMETER*multiplier),"Fighter %d: moon keeps the same base length"%id)
    else:
     check(is_equal_approx(shot.visual.scale.x*Qi.Shot.DIAMETER,Skills.BASE_DIAMETER*.3*multiplier),"Fighter %d %s: orb art is 40 percent smaller and retains growth"%[id,spell])
     check(is_equal_approx(shot.hit_radius*shot.collision_scale,Skills.BASE_DIAMETER*.5*multiplier),"Fighter %d %s: shrinking the art preserves the hit radius"%[id,spell])
     if shot.rank11_shine:check(is_equal_approx(shot.shine.pixel_size*131.0*shot.shine.scale.x,Skills.BASE_DIAMETER*.3*multiplier),"Fighter %d %s: impact shine is 40 percent smaller and retains growth"%[id,spell])
     check(float(shot.visual.get_instance_shader_parameter("gold_palette"))==0.0,"Saved Gold Qi IDs default to regular blue")
     check(float(shot.visual.get_instance_shader_parameter("uru_palette"))==0.0,"Ruby defaults to the same blue Qi")
     check(shot.visual.position==Vector3.ZERO,"Bigger Qi remains centred on its trajectory")
    if id in [34,35,36] and stacks==0:
     if spell==Qi.MOON_ID:
      shot.global_position=home+Vector3(7,0,-4);shot.visual_growth=1.0;shot.visual.set_instance_shader_parameter("growth",1.0);shot.update_visual()
     else:shot.global_position=home+Vector3(5,3,-4)
     for other in shots.slice(1):other.hide()
     kit.charge_fx.hide();shot.show()
     await capture("fighter-%d-%s"%[id,spell.replace("/","-")])
    rewards.skill_food_stacks=0
    check(shot.skill_factor("size")==multiplier,"Released shots retain their food snapshot")
    kit.cancel();shots.clear()
  if id%6==0:await frames(1)
 p.select_character(34);fresh();p.position=home;p.velocity=Vector3.ZERO
 army.clear();game.model.enemies.clear();army.refresh_kits()
 var primary=spawn(Vector3(0,0,-4));var extra=spawn(Vector3(6.5,0,-4));var outside=spawn(Vector3(24,0,-4))
 for spell in [Qi.ID,Qi.MOON_ID]:
  for stacks in [0,20]:
   rewards.skill_food_stacks=stacks;p.attack_chain.reset()
   var script=Qi.Shot if spell==Qi.ID else Qi.Moon
   var center=primary.combat_bounds().get_center() if spell==Qi.ID else primary.global_position+Vector3.UP*Qi.Moon.GROUND_CLEARANCE
   var config={"position":center,"target":primary,"velocity":Vector3.FORWARD*.001,"damage":10.0,"flight_life":2.5,"attack_ticket":p.attack_chain.make_ticket(spell)}
   if spell==Qi.ID:config.effect_height=Skills.BASE_DIAMETER
   # Moon's narrower crest has its own fixed footprint, preserved across casters.
   army.set_pose(extra.handle,home+Vector3(5 if spell==Qi.MOON_ID else 6.5,0,-4),0);army.sync_targets()
   var before=[primary.hp,extra.hp,outside.hp]
   var shot=pool.launch(p,script,spell,config)
   shot._physics_process(DT)
   check(is_equal_approx(before[0]-primary.hp,10),spell+": primary receives one hit")
   check(is_equal_approx(before[1]-extra.hp,10 if stacks else 0),spell+": growth catches an extra enemy once")
   check(outside.hp==before[2],spell+": distant enemy stays outside coverage")
   if shot.pool_live:shot.retire()
  var wall=StaticBody3D.new();var collider=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(.3,9,8)
  collider.shape=box;wall.add_child(collider);game.add_child(wall);wall.position=home+Vector3(2.5,3,-4)
  await physics_frame;await physics_frame
  var before=extra.hp
  var center=primary.combat_bounds().get_center() if spell==Qi.ID else primary.global_position+Vector3.UP*Qi.Moon.GROUND_CLEARANCE
  p.attack_chain.reset()
  var config={"position":center,"target":primary,"velocity":Vector3.FORWARD*.001,"damage":10.0,"flight_life":2.5,"attack_ticket":p.attack_chain.make_ticket(spell)}
  if spell==Qi.ID:config.effect_height=Skills.BASE_DIAMETER
  var shot=pool.launch(p,Qi.Shot if spell==Qi.ID else Qi.Moon,spell,config)
  shot._physics_process(DT)
  check(extra.hp==before,spell+": solid cover blocks the grown splash")
  if shot.pool_live:shot.retire()
  wall.free();await physics_frame;await physics_frame
 rewards.reset();p.select_character(37);fresh();p.position=home;p.velocity=Vector3.ZERO;p.model.select_stance(2)
 army.set_pose(primary.handle,home+Vector3(0,0,-3),0);army.set_pose(extra.handle,home+Vector3(7.5,0,-3),0);army.sync_targets()
 var kit=p.active_ability
 for stacks in [0,20]:
  p.attack_chain.reset();kit.clear_shin_counter();p.spell_loadout.equip(37,"surge","shin/counter");rewards.skill_food_stacks=stacks
  var before=[primary.hp,extra.hp]
  kit.counter_after_hit(Vector3.BACK,primary.forest_id)
  var glow:Sprite3D=p.model.shin_counter_fx
  check(is_equal_approx(glow.pixel_size*334*glow.global_basis.get_scale().x,Skills.BASE_DIAMETER*(2 if stacks else 1)),"Counter energy uses original level-one shine and food growth")
  glow.frame=4
  await capture("counter-%d-servings"%stacks)
  for i in 80:
   kit.tick_shin_counter(DT)
   if kit.shin_counter.is_empty():break
  check(is_equal_approx(before[0]-primary.hp,375),"Level-one counter hits its attacker once for 1.5× base damage")
  check(is_equal_approx(before[1]-extra.hp,375 if stacks else 0),"Grown counter catches the extra enemy once")
  kit.clear_shin_counter()
 rewards.reset();kit.clear_shin_counter()
 var fx=game.crowd.army.presentation
 var anchor=primary.combat_bounds().get_center()
 if DisplayServer.get_name()!="headless":
  for kind in ["kazi_combo","shin_combo","shin_sure_strike","shin_double_edge"]:
   fx.effects.clear()
   if kind.ends_with("combo"):fx.combo_burst(anchor,1.0,kind=="shin_combo",Skills.BASE_DIAMETER,primary.combat_bounds().size.length()*.5)
   else:fx.sure_strike_burst(anchor,Skills.BASE_DIAMETER,kind=="shin_double_edge",primary.combat_bounds().size.length()*.5)
   for view in [Vector3(0,6,18),Vector3(-12,9,12),Vector3(14,4,6),Vector3(2,18,4)]:
    game.camera_rig.camera.global_position=home+view;game.camera_rig.camera.look_at(anchor+Vector3.RIGHT*3)
    fx.draw_effects()
    var pose=fx.batches[kind].multimesh.get_instance_transform(0)
    var camera=game.camera_rig.camera
    check(camera.unproject_position(pose.origin).distance_to(camera.unproject_position(anchor))<.01,"Impact stays screen-centred from each camera angle")
    var reference=anchor+camera.global_basis.x*Skills.BASE_DIAMETER*.5
    var edge=pose.origin+pose.basis.x*fx.batches[kind].multimesh.mesh.size.x*.5
    # body_height=1 keeps the submitted diameter in world units.
    check(camera.unproject_position(reference).distance_to(camera.unproject_position(edge))<.01,"Front placement preserves the apparent skill size")
 game.queue_free();paused=false;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("SKILL_SIZE_CONSISTENCY_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
