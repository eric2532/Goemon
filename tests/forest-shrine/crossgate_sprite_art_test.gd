extends "res://tests/forest-shrine/dodge_counter_stats_test.gd"

const Model=preload("res://scripts/crossgate_model.gd")
const Art=preload("res://scripts/crossgate_sprite_art.gd")
const SHIN="res://assets/characters/crossgate/shin/900050/"
const BOOMERANG=SHIN+"boomerang/"
var originals={}

func prepare_fixture(folder:String,action:int)->bool:
 var path=folder+"art.json"
 if FileAccess.file_exists(path):
  printerr("Art swap fixture requires an unused path: ",path)
  return false
 var base:Dictionary=Model.profile(folder)
 originals[folder]=base
 var replacements={}
 var pages:Array=[]
 pages.resize(base.pages)
 pages.append("atlas-0.png")
 for facing in 8:
  var key="%d:%d"%[action,facing]
  var frames:Array=base.clips[key].frames.duplicate(true)
  for frame in frames:
   if frame[0]==0:frame[0]=base.pages
   frame[5]+=4
  replacements[key]=frames
 var data={"pages":pages,"stances":[replacements]}
 var file=FileAccess.open(path,FileAccess.WRITE)
 if file==null:return false
 file.store_string(JSON.stringify(data));file.close()
 Model.profiles.erase(folder)
 var routed:Dictionary=Model.profile(folder)
 var removed=DirAccess.remove_absolute(path)==OK
 return removed and routed.has("art_pages")

func timing(profile:Dictionary,key:String)->Dictionary:
 var result:Dictionary=profile.clips[key].duplicate()
 result.erase("frames")
 return result

func run():
 create_timer(120).timeout.connect(func():printerr("SPRITE_ART_TIMEOUT");quit(1))
 if not prepare_fixture(SHIN,0) or not prepare_fixture(BOOMERANG,5):quit(1);return
 var profile:Dictionary=Model.profile(BOOMERANG)
 var invalid={"stances":[{"5:0":[]}]}
 var before:Dictionary=profile.duplicate(true)
 check(not Art.apply(BOOMERANG,profile,invalid).is_empty() and profile==before,"Wrong frame counts leave the complete profile intact")
 invalid={"stances":[{"5:0":profile.clips["5:0"].frames.duplicate(true)}]}
 invalid.stances[0]["5:0"][0][1]=100000
 check(not Art.apply(BOOMERANG,profile,invalid).is_empty() and profile==before,"An out of bounds crop leaves the complete profile intact")
 root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.set_process(false)
 var player=game.player
 player.select_character(37)
 game.select_shin_skin(37,900050)
 var model=game.player.model
 var direction_:int=model.direction()
 var idle="0:%d"%direction_
 model.show_pose(0,0,true)
 check(is_equal_approx(model.sprite.offset.x,float(originals[SHIN].clips[idle].frames[0][5])+float(model.sprite.region_rect.size.x)*.5+4),"Selecting Shin draws the adjusted idle artwork")
 check(game.save_equipment_loadouts({Gear.character_key(37):{"1":"weapon:boomerang"}},{},{}),"Equip the boomerang through the saved gear route")
 var attack="5:%d"%model.direction()
 var pattern:Dictionary=model.normal_attack_pattern()
 check(timing(model.motions,attack)==timing(originals[BOOMERANG],attack) and pattern.contacts==[originals[BOOMERANG].clips[attack].release],"Replacement weapon keeps the complete attack timing, release and audio data")
 check(model.current_weapon()=="boomerang" and model.atlases.size()==2 and pattern.attack.frames[0][0]==1,"The weapon route selects its replacement atlas page")
 model.show_pose(5,0,false)
 var offset:float=float(pattern.attack.frames[0][5])+float(pattern.attack.frames[0][3])*.5
 check(is_equal_approx(model.sprite.offset.x,offset),"The sprite uses the replacement frame position")
 model.show_shin_counter(player.global_position,pattern.attack,true)
 check(model.stat_counter_shadow.texture==model.sprite.texture and model.stat_counter_shadow.region_rect==model.sprite.region_rect,"The counter uses the same replacement frames")
 var kit=player.active_ability
 kit.clear_shin_counter()
 var pool=Pool.service(game)
 pool.launched.connect(func(shot):shots.append(shot))
 kit.start_attack()
 var rate:float=player.attack_speed_multiplier()
 kit.tick((float(pattern.contacts[0])-.001)/rate)
 check(shots.is_empty(),"The new art cannot launch a projectile before the release cue")
 kit.tick(.002/rate)
 check(shots.size()==1 and shots[0].kind=="crossgate_boomerang","The original release cue launches one boomerang")
 for shot in shots:shot.retire()
 kit.cancel(true)
 check(game.save_equipment_loadouts({},{},{}),"Clear the equipped weapon")
 check(model.native_root==SHIN and model.appearance==Model.profile(SHIN) and model.atlases.size()==4,"Unequipping restores the cached character art")
 print("SPRITE_ART_RESULT checks=%d failures=%d"%[checks,failures])
 game.queue_free();paused=false;await frames(3)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg));quit(1 if failures else 0)
