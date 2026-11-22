extends "res://scripts/recovered_goemon_gameplay_tests.gd"
const Skills=preload("res://scripts/spells/skill_balance.gd")
const Tiers=preload("res://scripts/spells/skill_effects.gd")
const Qi=preload("res://scripts/qigong_combat.gd")
const Element=preload("res://scripts/crossgate_element_projectile.gd")
const Pool=preload("res://scripts/character_projectile_pool.gd")
const OUT="res://build/Other Files/Asset Toolkit/BlueCG Downloaded Attack Skills/Level 30/"
var caption:Label

func picture(stem:String,title:String):
 if DisplayServer.get_name()=="headless":return
 caption.text=title;game.forest_ui.hide()
 var camera=game.camera_rig.camera
 var pose=camera.global_transform
 if "-impact-" in stem:
  camera.global_position+=Vector3(6,5,9)
  camera.look_at(pose.origin-pose.basis.z*25+Vector3.UP*3)
 await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(OUT+stem+".png")==OK,"Rendered "+stem)
 camera.global_transform=pose

func run():
 create_timer(180).timeout.connect(func():printerr("SHINE_TIERS_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(OUT);root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 var p=game.player;var state=game.model.team_progression
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.camera_rig.set_process(false);game.camera_rig.set_physics_process(false)
 for node in [game,p,game.camera_rig,game.forest_ui]:node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true
 var home=Vector3(0,0,60);home.y=game.model.world_height(home.x,home.z)+.05
 game.model.update_vision(home);game.training_dummy.position=home+Vector3.DOWN*1000
 game.camera_rig.camera.global_position=home+Vector3(14,10,18);game.camera_rig.camera.look_at(home+Vector3.UP*2)
 var overlay=CanvasLayer.new();root.add_child(overlay);caption=Label.new();caption.position=Vector2(30,25);caption.add_theme_font_size_override("font_size",24);overlay.add_child(caption)
 var pool=Pool.service(game)
 pool.launched.connect(func(shot):shot.set_physics_process(false))
 var misses=pool.misses
 for fighter in p.RogueRoster.CROSSGATE:
  p.select_character(fighter);fresh();p.position=home;p.velocity=Vector3.ZERO;state.reset()
  for id in [Qi.ID,Qi.MAZE_QI,Qi.MOON_ID,"kazi/fire","kazi/wind","kazi/ice","kazi/meteor"]:
   var kit=p.spell_loadout._instance(id).controller
   for level_ in [1,9,10,18,19,27,28,29,30]:
    Skills.set_level(p,id,level_);kit.cancel();kit.clear_cooldowns();p.mana=p.max_mana;kit.start_cast()
    var tier=Skills.Levels.shine_tier(level_)
    var ref:String=(Tiers.PHYSICAL_SHINES if id in [Qi.ID,Qi.MAZE_QI,Qi.MOON_ID] else Tiers.ELEMENT_SHINES)[tier]
    var visual_scale=Element.VISUAL_SCALE if not kit.kind.is_empty() else 1.0
    check(kit.charge_fx.visible and kit.charge_fx.scale==Vector3.ONE*visual_scale and kit.charge_fx.texture==Tiers.textures[ref],"Fighter %d %s level %d shine scale"%[fighter,id,level_])
    check(is_equal_approx(kit.ticket.skill_size,Skills.rules_for(p,id).get("size",1.0)),"Impact size keeps its original rule")
    if fighter==34 and id in [Qi.ID,"kazi/fire"]:
     kit.set_charge_frame(6)
     if id=="kazi/fire" and level_==29:check(kit.charge_fx.offset.y==17.5,"Largest elemental flare uses its real baseline rather than stray pixels")
     if level_==30:
      kit.set_charge_frame(10.5 if id=="kazi/fire" else 8.5)
      check(kit.charge_fx.frame==(13 if id=="kazi/fire" else 11),"The full EX charge animation fits the existing windup")
      kit.set_charge_frame(6)
     await picture(id.replace("/","-")+"-%02d"%level_,"%s   Lv %d   Original %s"%[id,level_,ref])
    if not kit.kind.is_empty():
     var spec=Tiers.element(kit.kind,tier)
     for variant in spec.targets.size():
      var height=kit.caster_height()*Qi.EFFECT_SIZE*Qi.ELEMENT_RELEASE_SCALE
      var shot=pool.launch(p,Element,id,{"kind":kit.kind,"position":home+Vector3(0,0,-3),"effect_tier":tier,"effect_height":height,"burst_index":variant,"attack_ticket":kit.ticket,"cast_hits":[{},{},{},{}]})
      var target_ref:String=spec.targets[variant];var row=Tiers.clip(target_ref)
      check(shot.sprite.texture==Tiers.textures[target_ref] and shot.tier_clip==row,"Fighter %d %s Lv%d variant %d uses original target %s"%[fighter,id,level_,variant,target_ref])
      if level_==30:
       check(shot.combat_clip==Tiers.clip(Tiers.element(kit.kind,3).targets[variant]),"EX art retains the ordinary damage geometry and clock")
      var pixels=140.0 if kit.kind=="meteor" else float(Element.BODY_PIXELS[kit.kind])
      check(is_equal_approx(shot.sprite.pixel_size,height/pixels),"Element tier retains source pixel density")
      check(shot.sprite.scale.is_equal_approx(Vector3.ONE*Element.VISUAL_SCALE*Skills.factor(kit.ticket,"size")),"Every elemental tier applies the shared visual enlargement once on pooled reuse")
      check(is_equal_approx(shot.effect_height,height) and shot.skill_factor("hit_area")==Skills.factor(kit.ticket,"hit_area"),"Visual enlargement preserves combat height and hit-area tuning")
      if shot.echo_sprite!=null:check(shot.echo_sprite.scale.is_equal_approx(shot.sprite.scale),"Elemental trails and impacts use the same visual enlargement")
      if kit.kind=="wind":
       shot.position.y+=1.5;shot.set_wind_anchor()
       check(is_equal_approx(shot.sprite.global_position.y,game.world.surface_height_at(shot.sprite.global_position)+.04) and shot.sprite.offset.y==float(row.frame_bounds[0][3] if tier==4 else row.height)-float(row.height)*.5 and shot.sprite.billboard==BaseMaterial3D.BILLBOARD_FIXED_Y,"Every Wind tier stands on its painted base at ground height")
      if kit.kind=="ice":
       shot.position.y+=1.5
       var grounded=true
       for frame in int(row.frames):
        shot.set_ice_anchor(frame)
        grounded=grounded and is_equal_approx(shot.sprite.global_position.y,game.world.surface_height_at(shot.sprite.global_position)+.04)
        if tier==4 or frame>=Element.ICE_CRACK_CENTER.size():grounded=grounded and shot.sprite.offset.y==float(row.frame_bounds[frame][3])-float(row.height)*.5
       check(grounded,"Every Ice frame keeps its crack or crystal base on the ground")
       shot.set_ice_anchor(0)
      if fighter==34 and level_ in [29,30] and variant==0:
       kit.charge_fx.hide()
       shot.sprite.frame=int(row.hit_frames[0]) if not row.hit_frames.is_empty() else mini(6,int(row.frames)-1)
       if tier==4 and kit.kind=="fire":shot.sprite.frame=8
       if tier==4 and kit.kind=="ice":shot.sprite.frame=14
       if kit.kind=="ice":shot.set_ice_anchor(shot.sprite.frame)
       if kit.kind=="meteor":shot.age=Element.METEOR_FALL;shot.step_meteor()
       if kit.kind=="wind":shot.velocity=Vector3.ZERO
       await picture(kit.kind+"-impact-%02d"%level_,"%s target   Lv %d   Original %s"%[kit.kind,level_,target_ref])
      shot.retire()
    kit.cancel()
 p.select_character(p.RogueRoster.LANCELOT_ID);fresh();state.reset()
 for level_ in [1,10,19,30]:
  Skills.set_level(p,"lancelot/random-shot",level_);p.active_ability.start_charge("lancelot_random_shot")
  check(p.model.combo_glow.texture==Tiers.textures[Tiers.PHYSICAL_SHINES[Skills.Levels.shine_tier(level_)]],"Archer uses the original charge sheet at level %d"%level_)
  p.active_ability.cancel(true)
 p.select_character(37);fresh();p.position=home;p.velocity=Vector3.ZERO;state.reset()
 for row in [["shin/sure-strike","shin_sure_strike",1],["shin/double-edge","shin_sure_strike",2],["shin/two-birds","shin_two_birds",2],["shin/combo","kazi_combo",1],["bee/blink-flurry","kazi_combo",1],["saizo/assassination","kazi_combo",1]]:
  p.model.select_stance(row[2])
  for level_ in [1,9,10,18,19,27,28,29,30]:
   p.active_ability.cancel(true);Skills.set_level(p,row[0],level_);p.spell_loadout.casting_id=row[0];p.active_ability.start_charge(row[1]);p.spell_loadout.casting_id=""
   var glow=p.model.combo_glow;var cell=glow.texture.get_size()/Vector2(glow.hframes,glow.vframes)
   var tier=Skills.Levels.shine_tier(level_)
   var ref:String=Tiers.PHYSICAL_SHINES[tier]
   var expected=Skills.BASE_DIAMETER*[91.0,168.0,272.0,357.0,357.0][tier]/357.0
   if row[1]=="kazi_combo":expected*=p.combat_tuning("combo_charge_size")
   check(glow.texture==Tiers.textures[ref] and is_equal_approx(maxf(cell.x,cell.y)*glow.pixel_size*glow.global_basis.get_scale().x,expected),"Native shine boundary %s %d"%[row[0],level_])
   if row[0]=="shin/sure-strike" and level_ in [1,10,19,30]:
    glow.frame=6;await picture("sure-strike-%02d"%level_,"乾坤   Lv %d   Original %s"%[level_,ref])
 p.active_ability.cancel(true)
 var heal=p.spell_loadout._instance("uru/recovery").controller
 for level_ in [1,9,10,18,19,27,28,29,30]:
  Skills.set_level(p,"uru/recovery",level_);p.mana=p.max_mana;heal.start_recovery()
  check(heal.effect.scale==Vector3.ONE and heal.effect.texture==Tiers.textures[Tiers.recovery(Skills.Levels.shine_tier(level_)).cast],"Recovery casting shine level %d"%level_)
  heal.tick(heal.WINDUP)
  check(heal.effect.scale==Vector3.ONE and heal.tier==Skills.Levels.shine_tier(level_) and heal.effect.texture==Tiers.textures[Tiers.recovery(heal.tier).target],"Recovery arrival circle matches the original casting tier")
  if level_ in [29,30]:
   heal.tick(heal.ARRIVAL_TRAVEL+4.0/30)
   await picture("recovery-target-%02d"%level_,"Recovery   Lv %d   Original %s"%[level_,Tiers.recovery(heal.tier).target])
  heal.tick(heal.ARRIVAL_DURATION)
 p.model.select_stance(1);Skills.set_level(p,"shin/sure-strike",19)
 Skills.set_modifier(p,"shin/sure-strike","shine-test",{"size":.5});state.skill_food_stacks=20
 var ticket=p.attack_chain.make_ticket("shin_sure_strike")
 check(is_equal_approx(Skills.shine_factor(ticket),3.0),"Shine keeps additive item size and food multipliers")
 Skills.set_level(p,"shin/sure-strike",1);Skills.set_modifier(p,"shin/sure-strike","shine-test",{});state.skill_food_stacks=0
 check(is_equal_approx(Skills.shine_factor(ticket),3.0) and is_equal_approx(Skills.shine_factor(p.attack_chain.make_ticket("shin_sure_strike")),1.0),"Existing casts retain shine snapshots; new casts read current level and bonuses")
 check(Skills.shine_factor({"skill_size":2.0})==2.0,"Unlevelled effects retain their existing size")
 var remembered=p.model.combo_glow.texture
 Skills.set_level(p,"shin/sure-strike",30)
 check(p.model.combo_glow.texture==remembered,"Level changes do not swap the artwork of an existing cast")
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for i in 100:
  p.active_ability.start_charge("shin_sure_strike");p.active_ability.cancel(true)
 check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Repeated shines reuse the same nodes and resources")
 check(pool.misses==misses,"Original target tiers use prepared projectiles without pool misses")
 print("SHINE_TIERS_RESULT checks=%d failures=%d"%[checks,failures])
 game.queue_free();overlay.queue_free();paused=false;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)
