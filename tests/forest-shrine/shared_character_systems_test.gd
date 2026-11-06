extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Combat=preload("res://scripts/character_combat.gd")
const Pool=preload("res://scripts/character_projectile_pool.gd")
const AudioBank=preload("res://scripts/character_audio_bank.gd")
const Ice=preload("res://scripts/recovered_sasuke_projectile.gd")
const Missile=preload("res://scripts/recovered_yae_projectile.gd")
const LeaderShot=preload("res://scripts/recovered_leader_projectile.gd")

func run():
 await setup_fixture()
 var p=game.player;p.position=ORIGIN
 var progression=p.progression;var chain=p.attack_chain;var loadout=p.spell_loadout
 game.rogue_roster_mode=true;p.hp=p.max_hp*.63
 for id in p.RogueRoster.PLAYABLE_IDS:
  p.select_character(id)
  check(p.character_id==id and p.progression==progression and p.attack_chain==chain and p.spell_loadout==loadout,"Fighter%d uses shared progression, damage attribution and spells"%id)
  check(is_equal_approx(p.hp/p.max_hp,.63),"Fighter%d preserves health through shared selection"%id)
  if "--visual" in OS.get_cmdline_user_args():await capture_fighter(id)
  if id!=1:
   check(p.active_ability is Combat and p.active_ability.source_id()==id,"Fighter%d uses common controller ownership and lifecycle"%id)
   p.active_ability._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
   check(not p.active_ability.is_attacking(),"Fighter%d cancels pending offense on focus loss"%id)
 p.select_character(1);p.primary_down=true;p.auto_attack_enabled=true;p._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
 check(not p.primary_down and not p.auto_attack_running(),"Goemon uses the shared focus boundary")
 var pool=Pool.service(game)
 check(pool==Pool.service(game),"All kits resolve one projectile service")
 var samples=preload("res://scripts/recovered_sasuke_audio.gd")
 var voice=samples.stream_for("jump")
 check(voice==samples.stream_for("jump") and voice.get_streams_count()==3,"Shared audio cache retains weighted native variations")
 check(voice.get_stream(1)==voice.get_stream(2) and samples.stream_for("move_primary_2_voice")==null,"Shared audio cache preserves duplicate weights and intentional silence")
 check(AudioBank.sample(samples.ROOT+"event_210.wav")==samples.stream_for("swing"),"Event maps reuse the same sample resource")
 var rogue_audio=game.get_node("RogueSharedClassAudio");rogue_audio.volume=.55;rogue_audio.last_events.erase("cast");rogue_audio.play("cast",{"character_id":6,"volume":0})
 check(rogue_audio.cache.get("cast-mage")==AudioBank.sample("res://assets/rogue/audio/cast-mage.wav") and game.sounds.fire_cast==AudioBank.sample("res://assets/characters/musashi/audio/fire_cast.wav"),"Rogue classes and Edo use the same sample bank as the recovered fighters")
 var shared_fx=game.get_node("RogueSharedClassEffects")
 var borrowed=load("res://scripts/spells/spell_instance.gd").new();p.add_child(borrowed)
 borrowed.setup(p,loadout.Catalog.all()["ranger/rapid-shot"])
 p.ai_controlled=true;borrowed.queue_free();await process_frame;await process_frame;p.ai_controlled=false
 check(is_instance_valid(shared_fx) and game.get_node_or_null("RogueSharedClassEffects")==shared_fx,"Deleting an AI borrowed skill preserves the shared impact effects")
 p.select_character(16)
 var config={"kind":"ice","position":Vector3(0,20,60),"velocity":Vector3.FORWARD,"attack_ticket":{"source_character_id":16}}
 var shot=pool.launch(p,Ice,"sasuke/ice",config)
 var original_mesh=shot.ornament;var count=pool.created;var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 shot.hit_targets[999]=true;shot.age=4;shot.resolved=true;shot.lifetime=0;shot.damage_scale=9;shot.set_meta("old_attack",true);shot.retire()
 var clean=true;var reuse_start=Time.get_ticks_usec()
 for i in 100:
  shot=pool.launch(p,Ice,"sasuke/ice",config)
  clean=clean and shot.ornament==original_mesh and shot.hit_targets.is_empty() and shot.age==0 and not shot.resolved and shot.lifetime==2 and shot.damage_scale==1 and not shot.has_meta("old_attack")
  shot.retire()
 var reuse_usec=Time.get_ticks_usec()-reuse_start
 check(clean,"Repeated reuse resets hits, timers, damage, metadata and keeps prepared visuals")
 check(pool.created==count and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"One hundred prepared shots create no additional nodes or resources")
 var fresh_start=Time.get_ticks_usec()
 for i in 100:
  var fresh_shot=Ice.new();fresh_shot.game=game;fresh_shot.hero=p;fresh_shot.visual_source=p.model;fresh_shot.kind="ice"
  game.add_child(fresh_shot);fresh_shot.free()
 print("SHARED_PROJECTILE_CPU hundred_fresh_usec=%d hundred_reused_usec=%d"%[Time.get_ticks_usec()-fresh_start,reuse_usec])
 p.select_character(17)
 var target_ref=weakref(game.training_dummy)
 shot=pool.launch(p,Missile,"yae/lock_on",{"kind":"lock_on","target":target_ref,"velocity":Vector3.RIGHT})
 shot.retire();shot=pool.launch(p,Missile,"yae/lock_on",{"kind":"lock_on"})
 check(shot.target==null and shot.velocity==Vector3.ZERO and shot.attack_ticket.is_empty(),"A reused homing missile inherits no target, motion or attack ticket")
 shot.retire()
 shot=pool.launch(p,Missile,"overflow-reset",{"kind":"lock_on","target":target_ref,"velocity":Vector3.RIGHT,"damage_scale":9,"lifetime":.1,"attack_ticket":{"old":true}})
 shot.retire();shot=pool.launch(p,Missile,"overflow-reset",{"kind":"lock_on"})
 check(shot.target==null and shot.velocity==Vector3.ZERO and shot.damage_scale==1 and shot.lifetime==3 and shot.attack_ticket.is_empty(),"Cache growth cannot turn a live cast's transient state into the next cast's defaults")
 shot.retire()
 p.select_character(15)
 for kind in ["shuriken","axe","bomb"]:
  var launch={"source_character":15,"hit_radius":.4};launch[kind]=true
  shot=pool.launch(p,LeaderShot,"ben/"+kind,launch);var radius=shot.hit_radius;shot.retire()
  shot=pool.launch(p,LeaderShot,"ben/"+kind,launch)
  check(is_equal_approx(radius,shot.hit_radius),"Ben %s scales its contact radius exactly once on reuse"%kind)
  shot.retire()
 p.select_character(1)
 var first=game.spawn_gold_coin(Vector3(0,20,60),Vector3.FORWARD,false,false,1,false,0,{},false,99)
 var batch=first.batches[0].multimesh;first.retire()
 var next=game.spawn_gold_coin(Vector3(0,20,60),Vector3.RIGHT,false,false,1,false,0,{},false,2)
 check(next==first and next.batches[0].multimesh==batch and batch.instance_count==2 and next.active_count==2 and next.points[0]==Vector3.ZERO,"Level changes reuse Goemon's batches with the correct live coin count")
 next.retire()
 # Forced overlap must grow safely rather than evict a shot already in flight.
 var live=[]
 for i in 11:live.append(pool.launch(p,Ice,"overlap",config))
 check(live.all(func(item):return item.pool_live) and live[0]!=live[-1],"Unexpected concurrency never overwrites a live projectile")
 for item in live:item.retire()
 var stale=live[0];stale.free()
 shot=pool.launch(p,Ice,"overlap",config)
 check(is_instance_valid(shot) and shot.pool_live,"External wave cleanup cannot leave an invalid reusable instance")
 shot.retire()
 for kind in preload("res://scripts/forest/forest_enemy_roles.gd").RIGID_TYPES:
  var mesh=preload("res://scripts/forest/forest_thirstquencher_visual.gd").make_mesh(kind)
  check(mesh!=null and mesh.get_surface_count()>0,"Shared native renderer supports textured and untextured role%d"%kind)
 p.free()
 check(pool.all.is_empty() and pool.idle.is_empty(),"Caster deletion removes active and parked projectile ownership")
 game.free();game=null;paused=false;await frames();await create_timer(.15).timeout
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("SHARED_CHARACTER_SYSTEMS_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)

func capture_fighter(id:int):
 game.player.model.show()
 if is_instance_valid(game.camera_rig.first_person_viewmodel):game.camera_rig.first_person_viewmodel.hide()
 game.camera_rig.camera.global_position=ORIGIN+Vector3(6,4.5,10)
 game.camera_rig.camera.look_at(ORIGIN+Vector3.UP*1.8)
 await frames(6)
 await RenderingServer.frame_post_draw
 var dir="res://build/Other Files/Asset Toolkit/Shared Character Systems/Captures"
 DirAccess.make_dir_recursive_absolute(dir)
 root.get_texture().get_image().save_png(dir+"/fighter-%02d.png"%id)
