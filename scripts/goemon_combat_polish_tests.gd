extends "res://scripts/recovered_goemon_pipe_hitbox_tests.gd"
var damage_labels:Array[int]=[]
func key(code:int,down:bool=true,echo_:bool=false):
 var event=InputEventKey.new();event.physical_keycode=code;event.keycode=code;event.pressed=down;event.echo=echo_
 root.push_input(event,true);await frames(1)
func run():
 await setup_fixture()
 raw_motion=JSON.parse_string(FileAccess.get_file_as_string("res://assets/characters/recovered_goemon/motion.json"))
 game.child_entered_tree.connect(func(node):
  if node is Label3D and node.text.is_valid_int():damage_labels.append(int(node.text)))
 var p=game.player;var dummy=game.training_dummy
 var collision:CollisionShape3D=dummy.get_children().filter(func(c):return c is CollisionShape3D)[0]
 collision.shape.radius=.03;collision.shape.height=.06;collision.position=Vector3.ZERO;dummy.contact_shape.center=Vector3.ZERO
 reset_strike();pose_fixture(1,4)
 await target_at(raw_pipe_point(1,4,Vector3(23,-3,78)));p.strike()
 check(damage_labels==[66],"A real first Gold Pipe hit deals66 damage, three times its former22")
 damage_labels.clear();reset_strike(3);pose_fixture(3,7);p.attack_heavy=true
 await target_at(raw_pipe_point(3,7,Vector3(23,-3,78)));p.strike()
 check(damage_labels==[144],"A real heavy Gold Pipe hit deals144 damage, three times its former48")
 fresh();p.select_weapon(2)
 var ticket=p.attack_chain.make_ticket("coin");ticket["move_audio"]={"character_id":1,"move_key":"coin","voiced":true}
 var coin=game.spawn_gold_coin(ORIGIN+Vector3.UP*2,Vector3.FORWARD,false,false,1,false,0,ticket)
 check(is_equal_approx(coin.damage,60),"Goemon ryo snapshots three times its former20 damage")
 coin.queue_free()
 p.select_character(2)
 check(is_equal_approx(p.damage_multiplier(),1),"Edo keeps his existing damage multiplier")
 p.select_character(15)
 check(is_equal_approx(p.damage_multiplier(),3),"Ben keeps his existing damage multiplier")
 p.select_character(1)
 reset_strike();pose_fixture(1,4)
 var tip=raw_pipe_point(1,4,Vector3(23,-3,78))
 var outward=(tip-raw_pipe_point(1,4,Vector3(23,-3,77))).normalized()
 await target_at(tip+outward*.15);p.strike()
 check(contacts==[1],"A near-edge target just beyond the expanded tip receives forgiving pipe contact")
 reset_strike();pose_fixture(1,4);await target_at(tip+outward*.6);p.strike()
 check(contacts.is_empty(),"Pipe contact padding does not become a distant radial attack")
 fresh();p.select_weapon(1)
 await key(KEY_2)
 check(p.weapon_slot==2 and p.attack_left>0,"Pressing2 immediately starts a ryo throw without a mouse attack")
 var shot=p.attack_ticket
 await key(KEY_2,true,true);await key(KEY_2,false)
 check(p.attack_ticket==shot,"Key repeat and release do not restart the ryo throw")
 await step(45)
 check(p.weapon_slot==1 and p.attack_left<=0,"The temporary ryo action returns to the previously equipped pipe")
 fresh(true);p.select_weapon(1);await key(KEY_2)
 check(p.weapon_controls.charging and p.attack_left<=0,"Holding2 while golden starts the original coin charge")
 for code in [KEY_4,KEY_5]:await key(code);await key(code,false)
 check(p.weapon_controls.charging,"Inactive4/5 leave a held golden ryo charge unchanged")
 await step(121);await key(KEY_2,false)
 check(not p.weapon_controls.charging and p.attack_charged,"Releasing2 after a full hold starts the charged coin throw")
 await step(45)
 check(p.weapon_slot==1,"The charged number-key throw restores the pipe afterward")
 fresh();p.select_weapon(1);await key(KEY_3);await key(KEY_3,false)
 check(p.chain_pipe_combat.active and p.chain_pipe_combat.mode=="throw","Pressing3 immediately throws the original chain pipe")
 await step(90)
 check(p.weapon_slot==1 and not p.chain_pipe_combat.active,"Chain throw returns to the pipe after completion")
 fresh();p.select_weapon(1);await key(KEY_1);await key(KEY_1,false)
 check(p.attack_left>0 and not p.attack_charged and p.combo==1,"Pressing1 starts the original three-hit pipe combo")
 await step(160)
 check(p.combo==3 and p.attack_left<=0,"The direct pipe key completes all three original strikes")
 fresh();p.select_weapon(1)
 var button=game.forest_ui.loadout_buttons[1]
 button.button_down.emit();button.pressed.emit();button.button_up.emit()
 check(p.weapon_slot==2 and p.attack_left>0,"Clicking the ryo hotbar icon immediately performs its weapon action")
 await step(45)
 check(p.weapon_slot==1,"The clicked ryo action restores the previous weapon")
 fresh(true);p.select_weapon(1);button.button_down.emit();await step(121)
 check(p.weapon_controls.charging,"Holding the ryo hotbar button also charges while golden")
 button.pressed.emit();button.button_up.emit()
 var released=p.attack_ticket
 button.button_up.emit()
 check(p.attack_charged and p.attack_left>0 and p.attack_ticket==released,"Hotbar release casts one charged coin without a second click action")
 game.queue_free();paused=false;await frames();await create_timer(.15).timeout
 if FileAccess.file_exists(cfg):DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg))
 print("GOEMON_COMBAT_POLISH_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
