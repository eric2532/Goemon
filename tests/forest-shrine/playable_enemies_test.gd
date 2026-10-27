extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Roster=preload("res://scripts/rogue_roster.gd")
const Catalog=preload("res://scripts/spells/spell_catalog.gd")
const Pool=preload("res://scripts/character_projectile_pool.gd")
const OUT="res://build/Other Files/Playable Enemies/"
var timings=[]
func advance(count:int):
 for i in count:
  game.player._physics_process(1.0/60)
  for nodes in Pool.service(game).all.values():
   for shot in nodes:
    if shot.pool_live and shot.get_script() in [preload("res://scripts/recovered_enemy_projectile.gd"),preload("res://scripts/dark_lumina_3_projectile.gd")]:shot._physics_process(1.0/60)
  if i%40==0:await process_frame
func capture(label_:String):
 if DisplayServer.get_name()=="headless":return
 var camera=game.camera_rig.camera;var before=camera.global_transform
 camera.position=game.player.position+(Vector3(70,50,90) if game.player.character_id==27 else Vector3(6,4,9));camera.look_at(game.player.position+Vector3.UP*(12 if game.player.character_id==27 else 1.5))
 game.player.model.show();await frames(3);await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUT+label_+".png")
 camera.global_transform=before
func run():
 await setup_fixture()
 if DisplayServer.get_name()!="headless":
  DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP,true);DisplayServer.window_move_to_foreground()
 var p=game.player;var loadout=p.spell_loadout
 var owner=game.army_runtime;var count=owner.handles.size()
 for id in Roster.ENEMIES:
  p.select_character(id);fresh();game.camera_rig.yaw=0;await advance(2)
  game.camera_rig.camera.position=ORIGIN+Vector3(0,2.4,10);game.camera_rig.camera.look_at(ORIGIN+Vector3(0,1,-20))
  check(p.character_id==id and p.active_ability.source_id()==id,"Enemy %d uses shared player ownership"%id)
  check((p.body_shape.shape.size.y if p.body_shape.shape is BoxShape3D else p.body_shape.shape.height)>=p.model.bounds().size.y,"Enemy %d has fitted collision"%id)
  if id==27:
   check(p.model.skull.scale==Vector3.ONE and p.model.bounds().size.y==25,"Playable Skullpion keeps the full fivefold enemy boss scale")
   var targets=owner.external_targets()
   check(targets.maximum[0]-targets.minimum[0]==p.model.bounds().size,"Native army receives the full player boss hurtbox")
   p._clear_large_character_spawn()
   var query=PhysicsShapeQueryParameters3D.new();query.shape=p.body_shape.shape;query.transform=p.global_transform*p.body_shape.transform;query.collision_mask=1;query.exclude=[p.get_rid()]
   check(p.get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(),"Boss selection finds a body-sized space outside castle walls")
   var boss_start=p.position;p.smoke_move=Vector2(0,1);await advance(60);p.smoke_move=Vector2.ZERO
   check(p.position.distance_to(boss_start)>1,"Full-size Skullpion moves with the shared player controller")
   for i in 90:game.camera_rig.update_camera(1.0/60)
   check(game.camera_rig.camera.global_position.distance_to(p.global_position)>30,"Normal gameplay camera widens for the full-size boss")
   if DisplayServer.get_name()!="headless":
    p.model.show();await frames(3);await RenderingServer.frame_post_draw
    root.get_texture().get_image().save_png(OUT+"skullpion-gameplay.png")
   fresh();await advance(2)
  var initial=p.model.current_clip;p.model.animate(.2,5,true,0,0,false,0,false)
  check((p.model.current_clip!=initial or (id==30 and p.model.current_clip=="Source__801eeac8")),"Enemy %d uses its recovered movement animation"%id)
  p.model.animate(0,0,true,0,0,false,0,false)
  contacts.clear()
  p.auto_attack_enabled=true;p.auto_lock_target=game.training_dummy;p.auto_lock_refresh=100
  if id==27:p.active_ability.start_skull_attack(103)
  else:tap("light_attack")
  p.auto_attack_enabled=false;await advance(190 if id==30 else 150 if id==27 else 38)
  print("ENEMY_ATTACK_TRACE ",id," position=",p.position," facing=",p.facing," clip=",p.model.current_clip," contacts=",contacts)
  if id!=21:check(not contacts.is_empty(),"Enemy %d original attack reaches a real target"%id)
  else:
   await advance(160);check(not contacts.is_empty(),"Gunner's pooled original three-shot burst reaches a real target")
  await capture("attack-%d"%id)
  p.cancel_charge();p.position=ORIGIN;p.velocity=Vector3.ZERO;await advance(2)
  loadout.equip(id,"equip","ed/beam")
  var prepared=loadout.instances.values()[0]
  var event=InputEventAction.new();event.action="equip";event.pressed=true
  var start=Time.get_ticks_usec();p._unhandled_input(event);timings.append({"fighter":id,"first_input_usec":Time.get_ticks_usec()-start})
  check(loadout.instances.values()[0]==prepared,"Enemy %d starts its already-prepared spell runtime"%id)
  await advance(8)
  check(p.model.cast_owner==prepared,"Enemy %d animates its own body while casting"%id)
  await capture("cast-%d"%id)
  event.pressed=false;p._input(event)
  p.cancel_charge();loadout.equip(id,"equip","")
  check(game.army_runtime==owner and owner.handles.size()==count,"Selecting enemy %d does not spawn a second army actor"%id)
  p.active_ability.start_attack();p.active_ability._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
  check(not p.active_ability.is_attacking(),"Enemy %d clears pending attacks on focus loss"%id)
 # The player adapter damages a native opponent without another simulated unit.
 p.select_character(20);fresh();await advance(2)
 check(p.body_shape.shape is CapsuleShape3D,"Switching away from Skullpion restores the ordinary fighter capsule")
 var row=game.model.waves.spawn_enemy(0,ORIGIN+Vector3(0,0,-1.5));row.hp=1000;row.max_hp=1000
 owner.import_arrivals();owner.sync_targets()
 var actor=game.actors[row.id];var hp=actor.hp
 tap("light_attack");await advance(36)
 check(actor.hp<hp,"Enemy fighter delivers damage through the native army's existing HP and hit path")
 owner.clear();game.actors.clear();game.enemies.clear();game.model.enemies.clear()
 preload("res://tests/forest-shrine/training_dummy_fixture.gd").install(game)
 # Native and foreign Knight's Code both apply the same single reduction.
 for id in [1,7,23]:
  p.select_character(id);fresh();loadout.retired_cooldowns.clear()
  loadout.equip(id,"surge","knight/drink");tap("surge");await advance(150)
  var amount=loadout.filter_damage(100,Vector3.LEFT,false)
  if id==7:amount=p.active_ability.filter_damage(amount,Vector3.LEFT,false)
  check(is_equal_approx(amount,50),"Knight's Code reduces damage once on fighter %d"%id)
  loadout.equip(id,"surge","")
 # D-Kick must advance its source motion clock on a foreign body; 3-Way must release.
 p.select_character(24);fresh();await advance(2)
 for id in ["musashi/d-kick","musashi/fence","musashi/homing","musashi/grenade","musashi/three-way"]:
  p.cancel_charge();p.position=ORIGIN;p.velocity=Vector3.ZERO;await advance(2)
  check(Catalog.all().has(id) and loadout.equip(24,"equip",id),"Missing Musashi ability is equipable: "+id)
  var press=InputEventAction.new();press.action="equip";press.pressed=true;p._unhandled_input(press)
  var instance=loadout.instances.values()[0];var start=p.position
  await advance(30)
  if id.ends_with("d-kick"):check(p.position.distance_to(start)>.2,"Transferred D-Kick uses the original source movement clock")
  else:check(instance.controller.assimilation.releases>0,"Transferred ability releases original projectiles: "+id)
  press.pressed=false;p._input(press);await advance(100)
  check(not instance.controller.assimilation.held,"Released Musashi spell cannot remain held: "+id)
 loadout.equip(24,"equip","")
 # A prepared Ed beam resets local state and reuses its shield while source phases persist.
 p.select_character(23);loadout.equip(23,"equip","ed/beam")
 var beam_pool=Pool.service(game);var beam_created=beam_pool.created
 var old_beam:Node;var old_shield:Node
 for i in 20:
  var event=InputEventAction.new();event.action="equip";event.pressed=true;p._unhandled_input(event)
  var beam=loadout.instances.values()[0].controller.beam
  check(beam!=null and beam.active and beam.elapsed==0 and beam.shield.age==0,"Prepared Ed beam resets both cast clocks")
  if old_beam!=null:check(beam==old_beam and beam.shield==old_shield,"Repeated Ed casts reuse the same beam and shield")
  old_beam=beam;old_shield=beam.shield
  await advance(10);p.cancel_charge()
 check(beam_pool.created==beam_created,"Repeated Ed beam casts create no additional pooled actors")
 loadout.equip(23,"equip","")
 # Repeated bullet leases reset state without growth after setup.
 p.select_character(21);var pool=Pool.service(game);var created=pool.created
 var shot_script=preload("res://scripts/recovered_enemy_projectile.gd")
 for i in 100:
  var shot=pool.launch(p,shot_script,"soldier",{"velocity":Vector3.FORWARD,"attack_ticket":{"sample":i}})
  shot.lifetime=0;shot.retire()
  shot=pool.launch(p,shot_script,"soldier",{})
  check(shot.lifetime>3 and shot.velocity==Vector3.ZERO and shot.attack_ticket.is_empty(),"Soldier bullet lease resets all transient state")
  shot.retire()
 check(pool.created==created,"Repeated gunner shots reuse the prepared pool")
 var picker=load("res://scripts/rogue_roster_picker.gd").new();picker.game=game;game.ui.add_child(picker)
 await capture("gallery");picker.queue_free()
 FileAccess.open(OUT+"checks.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"renderer":RenderingServer.get_video_adapter_name(),"first_casts":timings},"  "))
 game.queue_free();paused=false;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("PLAYABLE_ENEMIES_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
