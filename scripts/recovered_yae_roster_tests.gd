extends SceneTree
## Catches an imported Yae who cannot be selected or lacks persistent profiles.
var checks=0
var failures=0
var game
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
	checks+=1
	if not ok:failures+=1
	print("PASS: " if ok else "FAIL: ",label_)
func frames(n:int):
	for i in n:await physics_frame
func run():
	game=load("res://scenes/forest_title.tscn").instantiate()
	game.settings_path="user://yae-roster-%s.cfg"%OS.get_process_id()
	root.add_child(game);current_scene=game;await frames(4)
	game.sound_library.folder="user://yae-roster-%s-sounds"%OS.get_process_id()
	game.sound_library.config_path="user://yae-roster-%s-sound.cfg"%OS.get_process_id()
	check(game.player.ROSTER.has(17),"Yae is reachable as a separate playable fighter")
	if not game.player.ROSTER.has(17):
		game.queue_free();await frames(2);quit(1);return
	game.begin_forest()
	var card=game.find_child("RogueFighter_yae",true,false)
	check(card!=null,"The fighter gallery exposes Yae with her own portrait and controls")
	game.choose_rogue_character(17)
	var p=game.player
	check(p.character_id==17 and game.selected_rogue_id==17,"Choosing Yae equips and remembers her")
	check(p.active_ability!=null and p.active_ability.active,"Yae selection activates her combat controller")
	check(p.model.get_meta("original_yae",false),"Playable Yae uses her native ROM body")
	p.hp=p.max_hp*.4;p.select_character(1);p.select_character(17)
	check(is_equal_approx(p.hp/p.max_hp,.4),"Switching to Yae preserves the existing health fraction")
	var Balance=load("res://scripts/character_balance.gd")
	check(Balance.key_for(17)=="yae" and Balance.name_for(17)=="Yae","Yae balance has a separate persistent profile")
	game.show_character_balance(true,17)
	var picker=game.menu.find_child("BalanceCharacter",true,false)
	check(picker!=null and picker.get_selected_id()==17,"Yae can edit her own profile in the shared balance editor")
	game.sound_library.select_character(17)
	check(game.sound_library.character_id==17 and game.sound_library.character_key(17)=="yae","Yae has an isolated sound recording profile")
	var moves=game.sound_library.moves_for(17)
	check(moves.has("primary_1") and moves.has("primary_3") and moves.has("secondary") and moves.has("utility"),"Yae combat sounds appear as named moves in Sound Studio")
	check(not moves.has("mermaid") and not moves.has("flute"),"Yae's excluded exploration abilities are absent from the combat catalog")
	game.forest_ui.sync()
	check(game.forest_ui.hero_name.text=="Yae" and game.forest_ui.hero_portrait.texture!=null,"The in-game HUD identifies Yae with her native portrait")
	p.select_character(1)
	check(not p.character_abilities[17].active and not p.character_abilities[17].is_attacking(),"Switching away retires Yae's combat state")
	game.queue_free();current_scene=null;await frames(3)
	print("YAE_ROSTER_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
