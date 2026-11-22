extends "res://tests/forest-shrine/crossgate_blast_coverage_test.gd"

const Pool=preload("res://scripts/character_projectile_pool.gd")
const ELEMENTS=["kazi/fire","kazi/ice","kazi/wind","kazi/meteor"]
const EVIDENCE="res://build/Other Files/Asset Toolkit/Elemental Casting/"
var caption:Label

func picture(name_:String,title:String):
 if DisplayServer.get_name()=="headless":return
 caption.text=title
 await process_frame;await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(EVIDENCE+name_+".png")==OK,"Captured "+name_)

func run():
 create_timer(240).timeout.connect(func():printerr("ELEMENTAL_CASTING_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(EVIDENCE);root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 var p=game.player;var army=game.army_runtime
 game.set_process(false);army.set_process(false);army.set_physics_process(false)
 game.camera_rig.set_process(false);game.camera_rig.set_physics_process(false);game.forest_ui.hide()
 for node in [game,p,game.camera_rig,game.forest_ui]:node.set_process_input(false);node.set_process_unhandled_input(false)
 root.gui_disable_input=true
 home.y=game.model.surface_height(home.x,home.z)+.05;game.model.update_vision(home)
 game.training_dummy.position=home+Vector3.DOWN*1000
 game.camera_rig.camera.global_position=home+Vector3(5,4,9);game.camera_rig.camera.look_at(home+Vector3.UP*2)
 var overlay=CanvasLayer.new();root.add_child(overlay);caption=Label.new();caption.position=Vector2(30,25);overlay.add_child(caption)
 var pool=Pool.service(game);var samples=[]
 for fighter in p.RogueRoster.CROSSGATE:
  p.select_character(fighter);fresh();p.position=home;game.model.team_progression.reset()
  var stances=p.model.appearance.get("weapons",[]).size()+1
  for stance in stances:
   if p.model.can_swap_stance():p.model.select_stance(stance)
   check(p.model.motions.clips.has("6:0"),"Fighter %d stance %d has its own casting clip"%[fighter,stance])
   for id in ELEMENTS:
    var spell=p.spell_loadout._instance(id);var skill=spell.controller
    for level_ in [1,10,19,30]:
     Skills.set_level(p,id,level_);p.spell_loadout.cancel();skill.clear_cooldowns();skill.start_cast();p.spell_loadout.current=spell
     check(skill.charge_fx.global_position.is_equal_approx(p.global_position),"Element starts at the caster's feet")
     var pattern=p.model.normal_attack_pattern()
     check(skill.native_pattern.contacts==pattern.contacts,"Casting presentation preserves consecutive elemental contacts")
     p.spell_loadout.tick(DT)
     check(p.model.current_clip.begins_with("6:"),"Fighter %d stance %d %s level %d casts instead of striking"%[fighter,stance,id,level_])
     check(skill.charge_fx.global_position.is_equal_approx(p.global_position),"Element remains grounded after the native update")
     if fighter==35 and stance==0 and level_==30:
      skill.set_charge_frame(6)
      await picture("uru-"+id.get_slice("/",1)+"-tier4","Uru • "+id+" • largest charge tier")
     if level_==1:
      for tick in 170:
       var started=Time.get_ticks_usec();p.spell_loadout.tick(DT);samples.append(Time.get_ticks_usec()-started)
       if skill.is_attacking():
        check(p.model.current_clip.begins_with("6:"),"Casting continues through the release timeline")
       if fighter==35 and stance==0 and id=="kazi/ice" and tick in [4,10,20,34,55,80]:
        await picture("uru-ice-%03d"%tick,"Uru ice casting • frame %d"%tick)
       if tick==10 and stance==0 and id=="kazi/ice":await picture("fighter-%d"%fighter,"%s • elemental casting"%p.RogueRoster.CROSSGATE[fighter].name)
       if not skill.is_attacking():break
     skill.cancel(true)
  p.spell_loadout.cancel()
 # Native allies use the same spell presentation and prepared pools.
 p.select_character(35);fresh();p.position=home
 var mirrors=preload("res://scripts/warcraft_mirrors.gd").new(p,0)
 for i in 5:check(mirrors.reinforce(35,home+Vector3((i-2)*3,0,-3)),"Native Uru ally is available")
 for body in mirrors.bodies:body.spell_loadout._instance("kazi/ice")
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT);var misses=pool.misses
 for repeat in 3:
  for body in mirrors.bodies:
   body.spell_loadout.cancel();var spell=body.spell_loadout._instance("kazi/ice")
   spell.controller.clear_cooldowns();spell.controller.start_cast();body.spell_loadout.current=spell
  for tick in 170:
   for body in mirrors.bodies:
    body.spell_loadout.tick(DT)
    if tick==10:
     check(body.model.current_clip.begins_with("6:") and body.spell_loadout.current.controller.charge_fx.global_position.is_equal_approx(body.global_position),"Simultaneous native allies cast with grounded charges")
   if repeat==0 and tick==10:await picture("five-uru-allies","Five native allies • ice casting")
  for body in mirrors.bodies:body.spell_loadout.cancel()
  if repeat==0:
   await frames(3)
   nodes=get_node_count();resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 check(pool.misses==misses,"Repeated simultaneous casts have no pool misses")
 print("ELEMENTAL_CAST_REUSE nodes=",nodes," -> ",get_node_count()," resources=",resources," -> ",Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
 check(get_node_count()==nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources,"Warmed repeated casts retain no extra nodes or resources")
 samples.sort();print("ELEMENTAL_CAST_STEP_US p95=",samples[floori(samples.size()*.95)]," max=",samples.back())
 mirrors.dispose();game.queue_free();overlay.queue_free();paused=false;await frames(3)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("ELEMENTAL_CASTING_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
