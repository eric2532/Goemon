extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const OUT="res://build/Other Files/Asset Toolkit/Mountain King/"
const Pool=preload("res://scripts/character_projectile_pool.gd")
const Shot=preload("res://scripts/mountain_king_projectile.gd")
var home=Vector3(-60,.1,60)
var live=false
var steps=[]
var intervals=[]
func fresh(surge:bool=false):
 super.fresh(surge)
 game.player.position=home;game.player.velocity=Vector3.DOWN
 game.player.move_and_slide();game.model.update_vision(home)
 game.training_dummy.home=home+Vector3.FORWARD*3;game.training_dummy.position=game.training_dummy.home
func aim_at(point:Vector3):
 var rig=game.camera_rig;rig.update_camera(0)
 var direction=(point-rig.camera.global_position).normalized()
 rig.yaw=atan2(-direction.x,-direction.z);rig.pitch=-asin(direction.y);rig.update_camera(0)
func advance(count:int):
 for i in count:
  var start=Time.get_ticks_usec()
  game.player._physics_process(1.0/60)
  for nodes in Pool.service(game).all.values():
   for shot in nodes:
    if shot.pool_live and shot.get_script()==Shot:shot._physics_process(1.0/60)
  steps.append((Time.get_ticks_usec()-start)/1000.0)
  if live and DisplayServer.get_name()!="headless":
   await physics_frame;intervals.append((Time.get_ticks_usec()-start)/1000.0)
  elif i%30==0:await process_frame
func capture(label_:String):
 if DisplayServer.get_name()=="headless":return
 game.forest_ui.sync()
 game.camera_rig.camera.global_position=home+Vector3(22,16,-28)
 game.camera_rig.camera.look_at(home+Vector3(0,7,0))
 game.player.model.pose(game.player.model.clip,game.player.active_ability.elapsed)
 RenderingServer.force_draw();await process_frame
 root.get_texture().get_image().save_png(OUT+label_+".png")
func run():
 create_timer(240).timeout.connect(func():printerr("MOUNTAIN_KING_TIMEOUT");quit(1))
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data);game.tuning.invincible=true
 home.y=game.model.surface_height(home.x,home.z)+.1
 game.camera_rig.set_process_unhandled_input(false)
 var p=game.player;var pool=Pool.service(game)
 pool.launched.connect(func(shot):
  if shot.get_script()==Shot:shot.set_physics_process(false))
 p.select_character(33);fresh();await advance(12)
 var model=p.model;var kit=p.active_ability
 game.forest_ui.sync();check(game.forest_ui.hero_name.text=="Mountain King","HUD shows Mountain King")
 check(game.forest_ui.helper_portraits.slice(0,3).all(func(icon):return icon.visible and icon.texture!=null),"Original spell icons appear in shared hotbar")
 check(p.RogueRoster.selection_ids().has(33),"Mountain King in shared roster")
 for level in [1,3,5,99]:
  p.team_progression.level=level;check(kit.rank()==mini(3,1+(level-1)/2),"Spell ranks follow shared team level "+str(level))
 p.team_progression.level=1
 check(model.motion.clips.size()==27,"All 27 original body clips")
 check(model.skeleton.get_bone_count()==100,"Intact imported rig")
 check(model.meshes.size()==8,"All eight source geosets")
 for name_ in model.motion.clips:
  check(model.animation_player.has_animation(name_),"Imported "+name_)
  for part in [.0,.5,.99]:
   model.pose(name_,model.animation_player.get_animation(name_).length*part)
   check(model.meshes.any(func(m):return m.visible),"Visible authored pose "+name_+" "+str(part))
 var glow_count=0
 for mesh in model.meshes:
  var mat=mesh.material_override
  if mat.blend_mode==BaseMaterial3D.BLEND_MODE_ADD:
   glow_count+=1
   var texture=mat.albedo_texture.get_image()
   if texture.is_compressed():texture.decompress()
   var blue_pixels=0
   for y in texture.get_height():
    for x in texture.get_width():
     var pixel=texture.get_pixel(x,y)
     if pixel.b>.05 and pixel.b>pixel.r*2:blue_pixels+=1
   check(blue_pixels>100 and mat.albedo_texture==mesh.mesh.surface_get_material(0).albedo_texture,"Blue glow is baked into the asset texture")
  else:
   var texture=mat.albedo_texture.get_image()
   if texture.is_compressed():texture.decompress()
   var blue_pixels=0
   for y in texture.get_height():
    for x in texture.get_width():
     var pixel=texture.get_pixel(x,y)
     if pixel.b>.1 and pixel.b>pixel.r*2:blue_pixels+=1
   check(blue_pixels>1000 and mat.albedo_texture==mesh.mesh.surface_get_material(0).albedo_texture,"Blue armor and clothes are baked into the asset texture")
 check(glow_count>0,"Original hero aura retained")
 model.pose("Stand",0);var normal=[]
 for i in model.skin_textures:normal.append(model.meshes[i].material_override.albedo_texture)
 model.pose("Stand Alternate",0)
 var index=0
 for i in model.skin_textures:
  check(model.meshes[i].material_override.albedo_texture!=normal[index],"Avatar switches original skin "+str(i));index+=1
 for slot in preload("res://scripts/warcraft_audio.gd").FILES[33]:check(SoundLibrary.original_for(33,slot)!=null,"Original audio "+slot)
 check(game.sound_preview(33,"step")==game.sound_default(1,"step"),"Shared running and walking sound")
 check(SoundLibrary.original_for(33,"hit")!=null,"Original heavy hammer contact sound")
 fresh();await advance(6);await capture("idle-blue")
 var step_samples=[]
 var previous_order=game.voice_idx
 p.smoke_move=Vector2.RIGHT
 for i in 90:
  await advance(1)
  for voice in game.voices:
   if voice.get_meta("order",-1)>previous_order and voice.get_meta("kind","")=="step":step_samples.append(voice.stream)
  previous_order=game.voice_idx
 check(not step_samples.is_empty() and step_samples.all(func(sample):return sample==game.sound_default(1,"step")),"Actual running dispatches shared footstep audio")
 fresh();await advance(6)
 for i in 2:
  contacts.clear();kit.start_attack();kit.bashing=false
  await advance(1);check(contacts.is_empty(),"Melee preserves original windup")
  await advance(60);check(contacts.size()==1,"Melee delivers one contact")
 fresh();kit.start_attack();kit.interrupt_for_dodge();await advance(60)
 check(contacts.is_empty(),"Dodge cancels pending melee contact")
 var jump_start=p.position.y
 tap("jump");await advance(15);check(p.position.y>jump_start+.1,"Shared jump control")
 fresh();await advance(5)
 var owner=game.army_runtime
 game.training_dummy.home=home+Vector3(0,0,-100);game.training_dummy.position=game.training_dummy.home
 var row=game.model.waves.spawn_enemy(0,home+Vector3(0,0,-5));row.hp=10000;row.max_hp=10000
 owner.import_arrivals();owner.sync_targets()
 var victim=game.actors[row.id];var hp=victim.hp
 aim_at(AttackChain.aim_point(victim,p.global_position+Vector3.UP*1.6))
 kit.start_bolt();check(kit.mode=="bolt" and kit.bolt_cooldown==9,"Storm Bolt starts with source cooldown")
 game.forest_ui.sync();check(game.forest_ui.loadout_cooldowns[0].text=="9.0s","Native spell cooldown appears on its numbered slot")
 await advance(20);check(victim.hp==hp,"Storm Bolt waits for source cast point")
 await advance(32);check(victim.hp<hp,"Homing Storm Bolt damages native target")
 check(owner.unit_state(victim.handle).stun>4.5,"Storm Bolt applies native five-second stun")
 await capture("storm-bolt")
 await advance(80);hp=victim.hp;kit.start_clap();check(kit.mode=="clap","Grounded Thunder Clap starts")
 check(victim.hp<hp,"Thunder Clap immediately damages native ground target")
 await advance(26)
 check(owner.unit_state(victim.handle).slow_factor==.5,"Thunder Clap applies native movement slow")
 await advance(10);await capture("thunder-clap");await advance(55)
 kit.bashing=true;kit.ticket=p.attack_chain.begin("warcraft_attack");kit.after_strike(victim,false)
 check(owner.unit_state(victim.handle).stun>=2,"Bash applies native stun")
 var base=p.max_hp;kit.start_avatar();await advance(30)
 check(kit.demon and kit.avatar_left>59 and p.max_hp==base+500,"Avatar adds 500 HP for sixty seconds")
 check(kit.attack_damage(false)==76,"Avatar retains Bash bonus and adds 20 attack damage")
 check(kit.filter_damage(130,Vector3.ZERO,false)==100 and kit.spell_immune(),"Avatar armor and spell immunity")
 await capture("avatar-blue")
 kit.tick_timers(60);check(not kit.demon and p.max_hp==base,"Avatar expiry restores normal maximum HP")
 # Pooled effects refresh per target and reset all references on release.
 var created=pool.created;var misses=pool.misses
 for i in 100:
  Shot.status(p,Shot,"bash",victim,2,{"test":true})
 var key=pool.key_for(p,Shot,"bash")
 check(pool.all[key].filter(func(s):return s.pool_live and s.target==victim).size()==1,"Repeated Bash refreshes one effect per target")
 pool.release_owner(p)
 for i in 100:
  var shot=pool.launch(p,Shot,"bolt",{"target":victim,"velocity":Vector3.FORWARD*30,"damage":350,"attack_ticket":{"old":true}})
  shot.age=3;shot.retire();shot=pool.launch(p,Shot,"bolt",{})
  check(shot.target==null and shot.age==0 and shot.velocity==Vector3.ZERO and shot.damage==100 and shot.attack_ticket.is_empty(),"Storm Bolt lease resets")
  shot.retire()
 check(pool.created==created and pool.misses==misses,"Repeated casts do not grow pool")
 # Cover stops damage even when the target was selected before the wall appeared.
 kit.cancel();kit.clear_cooldowns();p.position=home;aim_at(AttackChain.aim_point(victim,p.global_position+Vector3.UP*1.6));kit.start_bolt()
 var wall=StaticBody3D.new();wall.collision_layer=1
 var shape=CollisionShape3D.new();shape.shape=BoxShape3D.new();shape.shape.size=Vector3(10,8,.2);wall.add_child(shape);game.add_child(wall);wall.position=home+Vector3(0,3,-2)
 await physics_frame;await physics_frame;hp=victim.hp;await advance(100)
 check(victim.hp==hp,"Storm Bolt respects newly introduced cover")
 wall.free()
 p.select_character(1);fresh();await advance(5)
 game.training_dummy.home=home+Vector3(0,0,-100);game.training_dummy.position=game.training_dummy.home
 p.spell_loadout.equip(1,"equip","mountain-king/storm-bolt")
 aim_at(AttackChain.aim_point(victim,p.global_position+Vector3.UP*1.6));hp=victim.hp
 tap("equip");await advance(110)
 check(p.character_id==1 and victim.hp<hp,"Borrowed Storm Bolt uses shared skill system")
 p.spell_loadout.equip(1,"equip","mountain-king/thunder-clap");hp=victim.hp
 tap("equip");await advance(70)
 check(victim.hp<hp,"Borrowed Thunder Clap uses shared skill system")
 p.spell_loadout.equip(1,"equip","")
 p.select_character(33);fresh();await advance(5);kit=p.active_ability
 live=true;created=pool.created
 for i in 3:
  kit.cancel();kit.clear_cooldowns();kit.start_clap();await advance(90)
  kit.start_avatar();await advance(60);kit.end_avatar()
 check(pool.created==created,"Rendered repeated spells keep prepared pool stable")
 await capture("final-blue")
 # Five simultaneous copies retain native ownership and reuse the same kit/pool.
 var mirrors=preload("res://scripts/warcraft_mirrors.gd").new(p)
 check(mirrors.cast(),"Mountain King copies register with native kind133")
 var handles=mirrors.handles.duplicate()
 for body in mirrors.bodies:
  body.active_ability.start_avatar()
  check(body.active_ability.demon and owner.unit_state(body.native_handle).max_hp==base+500,"Allied Avatar applies one native health bonus")
 var count=pool.created
 for i in 90:
  mirrors.tick(1.0/60);await advance(1)
 check(pool.created==count,"Simultaneous allied Avatar reuses prepared effects")
 await capture("allied-avatars")
 mirrors.clear();check(handles.all(func(h):return not owner.valid(h)),"Copies retire through native lifecycle")
 mirrors.dispose()
 game.tuning.invincible=false;kit.cancel();kit.clear_cooldowns();kit.start_avatar();p.hp=1;p.invuln=0
 p.take_hit(100,Vector3.BACK)
 check(p.hp<=0 and kit.mode=="dead" and kit.clip=="Alternate Death","Defeat retains original Avatar death")
 var death_time=kit.elapsed;model._process(.2);check(kit.elapsed>death_time,"Defeat animation advances")
 game._respawn_player();check(p.hp>0 and not kit.demon and p.max_hp==base,"Respawn restores normal Mountain King")
 game.tuning.invincible=true
 p.select_character(1);check(not kit.active and not kit.demon and kit.mode.is_empty(),"Character switching clears form and pending actions")
 steps.sort();intervals.sort()
 var report={"checks":checks,"failures":failures,"pool_created":pool.created,"pool_misses":pool.misses,"player_step_p95_ms":steps[int(steps.size()*.95)],"player_step_max_ms":steps[-1],"rendered_frame_p95_ms":intervals[int(intervals.size()*.95)] if not intervals.is_empty() else null,"rendered_frame_max_ms":intervals[-1] if not intervals.is_empty() else null}
 FileAccess.open(OUT+"gameplay-"+DisplayServer.get_name()+".json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("MOUNTAIN_KING_RESULT ",JSON.stringify(report))
 game.queue_free();await frames(3);DirAccess.remove_absolute(cfg);quit(1 if failures else 0)
