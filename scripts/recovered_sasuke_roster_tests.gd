extends SceneTree
## Missing roster registration would make the recovered character unreachable.
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
	game.settings_path="user://sasuke-roster-%s.cfg"%OS.get_process_id()
	root.add_child(game);current_scene=game;await frames(4)
	check(game.player.ROSTER.has(16),"Sasuke is registered as a separate playable fighter")
	if not game.player.ROSTER.has(16):
		game.queue_free();await frames(2);quit(1);return
	game.begin_forest()
	var card=game.find_child("RogueFighter_sasuke",true,false)
	check(card!=null,"The fighter gallery exposes Sasuke with his own portrait and controls")
	game.choose_rogue_character(16)
	var p=game.player
	check(p.character_id==16 and game.selected_rogue_id==16,"Choosing Sasuke equips and remembers him")
	check(p.active_ability!=null and p.active_ability.active,"Sasuke has a live combat controller")
	check(p.model.get_meta("original_sasuke",false),"Playable Sasuke uses his native ROM body")
	p.hp=p.max_hp*.4;p.select_character(1);p.select_character(16)
	check(is_equal_approx(p.hp/p.max_hp,.4),"Switching to Sasuke preserves the existing health fraction")
	var Balance=load("res://scripts/character_balance.gd")
	check(Balance.key_for(16)=="sasuke" and Balance.name_for(16)=="Sasuke","Sasuke balance has a separate persistent profile")
	game.show_character_balance(true,16)
	var picker=game.menu.find_child("BalanceCharacter",true,false)
	check(picker!=null and picker.get_selected_id()==16,"Sasuke can edit his own profile in the shared balance editor")
	game.sound_library.select_character(16)
	check(game.sound_library.character_id==16 and game.sound_library.character_key(16)=="sasuke","Sasuke has an isolated sound recording profile")
	check(not game.sound_library.moves_for(16).is_empty(),"Sasuke action sounds appear in Sound Studio")
	p.select_character(1)
	check(not p.character_abilities[16].active and not p.character_abilities[16].is_attacking(),"Switching away retires Sasuke's combat state")
	game.queue_free();current_scene=null;await frames(3)
	print("SASUKE_ROSTER_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
