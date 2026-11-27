extends "res://tests/forest-shrine/explore_access_test.gd"
const Gear=preload("res://scripts/forest/equipment.gd")
const Nutrition=preload("res://scripts/forest/chest_food.gd")

func _initialize():
 create_timer(300).timeout.connect(func():printerr("BOSS_CHEST_TIMEOUT");quit(1));run.call_deferred()

func run():
 root.size=Vector2i(1280,800)
 game=load("res://scenes/forest_title.tscn").instantiate();game.settings_path="/tmp/crossgate-boss-chests-%d.cfg"%OS.get_process_id()
 root.add_child(game);current_scene=game;root.gui_disable_input=true
 for i in 4:await process_frame
 game.find_child("ForestFalan",true,false).pressed.emit();game.choose_rogue_character(game.player.RogueRoster.KAZI_ID)
 game.settings.forest_level_up_cards=false;game.equipment_hub.enter_button.pressed.emit()
 for i in 4:await physics_frame
 game.tuning.invincible=true;game.player.set_auto_attack(false)
 var loot=game.exploration_loot;loot.set_process(false)
 var accessories=Gear.ITEMS.keys().filter(func(id):return Gear.ITEMS[id].get("category","")=="accessories")
 game.settings.chest_swords=[];game.settings.sword_upgrades={};game.settings.accessory_drops={}
 check(Gear.sanitized_accessory_drops({"accessory:22":2,"weapon:SW016":3,"accessory:23":-1,"accessory:72":1.5})=={"accessory:22":2},"Collected accessories reject invalid IDs, negative and fractional counts")
 var party=game.settings.forest_pet_loadout
 game.settings.forest_pet_loadout=[];loot.reward_bag.clear()
 for cycle in 2:
  var found={}
  var eligible=(Nutrition.ITEMS.keys()+accessories).filter(loot.reward_eligible)
  for i in eligible.size():
   var id=loot.draw_reward();found[id]=found.get(id,0)+1
  check(not found.has("weapon") and eligible.all(func(id):return found.get(id,0)==1),"Regular reward bag has every eligible food/accessory once, no weapons")
 game.settings.forest_pet_loadout=party
 for id in accessories:
  loot.clear();loot.spawn_chest(0,game.player.position,"regular:"+id);loot.slots[0].reward=id
  press_f()
  check(game.settings.accessory_drops.get(id)==1 and not loot.slots[0].active,"Actual F collects regular accessory "+id)
 loot.clear();loot.spawn_chest(2,game.player.position,"stale-weapon")
 loot.slots[0].reward="weapon";loot.slots[0].sword="weapon:SW016";loot.reward_bag=[accessories[0]]
 press_f()
 check(game.settings.chest_swords.is_empty() and not loot.slots[0].has("sword") and loot.opened_chests.has("stale-weapon"),"Regular chest cannot grant a weapon even with stale injected contents")
 loot.sword_bag.clear();var found=[]
 for i in Gear.CHEST_WEAPONS.size():
  loot.clear();var key="earned:%d"%i
  check(loot.spawn_boss_chest(game.player.position,key) and not loot.spawn_boss_chest(game.player.position,key),"Earned victory spawns one chest")
  var slot:Dictionary=loot.slots[0];found.append(slot.sword);slot.bonus=accessories[i%accessories.size()]
  press_f()
  check(not slot.active and slot.sword in game.settings.chest_swords and loot.opened_chests.has(key),"Actual F saves guaranteed boss weapon and bonus")
  check(not loot.spawn_boss_chest(game.player.position,key),"Claimed boss chest never respawns")
 found.sort();var expected=Gear.CHEST_WEAPONS.duplicate();expected.sort()
 check(found==expected,"Nine boss victories cover every collectible weapon before bag refill")
 loot.clear();loot.spawn_boss_chest(game.player.position,"save-failure")
 var slot:Dictionary=loot.slots[0];var sword:String=slot.sword
 slot.bonus=accessories[0];loot.boss_contents["save-failure"].bonus=slot.bonus
 var before=game.settings.duplicate(true);var path=game.settings_path
 game.settings_path="user://missing-boss-chest-folder/preferences.cfg";press_f()
 check(slot.active and not loot.opened_chests.has(slot.key) and game.settings==before,"Failed write rolls back weapon, upgrade and accessory together")
 loot.clear();loot.spawn_boss_chest(game.player.position,"save-failure")
 check(loot.slots[0].sword==sword and loot.slots[0].bonus==accessories[0],"Re-entered arena restores identical unclaimed contents after failed save")
 game.settings_path=path;press_f();game.load_settings()
 check(loot.opened_chests.has("save-failure") and game.settings.sword_upgrades.get(sword)==1 and game.settings.accessory_drops[accessories[0]]==before.accessory_drops[accessories[0]]+1,"Retry saves one weapon upgrade and one accessory, surviving reload")
 # Exercise the actual original encounter and shared victory callback twice.
 await visit_source(11004,Vector2i(33,21))
 for victory in 2:
  var at:Vector2=Tour.Regions.Sites.HABARU_FORMATION[0]
  game.player.position=game.model.world_point(at+Vector2(0,5),.15);game.model.hero_position=game.player.position;game.player.reset_physics_interpolation()
  for i in 6:await physics_frame
  press_f();await drain()
  for i in 12:await physics_frame
  game.model.waves.tick(0.,game.player.position);game.army_runtime.import_arrivals();game.army_runtime.sync_compatibility()
  var party_members=game.model.enemies.values().filter(func(e):return e.has("habaru_slot"))
  check(party_members.size()==10,"Original dialogue/retry produces complete ten-member party")
  if victory==0:await access_capture("boss-chest-visible-habaru")
  var boss=party_members.filter(func(e):return e.get("boss",false))
  if not boss.is_empty():await defeat_ids([boss[0].id])
  game.explore_access._process(.2)
  check(loot.slots.all(func(s):return not s.active or not s.get("boss",false)),"Boss alone grants no weapon chest before retinue victory")
  await defeat_ids(party_members.map(func(e):return e.id));game.explore_access._process(.2)
  var chests=loot.slots.filter(func(s):return s.active and s.get("boss",false))
  check(chests.size()==1,"Full victory creates one boss chest")
  if not chests.is_empty():
   var chest:Dictionary=chests[0]
   check(game.army_runtime.native.can_reach_ally(game.player.position,chest.pos,.55*game.model.falan_scale),"Earned chest is on reachable arena ground")
   if victory==0:
    for i in 180:await physics_frame
    await access_capture("boss-chest-earned-habaru")
   await walk_toward(Vector2(chest.pos.x,chest.pos.z)/game.model.falan_scale,180)
   press_f()
   check(loot.opened_chests.has(chest.key),"Walk and F open boss chest alongside optional return portal")
  var portals=game.explore_access.pins().filter(func(p):return p.label.begins_with("◇ 返回法蘭"))
  check(portals.size()==1,"Looting keeps exactly one return portal")
  if not portals.is_empty():
   game.player.position=game.model.world_point(portals[0].at,.15);game.model.hero_position=game.player.position;game.player.reset_physics_interpolation()
   press_f()
   if is_instance_valid(game.dialogue) and game.dialogue.speaker=="回城傳送門":game.dialogue.chosen.emit("retry" if victory==0 else "return")
   for i in 8:await physics_frame
 check(Tour.area(game.model)=="city" and game.player.position.distance_to(game.model.world_point(game.explore_access.HOSPITAL_LANDING,.15))<.5,"Second victory portal returns outdoors to east hospital")
 var access=game.explore_access;var point=Vector2(game.player.position.x,game.player.position.z)/game.model.falan_scale
 var wall=StaticBody3D.new();wall.collision_layer=1;wall.collision_mask=0
 var collision=CollisionShape3D.new();var box=BoxShape3D.new();box.size=Vector3(80,12,80);collision.shape=box;wall.add_child(collision);game.add_child(wall);wall.position=game.player.position+Vector3.UP*5.
 await physics_frame
 var key=access.scope()+":unit:fixture-delayed";access.encounters[key]={"scope":access.scope(),"group":"unit:fixture-delayed","at":point,"name":"Fixture","cleared":false,"discovered":true,"pending":false}
 access.won(key,point)
 var delayed:Dictionary=access.encounters[key]
 check(delayed.get("portal_pending",false) and not delayed.has("chest"),"Temporary obstruction defers both return and loot instead of spawning them inside collision")
 wall.free();await physics_frame
 access._process(.2)
 check(delayed.has("portal") and delayed.has("chest") and not delayed.get("portal_pending",false),"Safe return and chest retry even when the arena visual container already exists")
 var chest_index=loot.slots.find_custom(func(s):return s.active and s.get("key","")==delayed.chest_key)
 if chest_index>=0:
  loot.slots[chest_index].pos=game.model.world_point(delayed.portal,.05)
  game.player.position=game.model.world_point(delayed.portal,.15);game.model.hero_position=game.player.position;game.player.reset_physics_interpolation()
  press_f()
  check(is_instance_valid(game.dialogue) and game.dialogue.pages[0].options.any(func(o):return o[0]=="loot"),"Overlapping loot and portal keep both actions available")
  if is_instance_valid(game.dialogue):game.dialogue.chosen.emit("loot")
  check(loot.opened_chests.has(delayed.chest_key),"Portal loot choice claims the same earned chest")
 print("BOSS_CHEST_RESULT checks=",checks," failures=",failures)
 finish()
