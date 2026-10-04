extends "res://scripts/attack_chain_tests.gd"
var fired: Array[Dictionary]=[]
var hostile_shots=0

func frames(n: int):
	for i in range(n):await get_tree().physics_frame

func observe_cast(node: Node):
	if node is GoldCoin:
		if node.hostile:hostile_shots+=1
		else:fired.append({"ticket":node.attack_ticket,"energy":node.combo_energy,"velocity":node.velocity,"piercing":node.piercing})

func capture_sky(label: String):
	if not visual:return
	game.hud.banner_time=0;game.hud.toast_time=0;game.player.invuln=0;game.player.model.show()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/sky-combat/"+label+".png")

func hold(code: Key,down: bool):
	var e=InputEventKey.new();e.physical_keycode=code;e.pressed=down
	Input.parse_input_event(e);Input.flush_buffered_events()

func island_rules():
	var p=game.player;var sky=game.world.sky_islands
	await frames(25)
	check(sky.islands.size()==784 and sky.bridges.is_empty() and sky.clouds.size()>150 and sky.clouds.size()<350,"784 islands retain only small isolated clouds and no continuous cloud roads")
	var kinds={};var minimum=INF;var maximum=0.0;var floors=true;var nonoverlap=true;var contained=true
	for i in range(sky.COUNT):
		kinds[sky.shape_ids[i]]=true;minimum=minf(minimum,sky.radii[i]);maximum=maxf(maximum,sky.radii[i])
		var origin=sky.islands[i]
		var ray=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(origin+Vector3.UP,origin-Vector3.UP,1))
		floors=floors and not ray.is_empty() and ray.normal.y>.99 and sky.island_at(origin+.1*Vector3.UP)==i
		for vertex in sky.outlines[i]:contained=contained and game.world.playable_bounds.has_point(Vector2(origin.x,origin.z)+vertex)
		for j in range(i+1,(sky.layer_of(i)+1)*sky.PER_LAYER):
			if origin.distance_to(sky.islands[j])>sky.radii[i]+sky.radii[j]:continue
			var a=PackedVector2Array();var b=PackedVector2Array()
			for v in sky.outlines[i]:a.append(v+Vector2(origin.x,origin.z))
			for v in sky.outlines[j]:b.append(v+Vector2(sky.islands[j].x,sky.islands[j].z))
			nonoverlap=nonoverlap and Geometry2D.intersect_polygons(a,b).is_empty()
	check(kinds.size()==6 and maximum/minimum>2,"All six irregular silhouettes appear, with more than 2× size variation")
	check(floors and contained,"Every island has a real flat collision surface inside the map")
	check(nonoverlap,"Varied islands do not overlap within a layer")
	var gaps=true
	for route in sky.jump_routes:
		var d=sky.islands[route.y]-sky.islands[route.x];var angle=atan2(d.z,d.x)
		var a=sky.interior_point(route.x,angle,1);var b=sky.interior_point(route.y,angle+PI,1)
		var middle=a.lerp(b,.5)
		var hit=game.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(middle+Vector3.UP,middle-Vector3.UP,1))
		gaps=gaps and hit.is_empty() and a.distance_to(b)>6 and a.distance_to(b)<35
	check(gaps and sky.jump_routes.size()==672,"All 672 hub-to-island routes contain true air gaps, not invisible roads")
	check(game.enemies.any(func(e):return e.variant==3 and not e.island_elite),"Initial island encounters include small ranged throwers")
	var spawns_safe=true
	for enemy in game.enemies:spawns_safe=spawns_safe and sky.contains_point(enemy.island_index,enemy.position,1)
	check(spawns_safe,"Enemies spawn inside each actual polygon footprint")
	game.camera_rig.set_process(false);game.camera_rig.camera.global_position=sky.islands[0]+Vector3(55,50,85)
	game.camera_rig.camera.look_at(sky.islands[0]);game.camera_rig.camera.fov=63
	await capture_sky("01-irregular-jump-islands")
	# Cross the first air gap with the real unrobed controller and two jump inputs.
	game.encounters.enabled=false
	var d=sky.islands[1]-sky.islands[0];d.y=0;d=d.normalized()
	var angle=atan2(d.z,d.x)
	var launch=sky.interior_point(0,angle,.83)
	var landing=sky.interior_point(1,angle+PI,.82)
	game.reset_player_at(launch+Vector3.UP*.1);p.set_scarf_equipped(false);game.camera_rig.yaw=0
	await frames(10);hold(KEY_SHIFT,true)
	p.smoke_move=Vector2(d.x,d.z);await frames(7);await key(KEY_SPACE)
	var crossed=false;var saw_air=false
	for step in range(155):
		if step==43:await key(KEY_SPACE)
		var delta=landing-p.position;delta.y=0
		p.smoke_move=Vector2(delta.normalized().x,delta.normalized().z) if delta.length()>1.5 else Vector2.ZERO
		saw_air=saw_air or not p.is_on_floor()
		await frames(1)
		if sky.island_at(p.position,6)==1 and p.is_on_floor():crossed=true;break
	p.smoke_move=Vector2.ZERO;hold(KEY_SHIFT,false)
	check(saw_air and crossed,"A real sprint/double jump crosses the first open gap and lands on the next island")

func controls_rules():
	var p=game.player
	await clean();fired.clear();press_melee("weapon_coin")
	check(p.quick_attacks.coins_enabled and fired.size()==1 and p.weapon_slot==1 and p.attack_left==0,"One press of 2 starts a coin immediately without changing weapon or locking movement")
	await frames(65)
	check(fired.size()>=3 and fired.size()<=4 and p.attack_chain.count==0,"Auto coins repeat at a bounded cadence and misses never build a combo")
	var echo=InputEventKey.new();echo.physical_keycode=KEY_2;echo.pressed=true;echo.echo=true
	Input.parse_input_event(echo);Input.flush_buffered_events()
	check(p.quick_attacks.coins_enabled,"Holding 2 cannot repeatedly flip the toggle")
	press_melee("weapon_coin");var before=fired.size();await frames(45)
	check(not p.quick_attacks.coins_enabled and fired.size()==before,"A second press stops automatic coin creation")
	await clean();fired.clear()
	var near=target(Vector3(8,0,-5));var far=target(Vector3(0,0,-22));var behind=target(Vector3(0,0,25))
	for e in [near,far,behind]:e.set_physics_process(false)
	press_melee("weapon_coin");await frames(23);press_melee("weapon_coin")
	check(near.hp==9980 and far.hp==10000 and behind.hp==10000 and p.attack_chain.count==1,"Auto coins hit the nearest on-screen enemy and keep off-screen targets out of auto aim")
	await clean();fired.clear();press_melee("heavy_attack");var ticket=p.attack_ticket
	p.quick_attacks.coins_enabled=true;p.quick_attacks.coin_clock=0;p.quick_attacks.tick_coins(0)
	check(p.attack_ticket==ticket and p.attack_chain.active_ticket==ticket and fired[0].ticket!=ticket,"A background coin retains its own hit ticket while a manual attack winds up")
	await drain();check(p.attack_left==0 and p.weapon_slot==1,"Manual heavy attack completes normally while coins repeat")
	p.smoke_move=Vector2.RIGHT;await frames(45)
	check(Vector2(p.velocity.x,p.velocity.z).length()>9.5 and p.attack_left==0,"Enabled coins allow full normal running speed")
	p.smoke_move=Vector2.ZERO;game.show_pause();before=fired.size();var clock=p.quick_attacks.coin_clock;await frames(30)
	check(fired.size()==before and p.quick_attacks.coins_enabled and p.quick_attacks.coin_clock==clock,"Pause freezes coin fire and preserves the toggle")
	game.resume();await frames(30);check(fired.size()>before,"Coin fire resumes after pause")
	press_melee("dodge");await frames(24);check(p.quick_attacks.coins_enabled,"Evading suspends shots briefly without switching off the toggle")
	# Even while a travel attack owns movement, 2 can turn shooting off.
	p.forward_dash.active=true;press_melee("weapon_coin")
	check(not p.quick_attacks.coins_enabled,"The coin toggle can be switched off during a dash")
	p.forward_dash.cancel();press_melee("weapon_coin")
	await key(KEY_Q);check(not p.quick_attacks.coins_enabled,"Switching to Edo turns off Goemon's coin toggle")
	await clean();fired.clear();await key(KEY_1)
	check(p.attack_charged and not p.wide_swing and p.surge_left==0,"1 starts the R-mode wind spin without needing to activate R")
	await frames(17);await capture_sky("02-hotkey-wind-spin");await drain()
	await clean();var front=target(Vector3(0,0,-7));var rear=target(Vector3(0,0,6));var side=target(Vector3(6,0,0))
	for e in [front,rear,side]:e.set_physics_process(false)
	await key(KEY_1);await drain()
	check(front.hp==9930 and rear.hp==9930 and side.hp==9930,"Hotkey spin has the same 70 damage, powered reach and 360-degree coverage as R + LMB")
	await clean();var enemy=await prime();enemy.set_physics_process(false);var health=enemy.hp
	press_melee("weapon_pipe")
	check(p.hit_done and is_equal_approx(health-enemy.hp,98.7) and p.attack_chain.count==3,"A combo spin skips windup and adds its separate damaging red cross slash")
	await drain();await clean();await fresh_robe();fired.clear();await key(KEY_1);await drain()
	check(fired.size()==16,"Hotkey spin releases the same 16-coin ring when wearing the robe")
	await clean();fired.clear()
	for i in range(100):p.attack_chain.confirm(p.attack_chain.begin("pipe"))
	for i in range(4):p.collect_powerup("attack_speed")
	press_melee("weapon_coin");press_melee("weapon_pipe");press_melee("weapon_chain");press_melee("heavy_attack")
	check(p.attack_left==0 and p.quick_attacks.pending.is_empty(),"100-link manual attacks still release immediately alongside auto coins")
	fired.clear();await frames(60)
	check(fired.size()<=18 and p.quick_attacks.pending.is_empty(),"Maximum speed and 100 links keep automatic projectiles bounded without queue growth")
	p.clear_powerups();check(not p.quick_attacks.coins_enabled,"A new-run power reset clears the toggle")

func elite_fixture()->Ninja:
	var enemy=Ninja.new();enemy.game=game;enemy.island_elite=true;enemy.practice=true
	enemy.position=game.player.position+Vector3(0,0,-9);game.add_child(enemy);game.enemies.append(enemy)
	enemy.set_physics_process(false);return enemy

func elite_rules():
	await clean();var p=game.player;var elite=elite_fixture();var attack=elite.elite_attacks
	p.set_physics_process(false);game.tuning.invincible=false;p.invuln=0
	var original=p.position;var health=p.hp
	attack.begin("blast");attack.tick(.65)
	check(p.hp==health and attack.phase=="warning","Elite blast deals no damage during its visible 1.2-second warning")
	game.camera_rig.camera.global_position=p.position+Vector3(10,13,16);game.camera_rig.camera.look_at(p.position+Vector3(0,0,-4))
	await capture_sky("03-elite-blast-warning")
	attack.tick(.56)
	check(p.hp==health-28,"Standing in the marked blast takes its area damage exactly on impact")
	attack.tick(.1);check(p.hp==health-28,"A blast cannot repeatedly hit during its impact animation")
	p.invuln=0;health=p.hp;attack.begin("blast");p.position.x+=7;attack.tick(1.21)
	check(p.hp==health,"Moving outside the locked blast circle dodges its damage")
	p.position=original;p.invuln=0;attack.begin("blast");p.position.y+=3;attack.tick(1.21)
	check(p.hp==health,"Jumping above the ground blast avoids damage")
	p.position=original;p.invuln=0;attack.begin("beam");attack.tick(.7)
	var locked=attack.direction;p.position.x+=5;attack.tick(.4)
	check(attack.direction==locked and attack.phase=="warning","Beam aim locks before firing, leaving a clear dodge window")
	health=p.hp;attack.tick(.11);attack.tick(.1)
	check(p.hp==health and attack.phase=="impact","The sustained channel misses a player who moved out of its locked line")
	p.position=original;p.invuln=0;attack.tick(.31)
	check(p.hp==health-12,"The channel damages a player inside its line")
	await capture_sky("04-elite-channel-beam")
	p.invuln=0;health=p.hp
	var wall=Geo.box(game,original+Vector3(0,1.5,-4),Vector3(8,5,.4),Geo.mat("888888"),true);await frames(2)
	attack.tick(.31)
	check(attack.beam_length<6 and p.hp==health,"Solid cover clips the visible beam and blocks channel damage")
	wall.queue_free();await frames(2)
	attack.begin("beam");elite.take_hit(1,Vector3.RIGHT,true)
	check(not attack.active,"Heavy hits interrupt an elite warning or channel")
	attack.begin("blast");elite.freeze_for(.4);check(not attack.active,"Freeze cancels pending elite damage")
	elite.frozen_left=0;attack.begin("beam");elite.take_hit(999999,Vector3.UP,false)
	check(not attack.active,"Killing an elite immediately removes its attack")
	p.position=original;p.hp=p.max_hp;p.invuln=0;game.tuning.invincible=true;p.set_physics_process(true)
	await clean();elite=elite_fixture();elite.set_physics_process(true);elite.cooldown=99;game.tuning.freeze_ai=false
	var saw_blast=false;var saw_beam=false
	for i in range(510):
		await frames(1)
		if elite.elite_attacks.active:
			saw_blast=saw_blast or elite.elite_attacks.kind=="blast"
			saw_beam=saw_beam or elite.elite_attacks.kind=="beam"
		if saw_blast and saw_beam:break
	check(saw_blast and saw_beam,"The live elite AI starts and alternates both special attacks")
	var phase_time=elite.elite_attacks.elapsed;game.show_pause();await frames(20)
	check(elite.elite_attacks.elapsed==phase_time,"Pause freezes an active elite warning")
	game.resume();elite.queue_free();game.enemies.erase(elite);await frames(2)
	check(get_tree().get_nodes_in_group("elite_telegraphs").is_empty(),"Unloading an elite removes its warning and channel nodes")
	game.tuning.freeze_ai=true;await clean();hostile_shots=0
	var caster=Ninja.new();caster.game=game;caster.variant=3;caster.practice=true;caster.position=p.position+Vector3(0,0,-12);caster.cooldown=0
	game.add_child(caster);game.enemies.append(caster);game.tuning.freeze_ai=false
	await frames(80)
	check(hostile_shots>=2,"A small ranged enemy winds up and throws real hostile projectiles from range")
	caster.state="chase";caster.cooldown=2;caster.position=p.position+Vector3(0,0,-5);caster.velocity=Vector3.ZERO
	var distance=caster.position.distance_to(p.position);await frames(25)
	check(caster.position.distance_to(p.position)>distance+.3,"Small ranged enemies back away when the player closes in")
	game.tuning.freeze_ai=true;await clean()

func run():
	visual="--sky-combat-visual" in OS.get_cmdline_user_args()
	if visual:DirAccess.make_dir_recursive_absolute("res://tests/sky-combat")
	Input.use_accumulated_input=false
	game.tuning=PrototypeTuning.DEFAULTS.duplicate();game.tuning.invincible=true;game.tuning.freeze_ai=true
	game.start_game();game.player.smoke_mode=true
	game.camera_rig.set_process_unhandled_input(false);get_window().set_flag(Window.FLAG_NO_FOCUS,true);Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	game.child_entered_tree.connect(observe_cast)
	await island_rules();await controls_rules();await elite_rules()
	print("SKY_COMBAT_RESULT failures=",failures)
	get_tree().quit(1 if failures else 0)
