extends "res://tests/forest-shrine/beast_master_test.gd"

const KazSkins=preload("res://scripts/kaz_skins.gd")
const SpriteArt=preload("res://scripts/crossgate_sprite_art.gd")
const Mirrors=preload("res://scripts/warcraft_mirrors.gd")
const CROSSGATE_ROOT="res://assets/characters/crossgate/"
const PREPARED_ROOT=CROSSGATE_ROOT+"weapons/beast_master/"
const WEAPON_ITEM="weapon:beast-master"
const LEGACY_ROUTES=[Vector2i(35,0),Vector2i(36,0),Vector2i(37,900050),Vector2i(39,105178)]
const COPY_ROUTES=[Vector2i(34,KazSkins.DEFAULT),Vector2i(38,106707)]
const CAPTURE_ROUTES={Vector2i(48,120386):"bei-recovered",Vector2i(48,109876):"bei-fallback"}
const CAPTURE_OUT="res://build/Other Files/Asset Toolkit/Beast Master Skins/"

var shots:Array=[]

func read_profile(folder:String)->Dictionary:
 var data=JSON.parse_string(FileAccess.get_file_as_string(folder+"motions.json"))
 if not data is Dictionary:return {}
 if FileAccess.file_exists(folder+"art.json"):
  var art=JSON.parse_string(FileAccess.get_file_as_string(folder+"art.json"))
  if not SpriteArt.apply(folder,data,art).is_empty():return {}
 return data

func prepared_frames(clip:Dictionary,pages:Array[String],checked_pages:Dictionary)->bool:
 var frames_:Array=clip.get("frames",[])
 if frames_.is_empty():return false
 for frame in frames_:
  if not SpriteArt.valid_frame(frame,pages.size()):return false
  var page:int=int(frame[0])
  if not checked_pages.has(page):
   if not ResourceLoader.exists(pages[page],"Texture2D"):return false
   checked_pages[page]=true
 return true

func available_clips(character:int,skin:int,route:Dictionary)->bool:
 var native=route.has("native")
 var maze=character==Gear.Roster.MAZE_ID
 var folder:String=route.get("root","")
 if native:
  if not Gear.Roster.has_crossgate_throws(character) or route.native!=Gear.Roster.MazeWeapon.KUNAI:return false
  folder=CROSSGATE_ROOT+"maze/" if maze else Gear.Roster.skin_root(character,skin)
 if folder.is_empty():return false
 var profile=read_profile(folder)
 if profile.is_empty():return false
 var pages=SpriteArt.paths(folder,profile)
 var cast_clock:Dictionary=read_profile(CROSSGATE_ROOT+"kazi/").get("clips",{}) if maze else profile.clips
 var cast_prefix="dagger:6:" if native else "6:"
 var throw_prefix="7:" if native else "5:"
 var checked_pages={}
 for direction in 8:
  var cast:Dictionary=profile.clips.get(cast_prefix+str(direction),{})
  var clock:Dictionary=cast_clock.get("6:%d"%direction,{})
  var throw:Dictionary=profile.clips.get(throw_prefix+str(direction),{})
  if clock.get("duration",0.0)<=0.0 or not prepared_frames(cast,pages,checked_pages) or not prepared_frames(throw,pages,checked_pages):return false
  var duration:float=throw.get("duration",0.0)
  var release:float=throw.get("release",-1.0)
  if native:release=duration*float(profile.get("release_frame",-1))/throw.frames.size()
  if not is_finite(release) or release<=0.0 or release>=duration:return false
  if not native and (throw.get("draw",-1.0)<0.0 or throw.draw>release):return false
 return true

func check_catalog()->Array[Vector2i]:
 var catalog=Gear.catalog()
 var prepared:Array[Vector2i]=[]
 var appearance_count=0
 for character in Gear.Roster.CROSSGATE:
  var skins=Gear.Roster.skin_catalog(character).keys()
  if character==Gear.Roster.KAZI_ID:skins.erase(KazSkins.MAZE)
  if character==Gear.Roster.SHIN_SPECIAL_ID:skins.append_array(Gear.Roster.ShinSkins.HIDDEN_CLASSIC)
  if skins.is_empty():skins=[0]
  var registered:Dictionary=catalog.get(str(character),{})
  check(skins.size()==registered.size(),"All appearances are registered for Cross Gate identity %d"%character)
  for skin in skins:
   appearance_count+=1
   var appearance={Gear.Roster.skin_setting(character):skin}
   var route:Dictionary=Gear.allowed(character,appearance).get("beast-master",{})
   var label="%d/%d"%[character,skin]
   check(Gear.can_equip(Gear.character_key(character),WEAPON_ITEM,appearance) and route.get("base_weapon","")=="kunai","%s equips Beast Master as a dagger"%label)
   check(available_clips(character,skin,route),"%s has prepared cast and dagger release frames in all eight facings"%label)
   if route.get("root","").begins_with(PREPARED_ROOT):
    check(route.root==PREPARED_ROOT+"%d-%d/"%[character,skin],"%s uses its own prepared appearance"%label)
    prepared.append(Vector2i(character,skin))
 check(appearance_count==349 and prepared.size()==40,"The complete matrix covers 349 appearances and 40 newly prepared routes")
 return prepared

func choose_appearance(appearance:Vector2i):
 var character=appearance.x
 var skin=appearance.y
 var player=game.player
 if character==Gear.Roster.KAZI_ID or character==Gear.Roster.MAZE_ID:
  game.select_kaz_skin(KazSkins.MAZE if character==Gear.Roster.MAZE_ID else skin)
 player.select_character(character)
 if Gear.Roster.is_shin(character):game.select_shin_skin(character,skin)
 elif Gear.Roster.has_variant_skins(character):game.select_crossgate_skin(character,skin)

func equip_appearance(appearance:Vector2i)->bool:
 choose_appearance(appearance)
 var character=appearance.x
 var player=game.player
 var loadout={Gear.character_key(character):{"1":WEAPON_ITEM}}
 var saved:bool=game.save_equipment_loadouts(loadout,game.settings.skill_item_loadouts,game.settings.cosmetic_loadouts)
 var ready:bool=saved and player.character_id==character and Gear.Roster.selected_skin(character,game.settings)==appearance.y and player.model.beast_master
 check(ready,"Saved and equipped Beast Master on %s"%appearance)
 return ready

func cast_case(appearance:Vector2i):
 var player=game.player
 player.active_ability.cancel(true)
 player.model.clear_beast_cast()
 var mana_before:float=player.mana
 var instances_before:int=player.spell_loadout.instances.size()
 press(1);animate_hero()
 var bindings:Array=player.spell_loadout.numbered_slots
 check(bindings.size()==6 and bindings.all(func(slot):return slot.size()>1 and slot[1]=="pet_attack"),"%s exposes pet commands on the six numbered bindings"%appearance)
 check(player.model.current_clip.begins_with("6:") and player.model.beast_cast_left>0.0,"%s plays its cast pose for the accepted pet command"%appearance)
 check(player.mana==mana_before and player.spell_loadout.instances.size()==instances_before and player.spell_loadout.current==null,"%s casting gesture neither spends mana nor casts a spell"%appearance)
 army.recall_beast_pets()

func capture(stem:String):
 await frames(3)
 await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(CAPTURE_OUT+stem+".png")==OK,"Captured "+stem)

func dagger_case(actor:Hero,label_:String,capture_stem:String=""):
 var kit=actor.active_ability
 kit.cancel(true)
 actor.attack_chain.reset()
 actor.impact_pause=0.0;actor.velocity=Vector3.ZERO;actor.facing=Vector3.FORWARD
 actor.accessory_bonuses.attack=123.0;actor.powerups.damage=1.0
 shots.clear()
 kit.start_basic_attack(actor.facing)
 var pattern:Dictionary=actor.model.normal_attack_pattern()
 check(pattern.contacts.size()==1 and pattern.projectiles==1 and int(kit.clip)==pattern.pose,label_+" starts one dagger throw")
 for tick in 180:
  kit.tick(DT)
  if shots.size()==1 and not capture_stem.is_empty():
   animate_hero()
   await capture(capture_stem+"-release")
   capture_stem=""
  if kit.mode.is_empty():break
 check(shots.size()==1,label_+" releases exactly one pooled dagger")
 if shots.size()==1:
  var shot=shots.front()
  check(shot.pool_live and shot.hero==actor and shot.kind in ["maze_dagger","water_dragon_dagger"],label_+" uses the shared dagger pool")
  check(is_equal_approx(shot.damage,Skills.BASIC_ATTACK_DAMAGE*actor.base_character_attack_multiplier()),label_+" uses base damage with bonuses active")
 for shot in shots:
  if shot.pool_live:shot.retire()
 actor.accessory_bonuses.erase("attack");actor.powerups.damage=0.0
 kit.cancel(true)

func copy_case(appearance:Vector2i):
 var player=game.player
 var mirrors=Mirrors.new(player,0)
 var echo=mirrors.make_body(appearance.x,true)
 echo.copy_from(player)
 var same_throw:bool=echo.model.beast_master and echo.model.gear_route==player.model.gear_route and echo.model.atlases[0]==player.model.atlases[0] and echo.model.fighter.strike=="throw"
 check(same_throw,"Mirror Image copies the equipped dagger route and appearance for %s"%appearance)
 check(not echo.spell_loadout.beast_master_equipped() and not echo.spell_loadout.numbered_slots.any(func(slot):return slot.size()>1 and slot[1]=="pet_attack"),"Mirror Image preserves the copy’s ordinary spell bindings")
 if same_throw:
  echo.global_position=player.global_position
  await dagger_case(echo,"Mirror Image %s"%appearance)
 mirrors.dispose()

func run():
 create_timer(240).timeout.connect(func():printerr("BEAST_MASTER_SKINS_TIMEOUT");quit(1))
 var prepared=check_catalog()
 cfg="/tmp/beast-master-skins-%d.cfg"%OS.get_process_id()
 var rendered=DisplayServer.get_name()!="headless"
 if rendered:DirAccess.make_dir_recursive_absolute(CAPTURE_OUT)
 root.size=Vector2i(1280,800)
 root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new()
 doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.set_process(false);game.set_physics_process(false);game.player.set_physics_process(false)
 game.camera_rig.set_process(false);game.camera_rig.set_physics_process(false)
 army=game.army_runtime
 army.set_process(false);army.set_physics_process(false)
 check(game.playing and not game.paused and game.model.phase=="wave","Appearance checks run during an isolated live wave")
 if not game.playing or game.paused or game.model.phase!="wave":
  await finish();return
 army.clear();game.model.enemies.clear();game.model.waves.patrol_posts.clear()
 check(game.save_pet_loadout([Pets.key(SKINS[0])],{}),"Saved one pet for casting across the appearance matrix")
 var home=Vector3(-100,0,100)
 home.y=game.model.surface_height(home.x,home.z)
 game.player.position=home
 game.training_dummy.home=home+Vector3.DOWN*1000;game.training_dummy.position=game.training_dummy.home
 var pool=Pool.service(game)
 pool.launched.connect(func(shot):shots.append(shot);shot.set_physics_process(false))
 for appearance in prepared+LEGACY_ROUTES:
  if not equip_appearance(appearance):continue
  game.player.position=home
  var capture_stem:String=CAPTURE_ROUTES.get(appearance,"") if rendered else ""
  if not capture_stem.is_empty():
   var camera:Camera3D=game.camera_rig.camera
   camera.global_position=home+Vector3(4,5.5,10)
   camera.look_at(home+Vector3.UP)
   camera.reset_physics_interpolation()
  cast_case(appearance)
  if not capture_stem.is_empty():
   for frame in 10:animate_hero()
   await capture(capture_stem+"-cast")
  game.player.model.clear_beast_cast()
  await dagger_case(game.player,"Appearance %s"%appearance,capture_stem)
  if appearance in COPY_ROUTES:await copy_case(appearance)
  await process_frame
 if equip_appearance(COPY_ROUTES[0]):
  var created:int=pool.created
  var misses:int=pool.misses
  for repeat in 8:await dagger_case(game.player,"Warm Kaz throw %d"%[repeat+1])
  check(pool.created==created and pool.misses==misses,"Repeated Beast Master throws reuse the warmed projectile pool")
 await finish()

func finish():
 army.clear()
 game.sound_library.cancel();game.music.stop();game.queue_free();current_scene=null;paused=false
 await frames(4)
 DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("BEAST_MASTER_SKINS_RESULT checks=",checks," failures=",failures)
 quit(1 if failures else 0)
