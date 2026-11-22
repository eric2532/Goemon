extends "res://scripts/recovered_goemon_gameplay_tests.gd"
## Retired shortcuts stay unbound while the HUD still shows the active weapon.
const Roster=preload("res://scripts/rogue_roster.gd")
const Gear=preload("res://scripts/forest/equipment.gd")

func key(code:Key):
 var event=InputEventKey.new()
 event.physical_keycode=code
 event.pressed=true
 Input.parse_input_event(event)
 var release=event.duplicate() as InputEventKey
 release.pressed=false
 Input.parse_input_event(release)
 Input.flush_buffered_events()

func check_weapon_icon(icon:Texture2D):
 var ui=game.forest_ui
 ui.sync_character()
 check(ui.ben_utility_tile.visible and not ui.utility_key.visible and ui.leader_utility_icon.texture==icon and ui.leader_utility_icon.texture_filter==CanvasItem.TEXTURE_FILTER_NEAREST,"The weapon tile shows %s with pixel filtering and no hotkey"%icon.resource_path.get_file())

func run():
 create_timer(90).timeout.connect(func():printerr("WEAPON_SWAP_TIMEOUT");quit(1))
 var doc=load("res://scripts/forest/forest_map_document.gd").new()
 doc.load_wind_meadow()
 await setup_fixture(doc.data)
 var p=game.player
 check(not InputMap.has_action("swap_weapon"),"The shared swap action is retired")
 check(not InputMap.has_action("cape_red") and not InputMap.has_action("cape_gold"),"The retired cape actions have no key bindings")
 check(game.forest_ui.find_child("CapeRed",true,false)==null and game.forest_ui.find_child("CapeGold",true,false)==null,"Neither cape button remains in the HUD")
 p.select_character(Roster.MAZE_ID)
 var weapon:int=p.model.maze_weapon
 key(KEY_Z)
 check(p.model.maze_weapon==weapon,"Z leaves Maze's active weapon alone")
 var maze_weapons=["sword","kunai","unarmed"]
 for i in maze_weapons.size():
  game.select_skin_weapon(Roster.MAZE_ID,i)
  check_weapon_icon(Gear.ITEMS["weapon:"+maze_weapons[i]].icon)
 game.select_skin_weapon(Roster.MAZE_ID,weapon)
 key(KEY_X)
 check(p.model.maze_weapon==weapon and not p.scarf_equipped and not p.gold_cloak,"X leaves the weapon and cape state alone")
 p.select_character(Roster.SHIN_ID)
 var stance:String=p.model.motions.weapon
 key(KEY_Z)
 check(p.model.motions.weapon==stance and not p.scarf_equipped,"Z leaves Shin's stance and cape alone")
 game.select_skin_weapon(Roster.SHIN_ID,game.skin_weapon_choices(Roster.SHIN_ID).find("Sword"))
 game.forest_ui.sync_character()
 check(game.forest_ui.ben_utility_tile.tooltip_text=="Sword","Shin's HUD names the active weapon")
 check_weapon_icon(Gear.ITEMS["weapon:sword"].icon)
 key(KEY_Q)
 var hub=game.equipment_hub
 check(is_instance_valid(hub),"Q opens Equipment during a wave")
 if is_instance_valid(hub):
  hub.auto_equip(hub.collection.find("weapon:polearm"))
  key(KEY_Q)
  check(p.model.gear_weapon=="polearm","Equipment selects Shin's spear")
  check_weapon_icon(Gear.ITEMS["weapon:polearm"].icon)
  key(KEY_Z)
  check(p.model.gear_weapon=="polearm","Z leaves the equipped spear alone")
 p.select_character(Roster.SHIN_SPECIAL_ID)
 game.forest_ui.sync_character()
 check(not game.forest_ui.ben_utility_tile.visible,"A fixed Shin Special skin has no weapon tile")
 game.settings.shin_special_skin=120440
 p.model.set_shin_skin(120440)
 check_weapon_icon(preload("res://assets/ui/crossgate/weapons/red-sword.png"))
 p.swap_weapon()
 check_weapon_icon(preload("res://assets/ui/crossgate/weapons/red-polearm.png"))
 p.swap_weapon()
 check_weapon_icon(preload("res://assets/ui/crossgate/weapons/red-sword.png"))
 p.select_character(Roster.KAZI_ID)
 key(KEY_Z)
 key(KEY_X)
 check(not p.scarf_equipped and not p.gold_cloak,"A fighter with one weapon gains neither cape")
 game.sound_library.cancel()
 game.music.stop()
 game.queue_free()
 paused=false
 await frames()
 print("UNIVERSAL_WEAPON_SWAP_RESULT checks=%d failures=%d"%[checks,failures])
 quit(1 if failures else 0)
