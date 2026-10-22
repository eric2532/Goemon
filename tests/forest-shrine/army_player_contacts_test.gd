extends SceneTree
const Contact=preload("res://scripts/forest/forest_enemy_contact.gd")
const Head=preload("res://scripts/master_chief_hit_zones.gd")
var checks=0
var failures=0
var fixture
var runtime
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 runtime=load("res://scripts/forest/crowd/army_runtime.gd").new()
 if not runtime.has_method("enemy_target"):
  check(false,"Native army player adapters and synchronous HP routing are missing");runtime.free();finish();return
 fixture=load("res://tests/forest-shrine/large_army_fixture.gd").new();root.add_child(fixture)
 var game=await fixture.make_game("original")
 runtime.configure(game);game.add_child(runtime);runtime.configure_kits(load("res://scripts/forest/crowd/army_kit_data.gd").from_model(game.model));game.model.army_runtime=runtime
 fixture.clear_targets();var id=100000;var handle:int=runtime.spawn(id,0,0,Vector3(20,8,60),64.123456789,3.9)
 var actor=runtime.enemy_target(id);game.enemies.append(actor)
 check(actor is Ninja and actor.model==null and not actor.is_physics_processing(),"Enemy facade has native player target type without a controller/model")
 check(actor.get_child_count()==1 and actor.collision_layer==4 and actor.collision_mask==0,"Only the fitted layer4 physics proxy is allocated")
 runtime.set_pose(handle,Vector3(20,8,60),.73);runtime.sync_targets()
 var data=actor._combat_data();var prepared=Contact.prepare(data)
 check(actor.combat_bounds().is_equal_approx(Contact.bounds(data)),"Rotated and raised soldier bounds match source fitted geometry")
 var bounds:AABB=actor.combat_bounds()
 for point in [bounds.get_center(),bounds.position,bounds.end,Vector3(40,20,80)]:
  check(actor.combat_contact_point(point).distance_to(Contact.contact(data,point,prepared))<.0001,"Fitted contact matches the original soldier")
 for line in [[bounds.get_center(),bounds.get_center()],[bounds.get_center()+Vector3.RIGHT*20,bounds.get_center()-Vector3.RIGHT*20],[bounds.end+Vector3.UP,bounds.end+Vector3.UP*3]]:
  var original=Contact.segment_contact(data,line[0],line[1],.2,prepared);var actual=actor.combat_segment_contact(line[0],line[1],.2)
  check(original.is_empty()==actual.is_empty() and (original.is_empty() or original.point.distance_to(actual.point)<.0001),"Piercing/swept and inside-body casts match source geometry")
 var head=Head.region(actor);var center:Vector3=head.pose*head.bounds.get_center()
 check(not Head.contact(actor,center+Vector3.BACK*20,center+Vector3.FORWARD*20).is_empty(),"Chief animated head queries use the original source bone")
 check(absf(runtime.unit_state(handle).hp-64.123456789)<1e-10,"HP retains authoritative double precision for exact lethal hits")
 actor.take_hit(1,Vector3.FORWARD,false,{"tower":true});check(absf(actor.hp-63.123456789)<1e-10,"Tower and player target share synchronous precise HP")
 game.model.phase="wave";game.model.enemies[id]={"id":id,"hp":actor.hp,"max_hp":actor.max_hp,"pos":actor.position,"variant":0,"ryo_dropped":true}
 game.model.damage_enemy(id,2)
 check(absf(actor.hp-61.123456789)<1e-10,"Model tower damage immediately routes into native authority")
 var nested={"spawned":false,"id":id+100}
 runtime.unit_died.connect(func(event):
  if event.target_id!=id or nested.spawned:return
  nested.spawned=true
  var extra:int=runtime.spawn(nested.id,0,3,Vector3(30,8,60),30,3.9)
  runtime.enemy_target(nested.id).take_hit(100,Vector3.FORWARD,false,{"tower":true})
 )
 var kills=game.kills
 var gold_before:int=game.model.gold
 actor.take_hit(.1,Vector3.FORWARD,false,{"lethal_headshot":true,"tower":true})
 check(is_zero_approx(actor.hp),"A lethal headshot mirror subtracts authoritative damage exactly once")
 check(actor.dead and actor.hp<=0 and not runtime.valid(handle) and actor.collision_layer==0,"Lethal headshot immediately removes target from all live contacts")
 actor.take_hit(10,Vector3.FORWARD,false,{"tower":true});runtime.dispatch_events()
 check(game.kills==kills+2 and nested.spawned,"Nested kill/spawn and repeated drains award exactly one kill per victim")
 check(game.model.ryo.claimed_enemies.has(id) and game.model.ryo.claimed_enemies.has(nested.id),"Nested final-victim callbacks preserve both exactly-once bounties")
 check(game.model.gold==gold_before+24 and game.model.ryo.drops.is_empty(),"Native nested deaths credit both bounties immediately without coins")
 var reused:int=runtime.spawn(id,0,0,Vector3(22,8,60),64,3.9)
 var reused_actor=runtime.enemy_target(id)
 check(reused_actor!=actor and reused_actor.hp==64 and not reused_actor.dead,"Reusing a logical ID still creates a fresh target for the new generation")
 runtime.despawn(reused)
 var replacement:int=runtime.spawn(id+1,0,0,Vector3(20,8,60),64,3.9)
 var next=runtime.enemy_target(id+1)
 check(next.get_instance_id()!=actor.get_instance_id() and next.hp==64,"Recycled native slots get distinct target identities for existing projectile histories")
 runtime.apply_hit(handle,{"amount":1000});check(next.hp==64,"Despawn between broad/narrow phases cannot damage a replacement")
 var ally:int=runtime.spawn(-10,1,7,Vector3(5,0,60),500,.4)
 var friendly=runtime.ally_target(-10)
 check(not friendly is Ninja and friendly.gate_id==-10,"Allied facade cannot enter player enemy queries")
 friendly.take_hit(10,Vector3.RIGHT,true);check(friendly.hp==490,"Autonomous allies receive independent authoritative damage")
 runtime.set_pose(replacement,Vector3(0,0,52),0);runtime.sync_targets()
 next.freeze_for(1.5);next.apply_defense_slow(.5,3)
 check(runtime.unit_state(replacement).frozen==1.5 and runtime.unit_state(replacement).slow_factor==.5,"Player freeze/slow APIs reach the simulation")
 # Unchanged real player abilities target the facade through their existing APIs.
 for character in [1,11,14,15,16,17,18]:
  fixture.clear_targets();runtime.clear();var p=fixture.reset_player(character);p.position=Vector3(0,.15,60)
  var data_=game.model.waves.spawn_enemy(0,Vector3(0,0,56));data_.hp=10000;data_.max_hp=10000
  var h:int=runtime.spawn(data_.id,0,0,data_.pos,10000,3.9);var target=runtime.enemy_target(data_.id)
  game.actors[data_.id]=target;game.enemies.append(target);var clock={"frame":0}
  fixture.active_tick=func(dt):
   if clock.frame==0:fixture.send_action("light_attack",true)
   if clock.frame==60:fixture.send_action("light_attack",false)
   p._physics_process(dt);clock.frame+=1
  await fixture.advance(1.5);fixture.active_tick=Callable();runtime.dispatch_events()
  check(target.hp<10000,"Unchanged character %d primary attack hits native target"%character)
 await compare_original_attacks(game)
 game.model.army_runtime=null;runtime.clear();runtime.queue_free();await fixture.close();fixture.queue_free();await process_frame;finish()
func compare_original_attacks(game):
 var traces={}
 for backend in ["legacy","crowd"]:
  var results=[]
  for kind in ["bomb","beam","headshot"]:
   fixture.clear_targets();runtime.clear();game.model.army_runtime=runtime if backend=="crowd" else null
   for projectile in get_nodes_in_group("projectiles"):
    if is_instance_valid(projectile):projectile.queue_free()
   await process_frame
   var hero=fixture.reset_player(15 if kind=="bomb" else (14 if kind=="beam" else 18))
   hero.position=Vector3(0,100,60);hero.facing=Vector3.FORWARD
   var row=game.model.waves.spawn_enemy(0,Vector3(0,100,52));row.hp=10000.123456789;row.max_hp=row.hp
   var target
   if backend=="crowd":
    runtime.spawn(row.id,0,0,row.pos,row.hp,3.9);target=runtime.enemy_target(row.id)
   else:
    target=load("res://scripts/forest/forest_raider.gd").new();target.game=game;target.forest_id=row.id;target.variant=0;target.position=row.pos;target.swarm=true
    game.add_child(target);target.set_physics_process(false);target._sync_fitted_pose()
   game.actors[row.id]=target;game.enemies.append(target)
   var before:float=target.hp
   if kind=="bomb":
    var shot=load("res://scripts/recovered_leader_projectile.gd").new();shot.game=game;shot.hero=hero;shot.source_character=15;shot.bomb=true;shot.damage=40;shot.blast_radius=4;shot.attack_ticket=hero.attack_chain.make_ticket("test_bomb")
    game.add_child(shot);shot._explode(Vector3(0,102,52));shot.queue_free()
   elif kind=="beam":
    var beam=load("res://scripts/recovered_ed_beam.gd").new();beam.game=game;beam.hero=hero;beam.attack_ticket=hero.attack_chain.make_ticket("beam")
    game.add_child(beam);beam.elapsed=1
    game.camera_rig.yaw=0;game.camera_rig.pitch=0;game.camera_rig.reset_follow();game.camera_rig.update_camera(1)
    beam.damage_tick();beam.stop();beam.queue_free()
   else:
    var head=Head.region(target);var center:Vector3=head.pose*head.bounds.get_center()
    var direction=(center-(hero.position+Vector3.UP*1.68)).normalized()
    game.camera_rig.yaw=atan2(-direction.x,-direction.z);game.camera_rig.pitch=-asin(direction.y);game.camera_rig.first_person_recoil=0;game.camera_rig.update_camera(0)
    hero.master_chief_combat.weapon_slot=2;hero.master_chief_combat.cooldown=0;hero.master_chief_combat.fire_shot()
   results.append(before-target.hp)
   check(target.hp<before,"Original %s executes against %s targets"%[kind,backend])
  traces[backend]=results
 for i in 3:check(is_equal_approx(traces.legacy[i],traces.crowd[i]),"Original attack %d preserves legacy damage through the native facade"%i)
func finish():
 print("ARMY_PLAYER_CONTACTS_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
