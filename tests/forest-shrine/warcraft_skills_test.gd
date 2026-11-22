extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const OUT="res://build/Other Files/Asset Toolkit/Warcraft/Mirror Image/"
const Kit=preload("res://scripts/warcraft_kit.gd")
const Catalog=preload("res://scripts/spells/spell_catalog.gd")
var live=false
var intervals=[]
var costs=[]
func advance(count:int,army:bool=false):
 for i in count:
  var start=Time.get_ticks_usec()
  game.player._physics_process(1.0/60)
  if army:
   game.army_runtime.step(1.0/60,{"targets":[]});game.army_runtime.dispatch_events();game.army_runtime.sync_compatibility()
   var events=game.army_runtime.presentation_events.duplicate();game.army_runtime.presentation_events.clear()
   game.crowd.army.present(game.army_runtime.render_snapshot(),events)
  costs.append((Time.get_ticks_usec()-start)/1000.0)
  if live and DisplayServer.get_name()!="headless":await physics_frame;intervals.append((Time.get_ticks_usec()-start)/1000.0)
  elif i%30==0:await process_frame
func capture(label_:String):
 if DisplayServer.get_name()=="headless":return
 game.crowd.army.present(game.army_runtime.render_snapshot(),[])
 game.forest_ui.sync();await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(OUT+"skills-"+label_+".png")
func number(slot:int):game.player.spell_loadout.number_input(slot,true);game.player.spell_loadout.number_input(slot,false)
func run():
 create_timer(180).timeout.connect(func():printerr("WARCRAFT_SKILLS_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUT)
 await setup_fixture();game.tuning.invincible=true
 game.set_process_input(false);game.set_process_unhandled_input(false);game.player.set_process_input(false);game.player.set_process_unhandled_input(false)
 game.camera_rig.set_process_input(false);game.camera_rig.set_process_unhandled_input(false)
 var p=game.player;var owner=game.army_runtime
 game.camera_rig.camera.position=ORIGIN+Vector3(25,20,42);game.camera_rig.camera.look_at(ORIGIN+Vector3(0,6,0))
 for key in ["blademaster/wind-walk","blademaster/mirror-image","demon-hunter/immolation"]:check(Catalog.all().has(key),"Shared catalog includes "+key)
 check(not Catalog.all().has("demon-hunter/mana-burn"),"Mana Burn intentionally excluded")
 p.select_character(31);fresh();await advance(5)
 var c=p.active_ability;var speed=p.movement_multiplier()
 tap("heavy_attack");await advance(1)
 check(c.clip=="Attack Slam" and p.model.clip=="Attack Slam","Critical Strike plays the recovered Attack Slam animation")
 check(is_equal_approx(c.contact,.733),"Critical Strike retains original slam contact frame")
 check(SoundLibrary.original_for(31,"wc_slam").resource_path.ends_with("CriticalStrike.wav"),"Critical Strike uses its recovered sound")
 live=true;await advance(15);await capture("critical-strike");live=false;fresh();await advance(2)
 number(2)
 check(c.wind_left>0 and p.rogue_untargetable(),"Wind Walk hides caster from enemy targeting")
 check(is_equal_approx(p.movement_multiplier(),speed*Kit.WIND_SPEED),"Wind Walk uses shared movement multiplier")
 check(c.wind_geometry.any(func(m):return m.transparency>.5),"Wind Walk leaves a visible translucent player")
 live=true;await advance(45);await capture("wind-walk");live=false
 var left=c.wind_left;number(2);check(c.wind_left==left,"Wind cooldown rejects repeated input")
 tap("light_attack");check(c.ticket.get("warcraft_opening",false) and not p.rogue_untargetable(),"Opening attack exits stealth and carries bonus")
 check(is_equal_approx(p.spell_loadout.damage_for_hit(game.training_dummy,48,c.ticket),96),"Opening attack doubles damage in shared hit filter")
 await advance(85);tap("light_attack");check(not c.ticket.get("warcraft_opening",false),"Opening bonus consumed exactly once")
 fresh();c.clear_cooldowns();number(2);await advance(481)
 check(c.wind_left==0 and not p.rogue_untargetable() and is_equal_approx(p.movement_multiplier(),speed),"Wind expiry restores speed and targeting")
 check(c.wind_geometry.all(func(m):return m.transparency==0),"Wind expiry resets owned presentation")
 c.clear_cooldowns();number(2);p.spell_loadout.equip(31,"equip","blademaster/wind-walk");tap("equip")
 var duplicate=p.spell_loadout.instances["31:blademaster/wind-walk"].controller
 check(c.wind_left>0 and duplicate.wind_left==0,"Reassigning native Wind Walk does not stack stealth or opening strikes")
 p.spell_loadout.equip(31,"equip","");await advance(2)
 check(c.wind_geometry.any(func(m):return m.transparency>.5),"Removing an unused duplicate preserves the active wind visual")
 c.cancel()
 p.select_character(32);fresh();await advance(5);c=p.active_ability
 var dummy=game.training_dummy
 var burn_row=game.model.waves.spawn_enemy(0,ORIGIN+Vector3(0,0,-3));burn_row.hp=50000;burn_row.max_hp=50000
 owner.import_arrivals();owner.sync_targets();var victim=game.actors[burn_row.id];var hp=victim.hp
 live=true;number(2);await advance(59)
 check(c.immolating and victim.hp==hp,"Immolation waits one full second before damage")
 await advance(2);check(victim.hp<hp,"Immolation burns a nearby enemy once per second")
 var burned=hp-victim.hp;hp=victim.hp;await advance(60)
 check(is_equal_approx(hp-victim.hp,burned),"Immolation keeps a stable one-second damage cadence")
 await capture("immolation");live=false
 p.spell_loadout.equip(32,"equip","demon-hunter/immolation");tap("equip")
 check(not c.immolating and not p.spell_loadout.instances["32:demon-hunter/immolation"].controller.immolating,"Reassigned Immolation toggles the existing aura off")
 p.spell_loadout.equip(32,"equip","");hp=victim.hp;await advance(100)
 check(not c.immolating and victim.hp==hp and not c.effects.emitters.immolation.emitting,"Toggle off stops damage and emitter")
 number(2);game.paused=true;hp=victim.hp;c.tick(2)
 check(victim.hp==hp,"Paused aura does not damage")
 game.paused=false
 var wall=StaticBody3D.new();wall.collision_layer=1;var collision=CollisionShape3D.new();collision.shape=BoxShape3D.new();collision.shape.size=Vector3(8,8,.2);wall.add_child(collision);game.add_child(wall);wall.position=ORIGIN+Vector3(0,3,-1.25)
 await physics_frame;await physics_frame;hp=victim.hp;await advance(90)
 check(victim.hp==hp,"Immolation respects solid cover")
 wall.free();number(2)
 # All three skills are assignable to another fighter through prepared spell instances.
 p.select_character(1);fresh()
 for pair in [["equip","blademaster/wind-walk"],["surge","demon-hunter/immolation"],["sky_strike","blademaster/mirror-image"]]:check(p.spell_loadout.equip(1,pair[0],pair[1]),"Equip shared "+pair[1])
 await advance(4);tap("equip");check(p.rogue_untargetable(),"Borrowed Wind Walk hides Goemon")
 tap("surge");hp=victim.hp;await advance(65)
 check(victim.hp<hp,"Borrowed Immolation damages without replacing normal weapon")
 tap("sky_strike");await advance(2)
 var borrowed=p.spell_loadout.instances["1:blademaster/mirror-image"].controller.mirrors
 var borrowed_handles=borrowed.handles.duplicate()
 check(borrowed_handles.size()==5 and borrowed.bodies.all(func(body):return body.character_id==1),"Borrowed Mirror Image copies Goemon himself")
 p.select_character(31)
 check(borrowed_handles.all(func(h):return not owner.valid(h)),"Switching clears borrowed mirror leases")
 check(not p.spell_loadout.untargetable(),"Switching fighters clears borrowed wind and aura")
 for pair in ["equip","surge","sky_strike"]:p.spell_loadout.equip(1,pair,"")
 fresh();await advance(5);c=p.active_ability
 owner.despawn(victim.handle);owner.sync_compatibility()
 dummy.home=ORIGIN+Vector3(0,0,-100);dummy.position=dummy.home
 owner.set_navigation(9932,{"width":0});owner.record_events=true;owner.event_log.clear()
 var row=game.model.waves.spawn_enemy(0,ORIGIN+Vector3(0,0,-4));row.hp=50000;row.max_hp=50000
 owner.import_arrivals();owner.sync_targets();var enemy=game.actors[row.id]
 owner.apply_hit(enemy.handle,{"element":"ice","status_seconds":60.0})
 live=true;number(3)
 check(c.mirrors.handles.size()==5,"Mirror Image creates exactly five native allies")
 var first=c.mirrors.handles.duplicate()
 p.spell_loadout.equip(31,"equip","blademaster/mirror-image");tap("equip")
 check(p.spell_loadout.instances["31:blademaster/mirror-image"].controller.mirrors.handles.is_empty() and first.all(func(h):return owner.valid(h)),"Reassigned Mirror Image cannot create a second group or retire the first")
 p.spell_loadout.equip(31,"equip","")
 check(first.all(func(h):return owner.valid(h) and owner.unit_state(h).kind==131 and owner.unit_state(h).team==1),"Every mirror belongs to the existing native army")
 check(game.explorer_helpers.active_units().is_empty(),"Mirrors do not consume paid mercenary slots or food")
 await advance(110,true);await capture("mirror-pursuit")
 await advance(300,true);await capture("mirror-attacks")
 var spins={};var melees=0;var choices={}
 for body in c.mirrors.bodies:
  for choice in body.action_history:
   choices[choice]=true
   if choice==2:spins[body.get_instance_id()]=true
   else:melees+=1
 check(choices.size()>1,"Images choose varied attacks from their character kit")
 check(melees>0 and enemy.hp<50000,"Copies deal damage through their shared character attacks")
 check(p.impact_pause==0,"Copy impacts do not pause the caster")
 await advance(500,true)
 check(first.size()==5 and first.all(func(h):return owner.valid(h)),"All mirrors stay active past fifteen seconds")
 await advance(900,true)
 check(c.mirrors.handles.is_empty() and first.all(func(h):return not owner.valid(h)),"All mirrors expire at thirty seconds")
 # Compare settled casts; immediate attacks can leave short-lived impact effects.
 await advance(180,true)
 var count=Performance.get_monitor(Performance.OBJECT_NODE_COUNT);var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for cycle in 3:
  c.clear_cooldowns();number(3);await advance(35,true);var leases=c.mirrors.handles.duplicate();c.cancel()
  check(leases.size()==5 and leases.all(func(h):return not owner.valid(h)),"Repeated cast/cancel retires every native lease")
 await advance(180,true)
 print("WARCRAFT_SKILLS_NODE_DELTA ",Performance.get_monitor(Performance.OBJECT_NODE_COUNT)-count)
 check(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)<=count,"Repeated summons do not grow node count")
 print("WARCRAFT_SKILLS_RESOURCE_DELTA ",Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)-resources)
 check(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated summons do not retain new resources")
 live=false
 c.clear_cooldowns();number(2);number(3);p.select_character(32);fresh();c=p.active_ability;number(2)
 game.tuning.invincible=false;p.invuln=0;p.hp=1;p.take_hit(100,Vector3.BACK)
 check(not c.immolating and not c.effects.emitters.immolation.emitting,"Death clears active aura")
 game._respawn_player();check(not p.active_ability.immolating,"Respawn does not revive old aura")
 for id in [31,32]:
  p.select_character(id);fresh();await advance(2)
  check(p.model.billboards.size()==(13 if id==31 else 76),"Recovered native billboard flags %d"%id)
  for angle in [0,PI/2,PI]:
   game.camera_rig.camera.position=ORIGIN+Vector3(sin(angle)*34,14,cos(angle)*34);game.camera_rig.camera.look_at(ORIGIN+Vector3.UP*7);p.model.pose("Stand",.2)
   check(p.model.billboards.all(func(b):return p.model.skeleton.get_bone_global_pose(b.bone).basis.is_finite()),"Finite camera-facing body glow %d/%s"%[id,angle])
   await capture("glow-%d-%d"%[id,roundi(angle*100)])
   if id==32:
    p.model.pose("Stand Alternate",.2);await capture("glow-demon-%d"%roundi(angle*100))
 costs.sort();intervals.sort()
 var report={"checks":checks,"failures":failures,"step_p95_ms":costs[int(costs.size()*.95)],"rendered_frame_p95_ms":intervals[int(intervals.size()*.95)] if not intervals.is_empty() else null,"mirror_spins":spins.size(),"mirror_melees":melees}
 FileAccess.open(OUT+"skills-"+DisplayServer.get_name()+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("WARCRAFT_SKILLS_RESULT ",JSON.stringify(report));game.queue_free();await frames(3);DirAccess.remove_absolute(cfg);quit(1 if failures else 0)
