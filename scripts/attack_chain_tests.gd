extends "res://scripts/direct_attack_tests.gd"
var shots: Array=[]

func observe_energy(node: Node):
	if node is GoldCoin and not node.hostile:shots.append(node)

func aim_camera():
	game.camera_rig.set_process(false)
	var point=game.player.global_position
	game.camera_rig.camera.global_position=point+Vector3(0,7,12)
	game.camera_rig.camera.look_at(point+Vector3(0,1,-7))

func clean():
	await fresh_robe(false);shots.clear();aim_camera()
	for effect in get_tree().get_nodes_in_group("combo_energy"):effect.queue_free()

func press_melee(action: String):
	var event=InputEventAction.new();event.action=action;event.pressed=true
	Input.parse_input_event(event);Input.flush_buffered_events()
	event=event.duplicate();event.pressed=false
	Input.parse_input_event(event);Input.flush_buffered_events()

func snap(label: String):
	if not visual:return
	game.hud.banner_time=0;game.hud.toast_time=0;game.player.invuln=0
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/attack-chain/"+label+".png")

func prime()->Ninja:
	var enemy=target(Vector3(0,0,-2.4));enemy.set_physics_process(false)
	await mouse(true,true);await mouse(false,true);await drain()
	return enemy

func unit_rules():
	var chain=AttackChain.new();var first=chain.begin("heavy")
	check(chain.count==0 and chain.remaining==0,"Starting an attack does not create a combo")
	check(chain.damage_for(first)==1,"An opener snapshots normal damage")
	chain.confirm(first)
	check(is_equal_approx(chain.damage_multiplier(),1.05),"A landed opener gives the next attack five percent more damage")
	check(chain.count==1 and chain.remaining==AttackChain.GRACE,"A confirmed first hit starts the combo")
	chain.tick(.4,true);var left=chain.remaining;chain.begin("miss")
	check(chain.count==1 and chain.remaining==left,"A missed attack cannot increment or refresh grace")
	chain.confirm(first)
	check(chain.count==1 and chain.remaining==AttackChain.GRACE,"Multi-target or sustained contact refreshes grace without duplicating a link")
	var next=chain.begin("wide");chain.confirm(next);chain.confirm(chain.bonus_ticket(next))
	check(chain.count==3 and chain.last_hit_action=="wide","A base attack and a separate bonus slash each earn one successful link")
	chain.begin("miss")
	chain.tick(AttackChain.GRACE+.01,true)
	check(chain.count==0 and chain.multiplier()==1,"The full grace window without damage expires the chain even while attacking")
	chain.confirm(first)
	check(chain.count==1,"A delayed real hit can start a fresh combo after expiry")
	chain.reset();chain.confirm(first)
	check(chain.count==0,"Old projectiles cannot restore a combo after a run reset")
	for i in range(24):chain.confirm(chain.begin("pipe"))
	check(chain.damage_multiplier()==1.5,"Combo damage caps at 1.5×")
	var powered=chain.begin("pipe");var bonus=chain.bonus_ticket(powered)
	chain.tick(AttackChain.GRACE+.01)
	check(chain.damage_multiplier()==1 and chain.damage_for(powered)==1.5 and chain.damage_for(bonus)==1.5,"Expiry resets new attacks while an already-cast projectile and its bonus retain their snapshot")
	chain.reset()
	check(chain.damage_for(powered)==1,"A previous-run powered ticket loses its damage bonus")
	for i in range(24):chain.confirm(chain.begin("pipe"))
	check(chain.count==24 and chain.multiplier()==1.5,"Confirmed links keep counting while combo speed caps at 1.5×")

func run():
	visual="--attack-chain-visual" in OS.get_cmdline_user_args()
	if visual:DirAccess.make_dir_recursive_absolute("res://tests/attack-chain")
	Input.use_accumulated_input=false
	game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.invincible=true;game.tuning.freeze_ai=true
	game.start_game();game.encounters.enabled=false;game.player.smoke_mode=true
	game.camera_rig.set_process_unhandled_input(false);get_window().set_flag(Window.FLAG_NO_FOCUS,true);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	game.child_entered_tree.connect(observe_projectile);game.child_entered_tree.connect(observe_energy)
	var p=game.player
	unit_rules()
	for action in ["light_attack","heavy_attack","weapon_pipe"]:
		await clean();press_melee(action)
		check(not p.hit_done and p.attack_chain.count==0,"Unconnected %s starts with its normal windup" % action)
		await drain()
		check(p.attack_chain.count==0 and get_tree().get_nodes_in_group("combo_bonus_attacks").is_empty(),"Swinging %s into air produces no combo or red bonus" % action)
	await clean();var enemy=await prime()
	check(enemy.hp==9952 and p.attack_chain.count==1,"A real right-click hit seeds exactly one link")
	var rear=target(Vector3(0,0,3));var side=target(Vector3(4,0,0));var extra=target(Vector3(0,0,-5.2))
	var impacts=[]
	var observer=func(victim,_strength,_duration):
		if victim==enemy:impacts.append(victim.hp)
	game.impact_confirmed.connect(observer)
	press_melee("weapon_pipe")
	check(is_equal_approx(enemy.hp,9853.3) and impacts.size()==2 and is_equal_approx(impacts[0],9878.5) and is_equal_approx(impacts[1],9853.3),"RMB → 1 deals 73.5 melee damage followed by an independent 25.2-damage red hit immediately (+5%)")
	check(p.attack_chain.count==3 and p.impact_pause==0,"The successful extra slash adds its own link without freezing the player")
	check(is_equal_approx(extra.hp,9901.3) and is_equal_approx(rear.hp,9926.5) and is_equal_approx(side.hp,9926.5),"Spin covers all directions while its separate red slash only hits targets in front")
	var effects=get_tree().get_nodes_in_group("combo_bonus_attacks")
	check(effects.size()==1 and effects[0].get_meta("cross") and effects[0].get_child_count()==2,"RMB → 1 creates a separate two-arm red cross slash")
	await snap("03-melee-cross-bonus");await drain();game.impact_confirmed.disconnect(observer)
	check(is_equal_approx(enemy.hp,9853.3) and is_equal_approx(extra.hp,9901.3) and p.attack_chain.count==3,"Contact-window resampling and multiple targets do not repeat the bonus or recursively create slashes")
	for e in [enemy,rear,side,extra]:e.position+=Vector3(50,0,0)
	var count=p.attack_chain.count;var grace=p.attack_chain.remaining
	press_melee("heavy_attack");await wait(.1)
	check(p.attack_chain.count==count and p.attack_chain.remaining<grace,"Missing during an existing combo does not add links or refresh it")
	await wait(AttackChain.GRACE+.1);enemy.position=p.position+Vector3(0,0,-2.4)
	press_melee("heavy_attack")
	check(p.attack_chain.count==0 and not p.hit_done,"Expired combo restores normal windup even when an enemy is now in range")
	await drain()
	await clean();enemy=await prime();enemy.position=p.position+Vector3(0,0,-7)
	var wall=Geo.box(game,p.position+Vector3(0,2,-3),Vector3(6,5,.5),Geo.mat("888888"),true)
	await wait(.05);extra=target(Vector3(0,0,-5.2));press_melee("weapon_pipe");await drain()
	check(extra.hp==10000 and p.attack_chain.count<=1,"Walls block red melee damage and blocked attacks do not earn links")
	wall.queue_free()
	await clean();enemy=target(Vector3(0,0,-2.4));await mouse(true);await mouse(false);await drain()
	check(is_equal_approx(enemy.hp,9867.6) and p.attack_chain.count==5,"LMB triplet keeps all three original hits and adds one real red hit to each connected follow-up")
	await clean();await key(KEY_2);await key(KEY_2);await drain();await wait(.2)
	check(p.attack_chain.count==0 and shots.size()==1 and not shots[0].combo_energy,"A ranged miss remains an ordinary coin and cannot start a combo")
	await clean();enemy=await prime();enemy.position=p.position+Vector3(0,0,-15)
	await key(KEY_2);await key(KEY_2)
	while shots.size()<2 and p.attack_left>0:await get_tree().physics_frame
	check(shots.size()==1 and not shots[0].combo_energy,"RMB → 2 throws an ordinary coin without a red ranged bonus")
	await snap("04-coin-melee-only-bonus");await drain();await wait(.6)
	check(is_equal_approx(enemy.hp,9931) and p.attack_chain.count==2,"A combo coin deals one 21-damage hit (+5%%) and earns one link (hp=%s, links=%s)" % [enemy.hp,p.attack_chain.count])
	await clean();var near=target(Vector3(8,0,-5));var far=target(Vector3(0,0,-22));var offscreen=target(Vector3(0,0,25))
	for e in [near,far,offscreen]:e.set_physics_process(false)
	await key(KEY_2);await key(KEY_2);await drain();await wait(.6)
	check(near.hp==9980 and far.hp==10000 and offscreen.hp==10000 and p.attack_chain.count==1,"2 still auto-aims at the nearest visible enemy and awards its link on impact")
	await clean();enemy=target(Vector3(0,0,-15));enemy.set_physics_process(false)
	await key(KEY_2);await key(KEY_2);await mouse(true,true);await mouse(false,true);await drain();await wait(.3)
	check(enemy.hp==9980 and p.attack_chain.count==1 and p.attack_chain.last_hit_action=="coin","In-flight projectile keeps its own hit attribution while a later heavy attack misses")
	await clean();enemy=await prime();enemy.position=p.position+Vector3(0,0,-8)
	await key(KEY_3);await wait(.4)
	var chain=p.model.chain_pipe
	chain.update_chain()
	check(chain.links.multimesh.instance_count==512,"Thicker chain retains the existing bounded instanced-link budget")
	await snap("05-thicker-chain")
	# Dummy headless rendering does not retain MultiMesh transform readback.
	if visual:check(chain.links.multimesh.get_instance_transform(0).basis.get_scale().is_equal_approx(Vector3(2.6,2.6,1)),"Rendered chain links are 2.6× thicker across their width, with unchanged length")
	await drain()
	check(is_equal_approx(enemy.hp,9853.3) and p.attack_chain.count==3,"Chain sweep confirms its hit and a separate red melee follow-up")
	await clean();await key(KEY_E);await wait(.3)
	check(p.attack_chain.count==0,"An empty damaging dash does not seed a combo")
	await clean();enemy=target(Vector3(0,0,-1.4));await key(KEY_E);await wait(.3)
	check(enemy.hp==9996 and p.attack_chain.count==1,"A damaging dash starts the combo only on contact")
	await clean();enemy=target(Vector3(0,0,-6));await key(KEY_T);await attack_frames()
	check(enemy.hp==9840 and p.attack_chain.count==1,"Sky Strike earns one confirmed link without cosmetic red damage")
	await clean();await key(KEY_Q);p.musashi.cast_fireball(false);await attack_frames();await wait(.3)
	check(p.attack_chain.count==0,"Casting fireballs into empty space does not start the chain")
	enemy=target(Vector3(0,0,-6));enemy.set_physics_process(false);p.soft_target=true
	p.musashi.cast_fireball(false);await attack_frames();await wait(.2)
	check(enemy.hp<10000 and p.attack_chain.count==1,"A fireball volley earns one link from actual projectile contact")
	var fireball_health=enemy.hp
	p.musashi.cast_fireball(true);await attack_frames();await wait(.2)
	check(is_equal_approx(fireball_health-enemy.hp,100.8),"A giant fireball after a confirmed volley deals 96 × 1.05 damage exactly once")
	check(p.attack_chain.count==2,"A giant fireball continues the same confirmed-hit chain")
	p.attack_chain.reset();var meteor_health=enemy.hp;p.musashi.begin_meteors()
	check(p.attack_chain.count==0,"Meteor windup alone does not award a link")
	await attack_frames()
	for i in range(180):
		if enemy.hp<meteor_health:break
		await get_tree().physics_frame
	check(enemy.hp<meteor_health and p.attack_chain.count==1 and p.attack_chain.last_hit_action=="meteors","Delayed meteor damage carries its original cast ticket and confirms one link")
	await clean();await key(KEY_Q)
	for i in range(10):p.attack_chain.confirm(p.attack_chain.begin("pipe"))
	p.collect_powerup("damage");enemy=target(Vector3(0,0,-6));enemy.set_physics_process(false);p.soft_target=true
	p.musashi.cast_fireball(true);await attack_frames();await wait(.3)
	check(is_equal_approx(enemy.hp,9784),"Capped combo damage stacks with the damage pickup on a real fireball: 96 × 1.5 × 1.5")
	await clean();await key(KEY_Q)
	p.musashi.activate_shield();p.musashi.start_beam()
	var held=InputEventAction.new();held.action="light_attack";held.pressed=true;Input.parse_input_event(held)
	await wait(.25)
	check(p.attack_chain.count==0,"Shield activation and a held beam aimed at empty space create no links")
	enemy=target(Vector3(0,0,-10));enemy.set_physics_process(false);await wait(1.2)
	check(p.attack_chain.count==1 and p.attack_chain.remaining>.8,"A held beam keeps grace alive only through real hits, without farming links per tick")
	enemy.position.x+=30;await wait(AttackChain.GRACE+.1)
	check(p.attack_chain.count==0,"Holding a beam after losing all targets cannot preserve the chain")
	held.pressed=false;Input.parse_input_event(held);p.musashi.stop_hold_beam()
	await clean();await key(KEY_Q);enemy=target(Vector3(0,0,-2));p.musashi.activate_shield();await wait(.15)
	check(enemy.hp<10000 and p.attack_chain.count==1,"Offensive shield earns a link from its first damaging pulse")
	await clean();await key(KEY_Q);var complete=game.encounters.completed;game.encounters.completed=true
	enemy=target(Vector3(0,0,-2));await key(KEY_E)
	check(enemy.hp==9964 and p.attack_chain.count==1,"Smoke teleport confirms its departure damage")
	await wait(.6);game.encounters.completed=complete
	await clean();enemy=target(Vector3(0,0,-2.4))
	for i in range(11):enemy.take_hit(1,Vector3.FORWARD,false,p.attack_chain.begin("pipe"))
	for i in range(4):p.collect_powerup("attack_speed")
	var health=enemy.hp;press_melee("weapon_pipe");await drain()
	check(is_equal_approx(enemy.hp,health-141) and p.attack_chain.count==13 and p.attack_speed_multiplier()==4.5,"Maximum combo plus orb speed preserves one base hit and one bonus, with no duplicates")
	game.show_pause();var before=p.attack_chain.remaining;await wait(1.2)
	check(p.attack_chain.remaining==before,"Pause freezes the hit-based grace timer")
	game.resume();await wait(AttackChain.GRACE+.1)
	check(p.attack_chain.count==0,"Grace resumes and expires normally after unpausing")
	await clean()
	var normal=Ninja.new();normal.game=game;normal.position=p.position+Vector3(8,0,0);game.add_child(normal);game.enemies.append(normal)
	check(normal.max_hp==game.tuning.enemy_hp*5,"Regular monsters have five times their previous base health")
	normal.take_hit(1,Vector3.FORWARD,false)
	check(p.attack_chain.count==0,"Unattributed environmental or diagnostic damage does not create an attack combo")
	normal.dead=true;normal.take_hit(1,Vector3.FORWARD,false,p.attack_chain.begin("pipe"))
	check(p.attack_chain.count==0,"Already defeated targets cannot award combo links")
	var giant=Ninja.new();giant.game=game;giant.ground_giant=true;giant.position=p.position+Vector3(15,0,0);game.add_child(giant);game.enemies.append(giant)
	check(giant.max_hp==game.tuning.enemy_hp*5*Ninja.GIANT_HEALTH,"Ground giants retain their giant multiplier on top of beefier base health")
	for i in range(40):ComboEnergy.slash(game,p.position+Vector3.UP,p.facing)
	check(get_tree().get_nodes_in_group("combo_energy").size()<=ComboEnergy.MAX_EFFECTS,"Separate bonus visuals retain the 24-effect budget")
	game.restart_area();await wait(.2)
	check(p.attack_chain.count==0,"A new run clears confirmed combo state")
	print("ATTACK_CHAIN_RESULT failures=",failures)
	get_tree().quit(1 if failures else 0)
