extends "res://scripts/ranger_storm_tests.gd"
## Actual higher jumps, held Space slow fall and firing during glide in latest MVP.
var air_measurements: Dictionary = {}

func random_flight_rules():
	await super.random_flight_rules()
	await jump_height_rules()
	await glide_rules()
	await airborne_fire_rules()
	await hurt_glide_rules()
	await glide_lifecycle_rules()

func jump_peak(index: int, second: bool) -> float:
	await fresh_class(index);var p=game.player
	tap("jump")
	if second:await frames(8);tap("jump")
	var start=p.position.y;var peak=start
	for i in range(110):
		await frames(1);peak=maxf(peak,p.position.y)
	return peak-start

func jump_height_rules():
	var ordinary=[];var ranger=[]
	for second in [false,true]:
		ordinary.append(await jump_peak(1,second));ranger.append(await jump_peak(7,second))
	for i in range(2):
		var ratio=ranger[i]/ordinary[i]
		check(ratio>1.95 and ratio<2.12,"Ranger %s actual jump apex is twice the ordinary height" % ("first" if i==0 else "second"))
	air_measurements.jump_heights={"ordinary":ordinary,"ranger":ranger}
	await fresh_class(7);press("jump");await frames(65)
	check(game.player.jumps_used==1 and not game.player.is_on_floor(),"Holding the first jump does not auto-spend the double jump")
	press("jump",false);tap("jump");await frames(2)
	check(game.player.jumps_used==2 and game.player.velocity.y>18,"A deliberate second Space press still performs the higher double jump")

func drop_fixture(index: int, height: float = 60.0):
	await fresh_class(index);var p=game.player
	p.global_position+=Vector3.UP*height;await frames(2)
	p.velocity=Vector3(0,-12,0);p.jumps_used=2;p.coyote=0;p.jump_buffer=0

func glide_rules():
	var drops=[];var speeds=[]
	for held in [false,true]:
		await drop_fixture(7);var p=game.player;var start=p.position.y
		if held:press("jump")
		await frames(24)
		drops.append(start-p.position.y);speeds.append(-p.velocity.y)
		press("jump",false)
	check(drops[1]>0 and absf(drops[0]/drops[1]-3)<.12,"Holding Space while falling covers one third the normal downward distance")
	check(absf(speeds[0]/speeds[1]-3)<.08,"Held Space slows actual downward speed by three times")
	air_measurements.fall={"normal_drop":drops[0],"held_drop":drops[1],"normal_speed":speeds[0],"held_speed":speeds[1]}
	await drop_fixture(7);var p=game.player
	press("jump");await frames(8);var slow_speed=-p.velocity.y
	press("jump",false);await frames(2)
	check(-p.velocity.y>slow_speed*2.8,"Releasing Space promptly restores normal descent")
	await drop_fixture(7);p=game.player;var a=p.active_ability
	press("jump");await frames(2);var once=-p.velocity.y
	await frames(28)
	check(-p.velocity.y>once and p.velocity.y< -1,"Held glide keeps descending instead of repeatedly dividing speed into hovering")
	press("jump",false)
	await fresh_class(7);p=game.player;press("jump");await frames(12)
	check(p.velocity.y>10 and not p.active_ability.player.get("rangerGliding",false),"Glide does not suppress the rising part of the higher jump")
	press("jump",false)
	await drop_fixture(1);p=game.player;press("jump");await frames(24)
	check(absf(-p.velocity.y-speeds[0])<.6,"Holding Space does not slow another hero's fall")
	press("jump",false)

func airborne_fire_rules():
	await drop_fixture(7,20);var p=game.player;var a=p.active_ability
	press("jump");press("light_attack");await frames(45)
	check(not p.is_on_floor() and a.player.get("rangerGliding",false),"Ranger stays airborne while holding Space and attacking")
	check(a.player.rangerShots>=3 and a.projectiles.filter(func(pr):return pr.weapon=="cutlass").size()>=10,"Held LMB keeps releasing downward fans throughout the glide")
	check(a.projectiles.any(func(pr):return pr.power and pr.vel.y<0),"Third-shot green downward fan remains available while gliding")
	press("light_attack",false);a._clear_projectiles();tap("surge");tap("weapon_chain");await frames(1)
	var powered_fan=a.projectiles.size()==5 and a.projectiles.all(func(pr):return pr.power)
	if game.crosshair_aim_enabled():
		check(powered_fan and a.projectiles[2].aimDirection.dot(game.projectile_direction(a.player.pos+Vector3.UP*1.05))>.999,"Rain and reticle-aimed five-arrow secondary fan work during held glide")
	else:check(powered_fan and a.projectiles.all(func(pr):return pr.vel.y<0),"Rain and five-arrow secondary fan still work during held glide")
	press("jump",false)

func hurt_glide_rules():
	await drop_fixture(7);var p=game.player;var a=p.active_ability
	press("jump");await frames(8)
	var ordinary=p.velocity.y*3;game.tuning.invincible=false;p.invuln=0
	p.take_hit(1,Vector3.ZERO)
	check(absf(p.velocity.y-(ordinary+3))<.001 and not a.player.rangerGliding,"A real nonlethal incoming hit applies its upward impulse once to normal fall momentum")
	await frames(8)
	check(a.player.rangerGliding and p.velocity.y<0,"Held Space resumes controlled glide after incoming-hit recovery")
	game.tuning.invincible=true;press("jump",false)

func glide_lifecycle_rules():
	await drop_fixture(7,1.3);var p=game.player;var a=p.active_ability
	press("jump");await frames(90)
	check(p.is_on_floor() and p.jumps_used==0 and not a.player.get("rangerGliding",false),"Holding glide through landing clears state without automatic jump or bounce")
	press("jump",false)
	await drop_fixture(7);a=p.active_ability;press("jump");await frames(5)
	var falling=-p.velocity.y;a.cancel(true)
	check(not a.player.get("rangerGliding",false) and -p.velocity.y>falling*2.8,"Cancel restores ordinary vertical speed and clears glide state")
	press("jump",false)
	await drop_fixture(7);a=p.active_ability;press("jump");await frames(5);p.select_character(4)
	check(not a.player.get("rangerGliding",false),"Hero switching cannot carry Ranger glide into another kit")
	press("jump",false)
	await drop_fixture(7);a=p.active_ability;press("jump");await frames(5)
	game.show_pause();var paused_position=p.position;await frames(8)
	check(p.position.distance_to(paused_position)<.001,"Pausing freezes glide without continuing descent")
	press("jump",false);game.resume();await frames(3)
	check(not a.player.rangerGliding and p.velocity.y< -12,"Space released during pause resumes ordinary falling")
	await drop_fixture(7);a=p.active_ability;press("jump");await frames(5)
	p.hp=0;game.encounters.hero_died();await frames(2)
	check(not a.player.rangerGliding,"Actual Fire Siege death clears active Ranger glide")
	press("jump",false);game.encounters.revive_now();await frames(15)
	check(not a.player.rangerGliding and p.is_on_floor(),"Revival returns to grounded movement without retained glide")

func lifecycle_rules():
	await super.lifecycle_rules()
	var path="res://build/ranger-air/air-measurements.json" if OS.has_feature("editor") else "user://build/ranger-air/air-measurements.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(air_measurements,"\t"))
