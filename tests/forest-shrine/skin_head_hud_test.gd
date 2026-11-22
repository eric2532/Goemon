extends SceneTree
const Roster=preload("res://scripts/rogue_roster.gd")
const OUT="res://build/Other Files/Asset Toolkit/Model HUD Heads/Gameplay/"
var entries:Array=[]
var checks=0
var failures=0
var game
func check(ok:bool,message:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+message)
func _initialize():run.call_deferred()
func frames(n:int=3):
 for i in n:await process_frame
func run():
 DirAccess.make_dir_recursive_absolute(OUT)
 for character in Roster.CROSSGATE:
  var catalog=Roster.skin_catalog(character)
  if catalog.is_empty():
   entries.append({"character":character,"skin":0,"name":Roster.name_for(character),"label":"Original","source":Roster.selection_portrait_path(character)})
  for skin in catalog:
   var path=Roster.ShinSkins.root(skin)+"portrait.png" if Roster.is_shin(character) else Roster.skin_root(character,skin)+"portrait.png"
   if character==Roster.KAZI_ID:path=catalog[skin][1].resource_path
   entries.append({"character":character,"skin":skin,"name":Roster.name_for(character),"label":catalog[skin][0],"source":path})
 for entry in entries:entry["body_pixels"]=preload("res://scripts/character_proportions.gd").crossgate_body_pixels(entry.character,entry.skin)
 var file=FileAccess.open(OUT+"catalog.json",FileAccess.WRITE);file.store_string(JSON.stringify(entries,"  "));file.close()
 if "--catalog" not in OS.get_cmdline_user_args():
  await verify_gameplay();return
 if DisplayServer.get_name()!="headless":
  root.size=Vector2i(1040,1200);root.content_scale_size=Vector2i.ZERO
  for character in Roster.CROSSGATE:
   var family=entries.filter(func(entry):return entry.character==character)
   var board=ColorRect.new();board.color=Color("28221d");board.size=Vector2(1040,1200);root.add_child(board)
   for i in family.size():
    var entry=family[i];var at=Vector2(12+(i%5)*204,10+(i/5)*170)
    var image=TextureRect.new();image.texture=load(entry.source);image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;image.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;image.position=at;image.size=Vector2(196,132);board.add_child(image)
    var label=Label.new();label.text="%d · %s"%[entry.skin,entry.label];label.position=at+Vector2(0,134);label.add_theme_font_size_override("font_size",12);board.add_child(label)
   await frames();await RenderingServer.frame_post_draw
   assert(root.get_texture().get_image().save_png(OUT+"source-%d.png"%character)==OK)
   board.queue_free();await frames()
 print("SKIN_HEAD_CATALOG entries=",entries.size());quit()

func verify_gameplay():
 create_timer(300).timeout.connect(func():printerr("SKIN_HEAD_HUD_TIMEOUT");quit(1))
 var Heads=preload("res://scripts/forest/painted_heads.gd")
 check(Heads.routes.values().all(func(path):return path.begins_with("model/")),"Every Cross Gate HUD head comes from the original model")
 var presets=ConfigFile.new();presets.load("res://export_presets.cfg")
 for section in presets.get_sections():
  if presets.get_value(section,"name","")=="Painterly Preview macOS":check("assets/ui/portraits/crossgate/model-heads.json" in presets.get_value(section,"include_filter","").split(","),"Painterly app delivery includes skin portrait routes")
 check(Heads.routes.size()>=entries.size(),"Portrait routes cover selections while preserving hidden saved appearances")
 for entry in entries:
  var key=str(entry.character)+((":"+str(entry.skin)) if entry.skin else "")
  check(Heads.routes.has(key) and ResourceLoader.exists(Heads.ROOT+str(Heads.routes.get(key,""))),"Original model head exists for "+key)
 if failures:quit(1);return
 root.size=Vector2i(1320,1080);root.content_scale_size=Vector2i.ZERO
 game=load("res://scenes/forest_shrine.tscn").instantiate();game.settings_path="user://skin-head-hud-%d.cfg"%OS.get_process_id();root.add_child(game);current_scene=game;await frames()
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 var ui=game.forest_ui;ui.set_process(false);game.model.team_progression.cards_enabled=false;game.model.team_progression.award_kills(16)
 for character in Roster.CROSSGATE:
  game.player.select_character(character)
  var family=entries.filter(func(entry):return entry.character==character)
  root.size=Vector2i(1320,maxi(1080,38+ceili(family.size()/5.0)*200));await frames(1)
  var layer=CanvasLayer.new();layer.layer=100;root.add_child(layer)
  var board=ColorRect.new();board.color=Color("28221d");board.size=Vector2(root.size);layer.add_child(board)
  var title=Label.new();title.text=Roster.name_for(character)+" · model / matching HUD head";title.position=Vector2(20,5);title.add_theme_font_size_override("font_size",20);board.add_child(title)
  for i in family.size():
   var entry=family[i]
   if character==Roster.KAZI_ID:game.select_kaz_skin(entry.skin)
   elif Roster.is_shin(character):game.select_shin_skin(character,entry.skin)
   elif Roster.has_variant_skins(character):game.select_crossgate_skin(character,entry.skin)
   ui.sync();await frames(1)
   var key=Roster.loadout_key(character,game.settings);var expected=Heads.ROOT+str(Heads.routes[key])
   check(ui.hero_portrait.texture!=null and ui.hero_portrait.texture.resource_path==expected,"HUD selects matching skin head for "+key)
   check(ui.hero_portrait.material==null and ui.hero_portrait.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST and ui.hero_portrait.texture.get_size()==Vector2(256,256),"Head keeps alpha and bounded import for "+key)
   check(ui.hero_portrait.texture.get_image().get_used_rect().position.y==8,"Portrait shares the circle-top alignment for "+key)
   check(ui.team_level_label.text=="2","Skin switch preserves shared XP for "+key)
   if entry.skin:
    if character==Roster.KAZI_ID and entry.skin==preload("res://scripts/kaz_skins.gd").MAZE:
     check(game.player.character_id==Roster.MAZE_ID and game.player.model.appearance.id==entry.skin,"Maze uses its prepared model under Kaz's skin choice")
    else:check((game.player.model.kaz_skin if character==Roster.KAZI_ID else game.player.model.shin_skin if Roster.is_shin(character) else game.player.model.variant_skin)==entry.skin,"Actual model matches HUD skin "+key)
   var at=Vector2(10+(i%5)*262,38+(i/5)*200)
   var source=TextureRect.new();source.texture=load(entry.source);source.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;source.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED;source.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;source.position=at;source.size=Vector2(110,150);board.add_child(source)
   var frame=TextureRect.new();frame.texture=ui.skin.texture("portrait_frame");frame.position=at+Vector2(118,12);frame.size=Vector2(128,128);frame.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;board.add_child(frame)
   var head=ui.hero_portrait.duplicate();head.position=at+Vector2(126,20);head.size=Vector2(110,110);board.add_child(head)
   var label=Label.new();label.text="%d · %s"%[entry.skin,entry.label];label.position=at+Vector2(0,157);label.size.x=252;label.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS;label.add_theme_font_size_override("font_size",12);board.add_child(label)
  if DisplayServer.get_name()!="headless":
   await frames();await RenderingServer.frame_post_draw
   check(root.get_texture().get_image().save_png(OUT+"matched-%d.png"%character)==OK,"Captured source/head comparison for "+str(character))
  layer.queue_free();await frames()
 var nodes=int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT));var resources=int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
 var cached=Heads.textures.duplicate()
 for repeat in 10:
  for entry in entries:
   var settings=game.settings.duplicate();var setting=Roster.skin_setting(entry.character)
   if not setting.is_empty():settings[setting]=entry.skin
   check(Heads.portrait(entry.character,settings)==cached[Heads.routes[Roster.loadout_key(entry.character,settings)]],"Reuses cached selected head")
 check(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT))==nodes and int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))==resources,"Repeated head selections retain no extra nodes/resources")
 var path=game.settings_path;game.sound_library.cancel();game.music.stop();game.queue_free();paused=false;await frames(4);DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
 print("SKIN_HEAD_HUD_RESULT checks=%d failures=%d combinations=%d unique_heads=%d"%[checks,failures,entries.size(),Heads.textures.size()]);quit(1 if failures else 0)
