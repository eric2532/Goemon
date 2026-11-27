extends "res://tests/forest-shrine/equipment_hub_test.gd"
const ACCESSORY_OUT="res://build/Other Files/Asset Toolkit/Accessories/"
const NUMBERS=[22,23,72,78,207,217,231,241,262,263,21817,21884]
var accessory_hits:Array=[]
var accessory_timings:Array=[]

func outfit(numbers:Array,weapon:String=""):
 var p=game.player;var slots={}
 if not weapon.is_empty():slots["1"]="weapon:"+weapon
 for i in numbers.size():slots[Gear.ACCESSORY_SLOTS[i]]="accessory:%d"%numbers[i]
 var saved=game.settings.gear_loadouts.duplicate(true)
 if slots.is_empty():saved.erase(Gear.character_key(p.character_id))
 else:saved[Gear.character_key(p.character_id)]=slots
 check(game.save_equipment_loadouts(saved,game.settings.skill_item_loadouts,game.settings.cosmetic_loadouts),"Save accessories %s for fighter %d"%[numbers,p.character_id])

func reset_case():
 var p=game.player
 p.spell_loadout.cancel(true);p.active_ability.cancel(true);p.active_ability.clear_cooldowns();p.attack_chain.reset()
 p.set_auto_attack(false);p.position=home;p.velocity=Vector3.ZERO;p.facing=Vector3.FORWARD;p.dodge_time=0;p.impact_pause=0
 p.hp=p.max_hp;p.mana=p.max_mana;game.army_runtime.clear();game.model.enemies.clear();game.army_runtime.refresh_kits()
 game.enemies=game.enemies.filter(func(enemy):return is_instance_valid(enemy) and not enemy.is_queued_for_deletion())
 for i in 8:
  p.velocity=Vector3(0,-3,0);p.move_and_slide()
 p.velocity=Vector3.ZERO
 game.crowd.army.presentation.clear();shots.clear();accessory_hits.clear()

func weapon_cue_after(order:int)->bool:
 return game.voices.any(func(voice):return voice.get_meta("order",-1)>order and voice.get_meta("kind","")=="swing")

func spell_case(id:String):
 var p=game.player;var skill=p.spell_loadout._instance(id).controller
 skill.cancel(true);skill.clear_cooldowns();p.attack_chain.reset();shots.clear();accessory_hits.clear()
 p.mana=p.max_mana
 var sound_order=game.voice_idx;var weapon_cue=false
 skill.start_cast()
 for tick in 240:
  skill.tick(DT)
  weapon_cue=weapon_cue or weapon_cue_after(sound_order)
  if not skill.is_attacking():break
 if skill.kind.is_empty():
  check(weapon_cue or skill.native_pattern.sounds.is_empty(),"Fighter %d %s keeps its physical weapon cues"%[p.character_id,id])
 else:check(not weapon_cue,"Fighter %d %s uses spell audio without weapon swings"%[p.character_id,id])
 return skill

func resolve_shots(ticks:int=300):
 for tick in ticks:
  var started=Time.get_ticks_usec()
  for shot in shots:
   if is_instance_valid(shot) and shot.pool_live:shot._physics_process(DT)
  game.army_runtime.flush_presentation();game.crowd.army.presentation.tick(DT)
  accessory_timings.append((Time.get_ticks_usec()-started)/1000.0)

func accessory_picture(stem:String):
 if DisplayServer.get_name()=="headless":return
 game.army_runtime.flush_presentation();game.forest_ui.sync()
 var fx=game.crowd.army.presentation
 for effect in fx.effects:
  if effect.kind=="shin_sure_strike":effect.age=5*fx.SURE_STRIKE_FRAME_TIME
 fx.draw_effects()
 await frames(3);await RenderingServer.frame_post_draw
 check(root.get_texture().get_image().save_png(ACCESSORY_OUT+stem+".png")==OK,"Captured "+stem)

func measured_speed(sprinting:bool)->float:
 var p=game.player
 reset_case();p.smoke_mode=true;p.smoke_move=Vector2.RIGHT
 if sprinting:Input.action_press("sprint")
 for tick in 90:
  p.position=home;p._physics_process(DT)
  await physics_frame
 var speed=Vector2(p.velocity.x,p.velocity.z).length()
 Input.action_release("sprint");p.smoke_move=Vector2.ZERO;p.velocity=Vector3.ZERO
 return speed

func speed_shoes():
 var p=game.player
 for character in p.RogueRoster.CROSSGATE:
  p.select_character(character);outfit([]);p.clear_food_buffs()
  var base=p.movement_multiplier();var flight=p.jump_style.flight_speed();var reach=p.melee_range_multiplier();var hp=p.max_hp
  outfit([21817]);Gear.apply(p);Gear.apply(p)
  check(is_equal_approx(p.movement_multiplier(),base*3) and is_equal_approx(p.jump_style.flight_speed(),flight*3),"Fighter %d shoes triple movement exactly once"%character)
  check(p.max_hp==hp and p.melee_range_multiplier()==reach,"Shoes preserve health and attack range")
  p.apply_food_buff("movement_speed")
  check(is_equal_approx(p.movement_multiplier(),base*3*1.2),"Shoes multiply the existing movement-food bonus")
  p.clear_food_buffs();outfit([])
  check(is_equal_approx(p.movement_multiplier(),base),"Unequipping shoes restores fighter %d movement"%character)
 p.select_character(43);outfit([])
 var walk=await measured_speed(false);var sprint=await measured_speed(true)
 check(walk>0 and sprint>walk,"Baseline walking and Shift sprint both move")
 outfit([21817])
 var fast_walk=await measured_speed(false);var fast_sprint=await measured_speed(true)
 check(is_equal_approx(fast_walk,walk*3) and is_equal_approx(fast_sprint,sprint*3),"Actual walking and Shift sprint velocities triple")
 game.load_settings();Gear.apply(p)
 check(p.accessory_bonuses.get("movement_speed")==3.0,"Saved shoes survive reload")
 var owner=Gear.character_key(43)
 check(not game.save_equipment_loadouts({owner:{"accessory:1":"accessory:21817","accessory:2":"accessory:21817"}},{},{}),"Duplicate shoes cannot stack")
 var warm_nodes=get_node_count();var warm_resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for cycle in 20:outfit([]);outfit([21817])
 check(get_node_count()==warm_nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=warm_resources,"Repeated shoe changes reuse warmed nodes and resources")
 print("SPEED_SHOES_MEASURED walk=%.3f equipped=%.3f sprint=%.3f equipped=%.3f"%[walk,fast_walk,sprint,fast_sprint])
 outfit([])

func run():
 create_timer(600).timeout.connect(func():printerr("ACCESSORY_EFFECTS_TIMEOUT");quit(1))
 DirAccess.make_dir_recursive_absolute(ACCESSORY_OUT);root.size=Vector2i(1280,800);root.set_flag(Window.FLAG_NO_FOCUS,true)
 var doc=load("res://scripts/forest/forest_map_document.gd").new();doc.load_wind_meadow()
 await setup_fixture(doc.data)
 game.set_process(false);game.army_runtime.set_process(false);game.army_runtime.set_physics_process(false)
 game.settings.disable_character_cooldowns=false;game.settings.forest_pet_loadout=[]
 game.model.waves.patrol_posts.clear();game.model.waves.crossgate_pet_test=true
 home=Vector3(40,0,60);home.y=game.model.surface_height(home.x,home.z)+.05;game.model.update_vision(home)
 game.training_dummy.home=home+Vector3.DOWN*1000;game.training_dummy.position=game.training_dummy.home
 game.camera_rig.camera.global_position=home+Vector3(8,9,21);game.camera_rig.camera.look_at(home+Vector3(0,2,-5))
 game.music.stop()
 for node in [game,game.player,game.camera_rig]:node.set_process_input(false);node.set_process_unhandled_input(false)
 var p=game.player;var pool=Pool.service(game)
 var provenance=JSON.parse_string(FileAccess.get_file_as_string("res://assets/ui/crossgate/accessories/provenance.json"))
 for source in provenance.choices:
  var texture:Texture2D=Gear.ITEMS[source.get("item","accessory:%d"%source.number)].icon
  var original=Image.load_from_file(texture.resource_path);original.convert(Image.FORMAT_RGBA8)
  var imported=texture.get_image();imported.convert(Image.FORMAT_RGBA8)
  check(FileAccess.get_sha256(texture.resource_path)==source.png_sha256 and imported.get_data()==original.get_data(),"Accessory #%d preserves original file and imported RGBA pixels"%source.number)
 await speed_shoes()
 pool.launched.connect(func(shot):shots.append(shot);shot.set_physics_process(false))
 game.army_runtime.record_events=true
 var figures=[]
 for character in p.RogueRoster.CROSSGATE:
  if character in [34,36]:game.settings.kaz_skin=preload("res://scripts/kaz_skins.gd").MAZE if character==36 else preload("res://scripts/kaz_skins.gd").DEFAULT
  p.select_character(character);outfit([]);reset_case()
  game.update_character_tuning(character,"critical_chance",0)
  game.update_character_tuning(character,"counter_chance",5)
  var base_reach=p.melee_range_multiplier();var base_hp=p.max_hp
  outfit([22,23,72,78])
  check(is_equal_approx(p.melee_range_multiplier(),base_reach*6),"Fighter %d stacks range to exactly six times"%character)
  check(is_equal_approx(p.max_hp,base_hp+1000),"Fighter %d receives exactly 1,000 bonus maximum health"%character)
  check(is_equal_approx(p.combat_tuning("counter_chance"),40),"Fighter %d gains 35 counterattack percentage points"%character)
  var unchanged_hp=p.hp;Gear.apply(p);Gear.apply(p)
  check(is_equal_approx(p.max_hp,base_hp+1000) and p.hp==unchanged_hp,"Reapplying gear cannot duplicate health or heal")
  game.update_character_tuning(character,"counter_chance",90)
  check(p.combat_tuning("counter_chance")==100,"Counterattack chance caps at 100 percent")
  game.update_character_tuning(character,"counter_chance",0)
  outfit([])
  check(is_equal_approx(p.max_hp,base_hp) and is_equal_approx(p.melee_range_multiplier(),base_reach),"Unequip removes cached stats for fighter %d"%character)
  # Each roster identity keeps its native contact pattern and prepared skill owner.
  reset_case();var enemy=spawn(Vector3(0,0,-10));var before=enemy.hp
  var moon_base=Skills.effective(p,"kazi/moon","count")
  outfit([207]);var moon=spell_case("kazi/moon")
  check(shots.size()==int(moon_base)+2,"Fighter %d gains exactly two moon waves across all native contacts"%character)
  var moon_contacts=p.model.normal_attack_pattern().contacts.size()
  check(shots.filter(func(shot):return shot.target==enemy).size()==mini(int(moon_base),moon_contacts)+2,"The extra moon waves can both hit a lone enemy")
  if character==43:
   var expected_moon=0.0
   for shot in shots:
    if shot.target==enemy:expected_moon+=shot.damage
   resolve_shots(8);await accessory_picture("moon-extra-waves")
   resolve_shots()
   check(is_equal_approx(before-enemy.hp,expected_moon),"Extra moon waves deliver their full real contact damage to a lone enemy")
  moon.cancel(true)
  reset_case();enemy=spawn(Vector3(0,0,-24 if character==43 else -10));before=enemy.hp
  outfit([263]);var wind=spell_case("kazi/wind")
  var contacts=p.model.normal_attack_pattern().contacts.size()
  check(shots.size()==11*contacts,"Fighter %d releases ten extra winds per native volley"%character)
  check(shots.all(func(shot):return shot.target==enemy),"Extra winds pursue the selected enemy instead of becoming harmless strays")
  check(shots.all(func(shot):return shot.position==shots[0].position and shot.velocity==shots[0].velocity),"The visual fan preserves the original projectile origin and homing trajectory")
  var extra_winds=shots.filter(func(shot):return not shot.wind_spread.is_zero_approx())
  check(extra_winds.size()==10*contacts and extra_winds.all(func(shot):return shot.start_delay<=.15),"All ten bonus winds start together in the visible fan")
  var lanes=[]
  for shot in extra_winds:
   if not lanes.has(shot.wind_spread):lanes.append(shot.wind_spread)
  check(lanes.size()==10,"Bonus winds have ten distinct left/right presentation lanes")
  resolve_shots(12)
  check(shots.all(func(shot):return is_equal_approx(shot.sprite.global_position.y,game.world.surface_height_at(shot.sprite.global_position)+.04)),"Every flying wind base follows ground height")
  if character==43:
   await accessory_picture("ten-extra-winds")
   resolve_shots(8);await accessory_picture("ten-extra-winds-midflight")
  resolve_shots()
  check(is_equal_approx(before-enemy.hp,11*(100*p.base_damage_multiplier()+p.base_magic_damage())),"Fighter %d extra winds deal their own four real pulses"%character)
  check(shots.all(func(shot):return not shot.pool_live),"Wind flights and their hit state finish cleanly")
  wind.cancel(true)
  outfit([]);wind=spell_case("kazi/wind")
  check(shots.size()==contacts and shots.all(func(shot):return shot.wind_spread==Vector3.ZERO and shot.sprite.position.x==0 and shot.sprite.position.z==0),"Unequipped pooled winds reset every fan lane")
  wind.cancel(true)
  reset_case();enemy=spawn(Vector3(0,0,-10));before=enemy.hp
  outfit([262]);var ice=spell_case("kazi/ice")
  check(shots.size()==contacts and shots.all(func(shot):return shot.ice_hit_count==10),"Fighter %d retains one ice effect per native contact with ten configured hits"%character)
  if character==43:
   resolve_shots(20);await accessory_picture("ten-hit-ice")
  resolve_shots()
  check(is_equal_approx(before-enemy.hp,10*(100*p.base_damage_multiplier()+p.base_magic_damage())/3.0),"Fighter %d Ice produces exactly ten contacts per effect"%character)
  check(shots.all(func(shot):return not shot.pool_live),"Repeated Ice animation retires after its last cycle")
  ice.cancel(true)
  var meteor=spell_case("kazi/meteor");meteor.cancel(true)
  reset_case();enemy=spawn(Vector3(0,0,-10));before=enemy.hp
  outfit([217]);Skills.set_level(p,"kazi/fire",30)
  var hotbar=p.spell_loadout._instance("kazi/fire").controller
  hotbar.cooldown=3.0
  var fire_sound_order=game.voice_idx;var fire_weapon_cue=false;var regular_cast=true
  p.active_ability.start_attack()
  check(game.last_sound_voice.get_meta("kind")=="cg_fire_charge" and game.last_sound_voice.stream==SoundLibrary.CROSSGATE_MAGIC_CAST,"Fighter %d Fire basic starts with the regular magic casting sound"%character)
  var basic=p.spell_loadout.current
  check(basic!=null and basic.spec.get("basic_attack",false),"Fighter %d basic attack enters the prepared Fire owner"%character)
  if basic!=null:
   check(basic.controller.ticket.skill_level==1 and basic.controller.ticket.skill_rules.base_damage==100,"Fire basic attack remains level one when Fire skill is level 30")
   check(basic.controller!=hotbar and basic.controller.pool_key!=hotbar.pool_key and hotbar.cooldown==3.0,"Fire basic attacks keep independent cooldowns and projectile leases")
   var elapsed=0
   var pictured=false
   for tick in 240:
    p.spell_loadout.tick(DT);elapsed+=1
    fire_weapon_cue=fire_weapon_cue or weapon_cue_after(fire_sound_order)
    if basic.busy():regular_cast=regular_cast and p.model.current_clip.begins_with("6:")
    if character==43 and not pictured and not shots.is_empty():
     pictured=true;shots.back()._physics_process(.3);await accessory_picture("fire-basic")
    if not basic.busy():break
   check(not fire_weapon_cue and regular_cast,"Fighter %d Fire basic keeps its regular casting animation without weapon audio"%character)
   resolve_shots()
   check(game.voices.any(func(voice):return voice.get_meta("order",-1)>fire_sound_order and voice.get_meta("kind","") in ["cg_fire_rise","cg_fire_hit"]),"Fighter %d Fire basic retains its original fire effect audio"%character)
   check(is_equal_approx(before-enemy.hp,100*p.base_damage_multiplier()+p.base_magic_damage()),"Fighter %d Fire replacement deals level-one damage without a normal strike"%character)
  Skills.set_level(p,"kazi/fire",1);p.spell_loadout.cancel(true);outfit([])
  figures.append({"character":character,"native_contacts":contacts})
  await frames()
 # Source selection, exclusivity, invalid saves and UI all use the existing hub.
 p.select_character(43);reset_case();outfit([241],"sword")
 p.active_ability.start_attack()
 check(p.active_ability.is_attacking() and p.active_ability.ticket.get("action","")!="lancelot_random_shot","The bow-only replacement leaves sword attacks intact")
 p.active_ability.cancel(true)
 for character in p.RogueRoster.CROSSGATE:
  if "bow" not in Gear.allowed(character,game.settings):continue
  p.select_character(character);outfit([],"bow");reset_case()
  var bow_enemy=spawn(Vector3(0,0,-10))
  Skills.set_level(p,Skills.Catalog.RANDOM_SHOT,1)
  p.spell_loadout._cast(Skills.Catalog.RANDOM_SHOT,"equip")
  var glow=p.model.combo_glow
  var regular_texture=glow.texture;var regular_scale=glow.scale;var regular_pixel_size=glow.pixel_size
  var regular_rules=p.active_ability.ticket.get("skill_rules",{}).duplicate()
  var regular_size=p.active_ability.ticket.get("skill_size",0)
  for tick in 240:p.active_ability.tick(DT)
  check(shots.size()==3,"Fighter %d regular level-one 亂射 releases three arrows"%character)
  var regular_damage=shots[0].damage if not shots.is_empty() else 0.0
  resolve_shots();outfit([241],"bow");reset_case();bow_enemy=spawn(Vector3(0,0,-10))
  Skills.set_level(p,Skills.Catalog.RANDOM_SHOT,30)
  var before=bow_enemy.hp
  p.active_ability.start_attack()
  check(p.active_ability.state.get("barrage_left",0)==3 and p.active_ability.ticket.get("skill_level",0)==1,"Fighter %d accessory starts exactly level-one 亂射 at learned level 30"%character)
  check(glow.visible and glow.texture==regular_texture and glow.scale.is_equal_approx(regular_scale) and glow.pixel_size==regular_pixel_size,"Fighter %d accessory matches the regular level-one flash art and size"%character)
  check(p.active_ability.ticket.get("skill_rules",{})==regular_rules and p.active_ability.ticket.get("skill_size",0)==regular_size,"Fighter %d accessory keeps the regular level-one rules"%character)
  check(p.active_ability.random_shot_cooldown==0,"Basic 亂射 does not consume the hotbar cooldown")
  if character in [37,43]:
   glow.frame=6;await accessory_picture("random-shot-level-one-%d"%character)
  for tick in 240:p.active_ability.tick(DT)
  check(shots.size()==3 and shots.all(func(shot):return shot.attack_ticket.get("skill_level",0)==1 and is_equal_approx(shot.damage,regular_damage)),"Fighter %d accessory releases three level-one arrows without an extra primary arrow"%character)
  resolve_shots()
  check(is_equal_approx(before-bow_enemy.hp,3*regular_damage),"Fighter %d accessory delivers exactly the regular level-one damage"%character)
  check(Skills.level_for(p,Skills.Catalog.RANDOM_SHOT)==30,"Accessory leaves the learned 亂射 level unchanged")
  Skills.set_level(p,Skills.Catalog.RANDOM_SHOT,1);outfit([])
 p.select_character(43)
 outfit([72],"bow");reset_case();var attacker=spawn(Vector3(0,0,-10))
 game.update_character_tuning(43,"counter_chance",65)
 check(p.active_ability.counter_after_hit(Vector3.BACK,attacker.forest_id,true) and not p.active_ability.shin_counter.is_empty(),"The +35-point bonus feeds the real basic counterattack owner")
 game.update_character_tuning(43,"counter_chance",0);p.active_ability.clear_shin_counter()
 for range_items in [[],[22,23]]:
  outfit(range_items,"sword");reset_case();var distant=spawn(Vector3(0,0,-18));var before=distant.hp
  p.ai_controlled=true;p.ai_aim=distant.global_position;p.active_ability.start_attack()
  for tick in 180:p.active_ability.tick(DT)
  p.ai_controlled=false
  check((distant.hp<before)==not range_items.is_empty(),"Six-times range reaches a real enemy beyond ordinary sword contact")
 outfit([231],"sword");reset_case();var primary=spawn(Vector3(0,0,-3));var flank=spawn(Vector3(4,0,-3));var out_of_range=spawn(Vector3(35,0,-3))
 var before_primary=primary.hp;var before_flank=flank.hp;var outside=out_of_range.hp
 var ticket=p.attack_chain.make_ticket("shin_sure_strike");ticket.sure_strike_size=Skills.BASE_DIAMETER
 primary.take_hit(250,Vector3.FORWARD,false,ticket)
 check(primary.hp<before_primary and flank.hp<before_flank and out_of_range.hp==outside,"乾坤 adds real local splash and leaves distant enemies untouched")
 check(is_equal_approx(before_primary-primary.hp,before_flank-flank.hp),"Explosion damage is not multiplied a second time")
 game.army_runtime.flush_presentation()
 await accessory_picture("sure-strike-splash")
 var owner=Gear.character_key(p.character_id)
 check(not game.save_equipment_loadouts({owner:{"accessory:1":"accessory:217","accessory:2":"accessory:241"}},{},{}),"Save validation rejects both primary replacements together")
 check(not game.save_equipment_loadouts({owner:{"accessory:1":"accessory:78","accessory:2":"accessory:78"}},{},{}),"A forged save cannot stack duplicates")
 check(not game.save_equipment_loadouts({Gear.pet_key(Pets.key(0)):{"accessory:1":"accessory:78"}},{},{}),"Character accessories cannot silently enter the native pet loadout")
 outfit([22,23,78]);var expected=game.settings.gear_loadouts.duplicate(true);game.load_settings();Gear.apply(p)
 check(game.settings.gear_loadouts==expected,"Numbered accessory choices survive save and reload")
 var settings_path=game.settings_path;game.settings_path="user://missing-accessory-folder/settings.cfg"
 check(not game.save_equipment_loadouts({},{},{}) and game.settings.gear_loadouts==expected,"Failed saves retain the previous loadout")
 game.settings_path=settings_path
 game.show_equipment_hub(true);await frames(3)
 var hub=game.equipment_hub;hub.show_page("accessories")
 check(hub.collection.size()==Gear.ITEMS.values().filter(func(item):return item.get("category","")=="accessories").size() and hub.collection.all(func(id):return Gear.ITEMS[id].icon!=null and not hub.describe(Gear.ITEMS[id]).is_empty()),"All accessory icons and effect descriptions appear")
 hub.selected_slot="accessory:5";hub.selected_item="accessory:21817";hub.equip_selected()
 check(p.accessory_bonuses.get("movement_speed")==3.0 and hub.accessory_buttons["accessory:5"].get_node("GearIcon").texture==Gear.ITEMS["accessory:21817"].icon,"The equipment UI equips the selected original shoes immediately")
 await accessory_picture("speed-shoes-equipped")
 hub.unequip()
 check(not p.accessory_bonuses.has("movement_speed"),"The equipment UI removes the shoe bonus immediately")
 hub.selected_slot="accessory:1";hub.selected_item="accessory:217";hub.equip_selected()
 hub.selected_slot="accessory:2";hub.selected_item="accessory:241";hub.equip_selected()
 check(hub.draft[owner].values().has("accessory:241") and not hub.draft[owner].values().has("accessory:217"),"Equipping 亂射 replaces Fire")
 expected=hub.draft.duplicate(true)
 check(game.settings.gear_loadouts==expected,"Accessories apply and save immediately")
 await accessory_picture("accessories-menu")
 game.back_from_equipment();await frames(3)
 check(game.settings.gear_loadouts==expected,"Back retains equipped accessories")
 check(not game.paused and game.playing,"Closing the in-game equipment hub resumes the cast fixture")
 # Five native ally bodies share the same prepared effects and exact damage.
 outfit([262,263],"bow");reset_case();var shared_enemy=spawn(Vector3(0,0,-10))
 var copies=preload("res://scripts/warcraft_mirrors.gd").new(p,0)
 for i in 5:check(copies.reinforce(43,home),"A simultaneous caster uses the native ally lifecycle")
 var copied_skills=[];var copied_damage=0.0
 for body in copies.bodies:
  body.ai_target=shared_enemy;body.ai_aim=shared_enemy.global_position;body.position=home
  check(body.accessory_bonuses.get("wind_extra",0)==10 and body.accessory_bonuses.get("ice_hits",0)==10,"Native copies inherit the saved accessory data")
  var controller=body.spell_loadout._instance("kazi/wind").controller
  copied_skills.append(controller);copied_damage+=11*(100*body.base_damage_multiplier()+body.base_magic_damage())
 var copy_nodes=0;var copy_resources=0;var copy_misses=pool.misses
 for cycle in 7:
  var before=shared_enemy.hp;shots.clear()
  var ally_sound_order=game.voice_idx;var ally_weapon_cue=false
  for controller in copied_skills:
   controller.hero.attack_chain.reset();controller.clear_cooldowns();controller.start_cast()
  for tick in 180:
   for controller in copied_skills:controller.tick(DT)
   resolve_shots(1)
   ally_weapon_cue=ally_weapon_cue or weapon_cue_after(ally_sound_order)
  check(not ally_weapon_cue,"Simultaneous native elemental casters do not play weapon swings")
  check(is_equal_approx(before-shared_enemy.hp,copied_damage),"Five simultaneous enhanced wind casts deal all expected hits")
  if cycle==1:
   await frames(3);copy_nodes=get_node_count();copy_resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 await frames(3)
 check(get_node_count()<=copy_nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=copy_resources and pool.misses==copy_misses,"Repeated simultaneous wind retains no warmed objects or pool misses")
 copied_skills=[];copied_damage=0.0
 for body in copies.bodies:
  copied_skills.append(body.spell_loadout._instance("kazi/ice").controller)
  copied_damage+=10*(100*body.base_damage_multiplier()+body.base_magic_damage())/3.0
 copy_misses=pool.misses
 for cycle in 3:
  var before=shared_enemy.hp;shots.clear()
  var ally_sound_order=game.voice_idx;var ally_weapon_cue=false
  for controller in copied_skills:
   controller.hero.attack_chain.reset();controller.clear_cooldowns();controller.start_cast()
  for tick in 240:
   for controller in copied_skills:controller.tick(DT)
   resolve_shots(1)
   ally_weapon_cue=ally_weapon_cue or weapon_cue_after(ally_sound_order)
  check(not ally_weapon_cue,"Simultaneous native elemental casters do not play weapon swings")
  check(is_equal_approx(before-shared_enemy.hp,copied_damage),"Five simultaneous Ice casts each produce exactly ten contacts")
 check(pool.misses==copy_misses,"Simultaneous ten-hit Ice uses the prepared native ally pools")
 copies.dispose();await frames(3)
 # Warm repeated casts before checking retained resources and pool misses.
 outfit([262,263],"bow");reset_case();spawn(Vector3(0,0,-10))
 for cycle in 2:
  spell_case("kazi/wind");resolve_shots();spell_case("kazi/ice");resolve_shots()
 await frames(3)
 var nodes=get_node_count();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT);var misses=pool.misses
 for cycle in 5:
  spell_case("kazi/wind");resolve_shots();spell_case("kazi/ice");resolve_shots()
 await frames(3)
 check(get_node_count()<=nodes and Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)<=resources and pool.misses==misses,"Repeated enhanced spells retain no warmed nodes/resources or pool misses")
 accessory_timings.sort()
 var report={"checks":checks,"failures":failures,"roster":figures,"step_ms_p95":accessory_timings[floori(accessory_timings.size()*.95)],"step_ms_max":accessory_timings.back(),"pool_misses":pool.misses,"rendered":DisplayServer.get_name()!="headless"}
 FileAccess.open(ACCESSORY_OUT+("headless" if DisplayServer.get_name()=="headless" else "desktop")+"-results.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
 print("ACCESSORY_EFFECTS_RESULT ",JSON.stringify(report))
 game.queue_free();current_scene=null;paused=false;await frames(4)
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 quit(1 if failures else 0)
