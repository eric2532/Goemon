extends "res://tests/forest-shrine/skill_weapon_requirements_test.gd"
const REVIEW="res://build/Other Files/Asset Toolkit/Shared Meditation/Original Tiers/"
const MeditationArt=preload("res://scripts/spells/skill_effects.gd")

func planted():
 super.planted()
 game.player.velocity=Vector3.DOWN*30;game.player.move_and_slide()

func press_meditation():
 game.player.mana=game.player.max_mana
 var event=InputEventKey.new();event.physical_keycode=KEY_1;event.pressed=true
 game.player._unhandled_input(event)
 event.pressed=false;game.player._input(event)

func review_picture(stem:String):
 if DisplayServer.get_name()=="headless":return
 game.forest_ui.sync();await frames(2);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(REVIEW+stem+".png")==OK,"Captured "+stem)

func finish_cast():
 var p=game.player
 for tick in 600:
  p.active_ability.tick(DT)
  p.model.animate(DT,0,true,0,0,false,0,false)
  if not p.active_ability.is_attacking():return
 check(false,"Meditation finishes within ten seconds")

func run():
 create_timer(240).timeout.connect(func():printerr("SHARED_MEDITATION_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(REVIEW);root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path=cfg;root.add_child(game);current_scene=game;await frames(3)
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false);game.camera_rig.set_process(false)
 game.settings.forest_pet_loadout=[];game.settings.disable_character_cooldowns=false
 game.begin_arena();game.choose_rogue_character(37);await frames(3)
 var hub=game.equipment_hub;hub.show_page("skills")
 check(hub.collection.has("skill:"+Catalog.MEDITATION),"明鏡止水 is a shared loadout choice")
 hub.selected_item="skill:"+Catalog.MEDITATION;hub.equip_selected()
 check(hub.skill_buttons.equip.get_node("GearIcon").texture==Catalog.KAZI_ICONS[Catalog.MEDITATION],"Inventory uses the existing meditation icon")
 check(Catalog.valid_loadouts(hub.spell_draft)==hub.spell_draft,"Selection survives saved-loadout validation")
 check(Skills.level_preview(Catalog.MEDITATION,30).contains("EX") and not Skills.level_preview(Catalog.MEDITATION,30).contains("impact size"),"Upgrade preview describes original artwork instead of percentage enlargement")
 await review_picture("inventory")
 hub.enter_map();await frames(3)
 var p=game.player;var fx=game.crowd.army.presentation
 home=Vector3(0,0,60);home.y=game.model.world_height(home.x,home.z)+.05
 var floor_=StaticBody3D.new();floor_.collision_layer=1
 var shape=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(30,1,30);shape.shape=box;floor_.add_child(shape);game.add_child(floor_);floor_.position=home+Vector3.DOWN*.55
 await physics_frame;await physics_frame
 game.model.update_vision(home);game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true
 if is_instance_valid(game.training_dummy):game.training_dummy.position=home+Vector3.DOWN*1000;game.training_dummy.home=game.training_dummy.position
 game.camera_rig.camera.global_position=home+Vector3(8,7,15);game.camera_rig.camera.look_at(home+Vector3(0,2,-4))
 var routes=0
 for character in Catalog.Roster.CROSSGATE:
  if character in [34,36]:game.settings.kaz_skin=preload("res://scripts/kaz_skins.gd").MAZE if character==36 else preload("res://scripts/kaz_skins.gd").DEFAULT
  p.select_character(character);p.set_auto_attack(false)
  check(p.spell_loadout.equip(character,"equip",Catalog.MEDITATION),"Fighter %d can equip meditation"%character)
  check(p.spell_loadout.equip(character,"surge",Catalog.MEDITATION),"The same skill can occupy another slot")
  for weapon in Gear.allowed(character,game.settings):
   for level_ in [1,10,19,30]:
    routes+=1;equip_weapon(character,weapon);planted();fx.tick(2.0)
    Skills.set_level(p,Catalog.MEDITATION,level_)
    var kit=p.active_ability;var model=p.model
    check(p.is_on_floor(),"Fighter %d %s starts grounded"%[character,weapon])
    p.hp=p.max_hp*.4;var before:float=p.hp;var fraction=.05+.01*(level_-1)
    press_meditation()
    check(kit.is_attacking() and kit.ticket.get("skill_id")==Catalog.MEDITATION and p.hp==before,"Fighter %d %s starts the shared cast before healing"%[character,weapon])
    check(not p.spell_loadout.instances.has("%d:%s"%[character,Catalog.MEDITATION]),"The existing fighter owns meditation without a donor")
    var tier=Skills.Levels.shine_tier(level_)
    var ref=["110183","110182","110181","110180","111017"][tier]
    var art=MeditationArt.clip(ref)
    check(model.combo_glow.visible and model.combo_glow.texture==MeditationArt.textures[ref] and model.combo_glow.hframes==7,"Shared casts use the correct original meditation drawing")
    check(kit.ticket.skill_level==level_ and is_equal_approx(kit.ticket.skill_healing,fraction),"Cast snapshots its level and healing fraction")
    var cell=model.combo_glow.texture.get_size()/Vector2(model.combo_glow.hframes,model.combo_glow.vframes)
    var diameter:float=maxf(cell.x,cell.y)*model.combo_glow.pixel_size*model.combo_glow.global_basis.get_scale().x
    check(is_equal_approx(diameter,Skills.BASE_DIAMETER*maxf(art.width,art.height)/342.0),"Original tiers keep one world size per source pixel")
    check(model.combo_glow.offset==Vector2(float(art.bounds[0])+float(art.width)*.5,-float(art.bounds[1])-float(art.height)*.5),"The source origin keeps every original drawing centered")
    check(game.last_sound_voice.stream==SoundLibrary.original_for(Catalog.Roster.SHIN_ID,"cg_shin_meditation"),"Shared cast uses the prepared original sound")
    check(p.spell_loadout.cooldown_for("equip")==10 and p.spell_loadout.cooldown_for("surge")==10,"Duplicate slots share the ten-second timer")
    kit.tick(DT);model.animate(DT,0,true,0,0,false,0,false)
    check(model.current_clip.begins_with("6:" if model.motions.clips.has("6:0") else "0:"),"The receiving fighter uses its own available casting pose")
    if character in [34,43] and weapon in ["sword","bow"]:await review_picture("cast-%d-%s-lv%d"%[character,weapon,level_])
    finish_cast()
    check(is_equal_approx(p.hp,before+(p.max_hp-before)*fraction) and not model.combo_glow.visible,"Completion restores the level-based missing HP and hides the effect")
    check(game.last_sound_voice.stream==SoundLibrary.original_for(Catalog.Roster.SHIN_ID,"cg_shin_meditation_heal"),"Completion uses the distinct original healing sound")
    var text=str(roundi(p.hp-before))
    check(fx.labels.any(func(label):return label.visible and label.text==text and label.font==fx.HEAL_FONT),"Existing pooled green digits show actual healing")
    if character==34 and weapon=="sword":await review_picture("healed-kaz-lv%d"%level_)
    var healed:float=p.hp;press_meditation()
    check(not kit.is_attacking() and p.hp==healed,"An early recast cannot heal again")
    kit.tick_timers(5);press_meditation()
    check(not kit.is_attacking() and p.spell_loadout.cooldown_for("equip")==5,"Meditation remains on cooldown at five seconds")
    kit.tick_timers(5);p.hp=p.max_hp*.8;before=p.hp;press_meditation();finish_cast()
    check(is_equal_approx(p.hp,before+(p.max_hp-before)*fraction) and p.hp<=p.max_hp,"A ready recast heals the new missing-health amount without exceeding maximum HP")
    planted();p.hp=p.max_hp*.4;before=p.hp;press_meditation();kit.tick(DT);kit.cancel(true);finish_cast()
    check(p.hp==before and not model.combo_glow.visible and p.spell_loadout.cooldown_for("equip")==10,"Interruption cancels healing and retains cooldown")
    planted();p.hp=0;press_meditation()
    check(not kit.is_attacking() and kit.shin_meditation_cooldown==0,"A defeated fighter cannot cast")
    p.hp=p.max_hp;planted();p.dodge_time=.2;press_meditation()
    check(not kit.is_attacking() and kit.shin_meditation_cooldown==0,"Dodge rejects a cast without spending cooldown")
    p.dodge_time=0;kit.clear_cooldowns()
  await frames(1)
 for character in [Catalog.Roster.SHIN_ID,Catalog.Roster.BOG_ID]:
  p.select_character(character);planted();p.hp=p.max_hp*.4;p.mana=p.max_mana
  Skills.set_level(p,Catalog.MEDITATION,30)
  var before:float=p.hp;p.active_ability.start_shin_meditation();finish_cast()
  check(is_equal_approx(p.hp,before+(p.max_hp-before)*.34),"The original native meditation entry still heals fighter %d"%character)
 p.select_character(34);planted();p.hp=p.max_hp*.4
 p.global_position+=Vector3.UP*4;p.velocity=Vector3.ZERO;p.move_and_slide();press_meditation()
 check(not p.active_ability.is_attacking() and p.active_ability.shin_meditation_cooldown==0,"An airborne fighter cannot spend a meditation cast")
 p.select_character(37);equip_weapon(37,"sword");planted();Skills.set_level(p,Catalog.MEDITATION,1)
 p.hp=p.max_hp*.4;press_meditation()
 var original=p.model.motions.clips["6:0"]
 check(is_equal_approx(p.active_ability.duration,original.duration) and is_equal_approx(p.active_ability.state.meditation_release,original.release),"Meditation retains the original casting duration and release marker")
 p.active_ability.tick(3.0/60)
 check(p.model.combo_glow.frame==1 and p.hp==p.max_hp*.4,"Original seven-frame art advances every two source ticks before healing")
 Skills.set_level(p,Catalog.MEDITATION,30);p.hp=p.max_hp*.2
 check(p.model.combo_glow.texture==MeditationArt.textures["110183"],"A level change retains the original drawing already casting")
 finish_cast()
 check(is_equal_approx(p.hp,p.max_hp*.24),"Released cast keeps level-one healing and reads missing HP at completion")
 planted();p.hp=p.max_hp;press_meditation();finish_cast()
 check(p.hp==p.max_hp,"Full health cannot produce overhealing")
 Skills.set_modifier(p,Catalog.MEDITATION,"fixture",{"healing":1.0,"size":.2});planted();p.hp=p.max_hp*.4
 press_meditation();var ticket=p.active_ability.ticket
 Skills.set_modifier(p,Catalog.MEDITATION,"fixture",{});finish_cast()
 check(ticket.skill_healing==1.0 and p.hp==p.max_hp and is_equal_approx(ticket.skill_size,1.2),"Existing item bonuses snapshot, clamp healing and multiply effect size")
 Skills.set_level(p,Catalog.MEDITATION,1);game.model.team_progression.stat_points=1
 game.show_status_panel();var panel=game.status_panel;panel.show_skills(true)
 check(not panel.skill_buttons[0].disabled and panel.skill_buttons[0].tooltip_text.contains("5% missing HP") and panel.skill_buttons[0].tooltip_text.contains("6% missing HP"),"The Skills panel exposes current and next meditation levels")
 panel.skill_buttons[0].pressed.emit();panel.refresh()
 check(Skills.level_for(p,Catalog.MEDITATION)==2 and game.model.team_progression.stat_points==0,"Meditation spends one shared point through the existing upgrade button")
 await review_picture("skill-upgrade")
 game.close_status_panel();await frames(2)
 p.select_character(34);equip_weapon(34,"sword");planted();p.hp=p.max_hp*.4
 for repeat in 2:press_meditation();finish_cast();p.active_ability.clear_cooldowns();p.hp=p.max_hp*.4
 await frames(3)
 var nodes=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT));var resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
 for repeat in 40:
  p.active_ability.clear_cooldowns();p.hp=p.max_hp*.4;press_meditation();finish_cast()
 await frames(3)
 var final_nodes=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT));var final_resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
 check(final_nodes<=nodes and final_resources<=resources,"Forty warmed casts retain no extra nodes/resources (%d/%d nodes, %d/%d resources)"%[final_nodes,nodes,final_resources,resources])
 game.queue_free();current_scene=null;paused=false;await frames(4);DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("SHARED_MEDITATION_RESULT routes=%d checks=%d failures=%d"%[routes,checks,failures]);quit(1 if failures else 0)
