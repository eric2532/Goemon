class_name GameHUD
extends Control
var game: Node
var zone="TIDEFALL SHORE"
var banner=""
var banner_time=0.0
var toast_text=""
var toast_time=0.0
var font=ThemeDB.fallback_font
var nearby_cache: Array=[]
var nearby_refresh=0.0
var nearby_origin=Vector3.INF
var panel_styles: Dictionary={}
var building_target: BreakableBuilding
var building_target_time=0.0

func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func text(p: Vector2,s: String,size: int=18,color: Color=Color("edf4e9")):
	draw_string(font,p+Vector2(0,2),s,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color(0,0.08,0.12,0.65))
	draw_string(font,p,s,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _process(delta):
	banner_time=maxf(0,banner_time-delta)
	toast_time=maxf(0,toast_time-delta)
	nearby_refresh-=delta
	if not game.paused:building_target_time=maxf(0,building_target_time-delta)
	queue_redraw()

func _draw():
	if not game or not game.playing or game.paused: return
	var w=size.x
	var h=size.y
	var p=game.player
	var ink=Color(0.025,0.10,0.14,0.82)
	var gold=Color("f6d485")
	if building_target_time>0 and is_instance_valid(building_target):
		var bar=Vector2(w*.5-150,h*.66)
		draw_style_box(panel_style(ink),Rect2(bar,Vector2(300,64)))
		text(bar+Vector2(14,23),"BUILDING BROKEN · SIZE ×%.2f" % p.growth_multiplier() if building_target.destroyed else "BREAKABLE BUILDING · %d / %d" % [ceili(building_target.hp),building_target.max_hp],16,gold)
		if not building_target.destroyed:
			draw_rect(Rect2(bar+Vector2(14,33),Vector2(272,7)),Color("493039"))
			draw_rect(Rect2(bar+Vector2(14,33),Vector2(272*building_target.hp/building_target.max_hp,7)),gold)
			text(bar+Vector2(14,56),"Keep hitting to break it and grow",12)
	draw_style_box(panel_style(ink),Rect2(28,28,305,147))
	draw_circle(Vector2(68,76),27,Color("173d64"))
	draw_arc(Vector2(68,76),29,-PI/2,PI*1.5,48,gold,2,true)
	text(Vector2(53,85),"蒼",25,gold)
	text(Vector2(112,58),p.RogueRoster.name_for(p.character_id).to_upper() if p.is_rogue_character() else ("E D O / FIRE" if p.character_id==2 else "G O E M O N"),15,gold)
	draw_rect(Rect2(112,73,193,10),Color("23404a"))
	draw_rect(Rect2(112,73,193*p.hp/p.max_hp,10),Color("80dfac"))
	text(Vector2(112,107),"VITALITY  %03d / %03d" % [int(p.hp),int(p.max_hp)],13)
	var level=p.progression
	text(Vector2(48,130),"LV %02d / 99" % level.level,14,gold)
	var progress_label="MAX LEVEL" if level.level==level.MAX_LEVEL else ("%d defeated" % level.total_kills if game.descent_mode else "%d / %d kills" % [level.kills_into_level,level.kills_required()])
	text(Vector2(195,130),progress_label,12)
	draw_rect(Rect2(48,141,256,5),Color("23404a"))
	draw_rect(Rect2(48,141,256*(level.growth() if game.descent_mode else level.progress()),5),gold)
	text(Vector2(48,163),"Maximum bonuses reached" if level.level==level.MAX_LEVEL else ("Each island enemy grants +1 level" if game.descent_mode else "Kills level you up automatically"),12,Color("c4d3cc"))
	draw_style_box(panel_style(Color(0.025,0.10,0.14,0.76)),Rect2(20,h-134,650 if game.rogue_roster_mode else 538,117))
	if not game.descent_mode and not game.tower_defense_mode:draw_style_box(panel_style(Color(0.025,0.10,0.14,0.76)),Rect2(w-275,198,252,119))
	var speed=Vector2(p.velocity.x,p.velocity.z).length()
	if p.is_rogue_character():
		var data=p.RogueRoster.data(p.character_id)
		var cooldowns=p.active_ability.player.get("cooldowns",{})
		text(Vector2(32,h-108),"Q · Choose fighter   /   Mouse aim",15,gold)
		text(Vector2(32,h-80),"LMB · %s   RMB · %s%s" % [data.abilities.cutlass.name,data.abilities.flintlock.name,rogue_cooldown(cooldowns.get("flintlock",0.0))],15)
		text(Vector2(32,h-53),"C / E · %s%s   R · %s%s" % [data.abilities.roll.name,rogue_cooldown(cooldowns.get("roll",0.0)),data.abilities.drink.name,rogue_cooldown(cooldowns.get("drink",0.0))],14,Color(data.color))
		text(Vector2(32,h-28),"WASD Move · Shift Sprint · Space Jump · F Upgrade · Esc Pause",13,Color("c0d3d1"))
	else:
		var primary=""
		if p.character_id==2:
			primary="Hold LMB · Piercing beam" if p.musashi.empowered() else "LMB / Hold · Triple fireball"
			primary+="   RMB · Giant fireball"
		else:
			var slot=p.quick_attacks.return_slot if p.quick_attacks.active else p.weapon_slot
			primary=("LMB · Wind spin" if p.surge_left>0 else "LMB · 3-hit combo")+"   RMB · Heavy" if slot==1 else (("LMB · Giant toss" if p.surge_left>0 else "LMB · Toss")+"   RMB · Split")
			if slot==3:primary="LMB · Explosive throw   RMB · Fire fan" if p.surge_left>0 else "LMB · Chain throw   RMB · Fan swing"
		if game.rogue_battle_mode:primary="Mouse aim · "+primary.replace("LMB · 3-hit combo","Hold LMB · Combo")
		var number_actions="1 Spin · 2 Coins ×%d %s · 3 Sweep · 4 Red · 5 Gold" % [p.progression.coin_count(),"ON" if p.quick_attacks.coins_enabled else "OFF"]
		text(Vector2(32,h-108),("1 Volley · 2 Giant fireball · 3 Meteors · Q Switch" if p.attack_chain.unleashed() else "E D O · FIRECASTER · Q Switch character") if p.character_id==2 else number_actions,15,gold)
		text(Vector2(32,h-80),primary,15)
		text(Vector2(32,h-53),"WASD Fly   HOLD SPACE Ascend   SHIFT Boost" if p.can_fly() else "WASD   CTRL Walk   SHIFT Sprint   SPACE ×%d Jump   C Evade" % p.maximum_jumps(),13)
		var mode_control=("F Upgrade" if game.defense_beta else "F Build cannon") if game.tower_defense_mode else "Y New map"
		var goemon_controls="E Dash   R Surge   T Sky strike   "+("Q Fighters   " if game.rogue_roster_mode else "Q Switch   ")
		text(Vector2(32,h-28),("E Fire dodge   T Meteors   R Blue surge   " if p.character_id==2 else goemon_controls)+mode_control+"   ESC Pause",13,Color("c0d3d1"))
	if p.scarf_equipped and p.character_id==1:
		draw_style_box(panel_style(Color(0.16,0.025,0.04,0.90)),Rect2(20,h-170,440,29))
		text(Vector2(31,h-149),"GOLD CLOAK · HOLD SPACE TO FLY · SHIFT BOOST" if p.gold_cloak else "RONIN CLOAK · 3× SPEED · QUAD JUMP · BONUS COINS",13,Color("ffe1d6"))
	# Small speed instrument.
	var bx=w/2+(45 if game.rogue_roster_mode else -100)
	draw_rect(Rect2(bx,h-43,200,4),Color(0.05,0.2,0.23,0.6))
	draw_rect(Rect2(bx,h-43,200*minf(1,speed/(18*p.movement_multiplier())),4),gold)
	text(Vector2(bx+47,h-56),"%02d  /  MOMENTUM" % int(speed),12,gold)
	if game.tower_defense_mode:
		draw_defense(w,h,ink,gold)
	elif game.descent_mode:
		draw_descent(w,ink,gold)
	else:
		# North-up sanctuary map with real positions, enemies, river, and boss.
		var center=Vector2(w-111,112)
		var map_center=game.world.playable_bounds.get_center()
		var map_scale=140.0/game.world.playable_bounds.size.length()
		draw_circle(center,79,ink)
		draw_arc(center,79,0,TAU,64,Color(0.9,0.8,0.5,0.8),1.5,true)
		if game.area_index==0:
			for z in range(-65,55,4):
				var a=center+(Vector2(24+3*sin(z*0.055),z)-map_center)*map_scale
				draw_circle(a,3.5,Color("46969c"))
		else:
			for route in game.world.routes:
				draw_line(center+(Vector2(route[0].x,route[0].z)-map_center)*map_scale,center+(Vector2(route[1].x,route[1].z)-map_center)*map_scale,Color("7f9a8b"),2,true)
		for route in game.world.outer_routes:
			draw_line(center+(Vector2(route[0].x,route[0].z)-map_center)*map_scale,center+(Vector2(route[1].x,route[1].z)-map_center)*map_scale,Color("6b897d"),1,true)
		for landmark in game.world.landmarks.values():
			draw_rect(Rect2(center+(Vector2(landmark.x,landmark.z)-map_center)*map_scale-Vector2(4,4),Vector2(8,8)),gold,false,1.5)
		for gate in game.gates:
			var point=center+(Vector2(gate.position.x,gate.position.z)-map_center)*map_scale
			draw_colored_polygon(PackedVector2Array([point+Vector2(0,-8),point+Vector2(8,0),point+Vector2(0,8),point+Vector2(-8,0)]),Color("8bffe1") if gate.unlocked else Color("f59577"))
		for e in game.enemies:
			if is_instance_valid(e) and not e.dead:
				draw_circle(center+(Vector2(e.position.x,e.position.z)-map_center)*map_scale,3 if e.boss else 2,Color("f38b75"))
		for magnet in get_tree().get_nodes_in_group("orb_magnets"):
			if magnet.is_queued_for_deletion():continue
			var point=center+(Vector2(magnet.position.x,magnet.position.z)-map_center)*map_scale
			text(point+Vector2(-5,5),"M",14,Color("a5f0ff"))
		var pp=center+(Vector2(p.position.x,p.position.z)-map_center)*map_scale
		draw_circle(pp,4,Color("faf0c2"))
		draw_line(pp,pp+Vector2(p.facing.x,p.facing.z)*10,Color.WHITE,2,true)
		text(center+Vector2(-5,-85),"N",12,gold)
		var survival=game.encounters
		text(Vector2(w-256,223),"TIDEFALL SANCTUARY",14,gold)
		text(Vector2(w-256,247),"SURVIVE THE SWARM",15)
		text(Vector2(w-256,271),"%d alive · %d defeated" % [survival.alive_count,game.kills],14,Color("c4d3cc"))
		text(Vector2(w-256,299),"+10 per wave each minute",13)
		# The run timer stays prominent; waves and remaining time share gameplay time.
		draw_style_box(panel_style(ink),Rect2(w/2-185,24,370,128))
		text(Vector2(w/2-98,47),"SURVIVE UNTIL ZERO",16,gold)
		var clock_color=Color("ff987e") if survival.remaining()<=60 else Color("edf4e9")
		text(Vector2(w/2-67,91),survival.clock_text(survival.remaining()),40,clock_color)
		var wave_label="WAVE %02d / 60 · %d ENEMIES" % [survival.wave,survival.wave_size(maxi(1,survival.wave))]
		var label_width=font.get_string_size(wave_label,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
		text(Vector2((w-label_width)/2,116),wave_label,14,gold)
		var next_label="NEXT SWARM IN %02ds" % ceili(survival.next_wave_in()) if survival.wave<60 else "FINAL WAVE · HOLD ON"
		label_width=font.get_string_size(next_label,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x
		text(Vector2((w-label_width)/2,139),next_label,13)
	text(Vector2(32,195),"JUMPS",11,gold)
	for i in range(p.maximum_jumps()):
		draw_circle(Vector2(94+i*19,190),5,Color("99e4d6") if i<p.maximum_jumps()-p.jumps_used else Color("344e53"))
	if p.is_rogue_character():
		var state=p.active_ability.player
		var buff_left=maxf(float(state.get("buffTime",0)),float(state.get("drink",0)))
		var buff_name=str(state.get("buffName",""))
		if p.RogueRoster.class_id(p.character_id)=="pirate":buff_name="DRINK · UNTARGETABLE"
		if buff_left>0:text(Vector2(32,285),"%s · %.1fs" % [buff_name.to_upper(),buff_left],15,gold)
		elif state.get("blocking",false):text(Vector2(32,285),"BLOCKING · Face incoming attacks",15,gold)
		elif state.get("crouched",false):text(Vector2(32,285),"GET DOWN · Evading projectiles",15,gold)
		else:text(Vector2(32,285),"Q · ROGUE FIGHTERS",15,gold)
		if state.get("classId","")=="master-thief":
			var meter=float(state.get("blockMeter",0))
			draw_rect(Rect2(32,299,220,5),ink);draw_rect(Rect2(32,299,220*clampf(meter/100.0,0,1),5),gold)
			text(Vector2(32,322),"FIRE BURST READY · RMB" if meter>=100 else "BLOCK METER · %d / 100" % meter,12,gold)
	elif p.character_id==2:
		text(Vector2(32,285),"BLUE SURGE · %ds" % ceili(p.musashi.shield_left) if p.musashi.empowered() else ("BLUE SHIELD · Beam protected" if p.musashi.beam_guard else ("R · Blue surge ready" if p.musashi.shield_cooldown<=0 else "Blue surge cooldown · %ds" % ceili(p.musashi.shield_cooldown))),16,gold)
		if p.musashi.state==MusashiCombat.State.BEAM and is_instance_valid(p.musashi.beam):
			text(Vector2(w/2-205,h-245),"HOLD LMB · PIERCING BEAM · %dm" % int(p.musashi.beam.length_now),18,Color("ffac54"))
		elif p.musashi.is_casting_meteors():
			text(Vector2(w/2-145,h-245),"METEOR RAIN"+(" · %d queued" % p.musashi.meteor_pending if p.musashi.meteor_pending>0 else ""),18,Color("ffac54"))
	else:
		text(Vector2(32,285),"R · GOLDEN SURGE  %02ds" % ceili(p.surge_left) if p.surge_left>0 else "R · Golden surge ready",16,gold)
	var thief_meter=p.is_rogue_character() and p.RogueRoster.class_id(p.character_id)=="master-thief"
	var buff_y=(376.0 if p.buildings_broken>0 else 352.0) if thief_meter else (352.0 if p.buildings_broken>0 else 330.0)
	if not game.descent_mode:
		text(Vector2(32,buff_y),"ICE %d / 5 · Freeze 2s" % p.elemental_orbs.ice,15,EnergyPickup.COLORS.ice)
		buff_y+=24
		text(Vector2(32,buff_y),"FIRE %d / 5 · Explosion" % p.elemental_orbs.fire,15,EnergyPickup.COLORS.fire)
		buff_y+=24
	for kind in p.powerups:
		if p.powerups[kind]>0:
			var label="ATTACK SPEED ×%.1f · %d stacks" % [p.attack_speed_multiplier(),p.attack_speed_stacks] if kind=="attack_speed" else EnergyPickup.LABELS[kind]
			text(Vector2(32,buff_y),"%s · %ds" % [label,ceili(p.powerups[kind])],15,EnergyPickup.COLORS[kind])
			buff_y+=24
	if p.surge_left>0:
		draw_rect(Rect2(32,298,220,4),ink)
		draw_rect(Rect2(32,298,220*minf(1,p.surge_left/game.tuning.surge_duration),4),gold)
	for gate in game.gates:
		if game.portal_hint!="" or not gate.forward_gate:continue
		var diff=gate.position-p.position
		var heading=atan2(diff.x,-diff.z)+game.camera_rig.yaw
		var marker=Vector2(w*.5,110 if game.boss_active else 65)
		draw_colored_polygon(Transform2D(heading,marker)*PackedVector2Array([Vector2(0,-10),Vector2(7,6),Vector2(0,3),Vector2(-7,6)]),Color("79ffe0"))
		text(Vector2(w*.5-110,marker.y+33),"ENERGY PORTAL · %dm · F to enter" % int(diff.length()),14,Color("a3ffe6"))
		break
	if game.portal_hint!="":
		var prompt_width=font.get_string_size(game.portal_hint,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
		draw_style_box(panel_style(ink),Rect2((w-prompt_width)/2-20,h-210,prompt_width+40,40))
		text(Vector2((w-prompt_width)/2,h-182),game.portal_hint,18,gold)
	if p.buildings_broken>0:text(Vector2(32,346 if thief_meter else 322),"SIZE / REACH ×%.2f · %d buildings" % [p.growth_multiplier(),p.buildings_broken],13,gold)
	var flow=p.attack_chain
	if flow.count>0:
		var red=Color("ff6680") if flow.energized() else gold
		draw_style_box(panel_style(Color(.18,.025,.06,.86)),Rect2(28,202,320,64))
		text(Vector2(41,225),("%d · UNLEASHED" % flow.count) if flow.unleashed() else ("%d · BLAZING" % flow.count if flow.count>=50 else ("%d · HEATED" % flow.count if flow.count>=25 else ("%d LINK%s" % [flow.count,"S" if flow.count!=1 else ""]))),24,red)
		text(Vector2(41,248),"SPD ×%.2f   DMG ×%.2f" % [flow.multiplier(),flow.damage_multiplier()],14,red)
		draw_rect(Rect2(41,254,180,4),Color("493039"))
		draw_rect(Rect2(41,254,180*flow.remaining/flow.GRACE,4),red)
		text(Vector2(232,257),"%.2fs" % flow.remaining,12,red)
	if not game.adventure.pending_rewards.is_empty():
		text(Vector2(w*.5-190,h-182),"F · CHOOSE UPGRADE · %d earned" % game.adventure.pending_rewards.size(),18,gold)
	if game.boss_active and is_instance_valid(game.boss_enemy) and not game.boss_enemy.dead:
		var bw=440.0
		text(Vector2(w/2-143,44),game.BOSS_NAMES[game.area_index].to_upper()+" · GUARDIAN",17,gold)
		draw_rect(Rect2(w/2-bw/2,58,bw,8),ink)
		draw_rect(Rect2(w/2-bw/2,58,bw*game.boss_enemy.hp/game.boss_enemy.max_hp,8),Color("e47966"))
	if banner_time>0:
		var alpha=minf(1,banner_time)
		var tw=font.get_string_size(banner,HORIZONTAL_ALIGNMENT_LEFT,-1,30).x
		text(Vector2((w-tw)/2,h*0.25),banner,30,Color(1,0.89,0.66,alpha))
		draw_line(Vector2(w/2-120,h*0.25+18),Vector2(w/2+120,h*0.25+18),Color(1,0.85,0.5,alpha*0.8),1)
	if toast_time>0:
		var tw=font.get_string_size(toast_text,HORIZONTAL_ALIGNMENT_LEFT,-1,17).x
		draw_style_box(panel_style(ink),Rect2(w/2-tw/2-24,h-156,tw+48,40))
		text(Vector2(w/2-tw/2,h-130),toast_text,17,gold)

func draw_defense(w: float,h: float,ink: Color,gold: Color):
	var run=game.encounters
	var world=game.world
	var left=w*.5-205
	draw_style_box(panel_style(ink),Rect2(left,24,410,178 if run.beta_mode else 150))
	text(Vector2(left+22,49),("ROGUE SIEGE / "+("HARD" if run.hard_mode else "BETA")) if game.rogue_roster_mode else (("FIRE SIEGE  /  HARD" if run.hard_mode else "FIRE SIEGE  /  HOLD THE CENTER") if run.beta_mode else "THREE GATES  /  TOWER DEFENSE"),15,gold)
	text(Vector2(left+22,86),"%d GOLD" % run.money,29,Color("ffe6a3"))
	text(Vector2(left+240,83),"WAVE %d / %d" % [maxi(1,run.wave),run.MAX_WAVES] if run.beta_mode else "WAVE %02d" % run.wave,20)
	var status="NEXT WAVE IN %ds · BUILD & REPOSITION" % ceili(run.next_wave_in()) if run.next_wave_in()>0 else "%d RAIDERS · HOLD ALL THREE LANES" % run.alive_count
	if run.beta_mode:
		status="WAVE %d IN %ds · UPGRADE & REPOSITION" % [mini(run.MAX_WAVES,run.wave+1),ceili(run.next_wave_in())] if run.next_wave_in()>0 else "%d ACTIVE · %d INCOMING · %d / %d DOWN" % [run.alive_count,run.pending,run.wave_kills,run.wave_size(run.wave)]
	text(Vector2(left+22,112),status,14)
	text(Vector2(left+22,140),"SHRINE  %d / %d" % [run.base_hp,run.base_max_hp],14,Color("ffad96") if run.base_hp<=5 else Color("a6eed7"))
	draw_rect(Rect2(left+176,130,210,9),Color("31454b"))
	draw_rect(Rect2(left+176,130,210*maxf(0,float(run.base_hp)/run.base_max_hp),9),Color("ff997a") if run.base_hp<=5 else Color("89dbc4"))
	if run.beta_mode:
		var profile=run.wave_profile(maxi(1,run.wave))
		text(Vector2(left+22,170),"ENEMIES: SIZE ×%.1f  HP ×%.2f  DAMAGE ×%.2f" % [profile.size,profile.health,profile.damage],12,Color("ffc493"))
	var siege_boss: Ninja=null
	for enemy in game.enemies:
		if is_instance_valid(enemy) and not enemy.dead and enemy.defense_lane>=0 and enemy.defense_boss_tier>0:
			siege_boss=enemy
			break
	draw_style_box(panel_style(ink),Rect2(w-302,28,274,103))
	text(Vector2(w-284,53),"%d FIRE + %d CANNONS" % [run.tower_count("fire"),run.tower_count("cannon")] if run.beta_mode else "BUILD YOUR DEFENSE",14,gold)
	text(Vector2(w-284,78),"F · Build 100 gold / Upgrade" if run.beta_mode else "F near a wall mount · 100 gold",13)
	text(Vector2(w-284,102),"Level II: 150 gold · Level III: 225" if run.beta_mode else "F again to upgrade · %d / %d built" % [run.cannon_count(),world.cannon_sites.size()],13)
	text(Vector2(w-284,121),"Kills +%d gold · Bosses on 5 & 10" % (12+4*run.upgrade_level("bounty_hunters")) if run.beta_mode and run.tactics_enabled else "Kills +12 gold · Clear a wave for a bonus",11,Color("c4d3cc"))
	if run.beta_mode and run.tactics_enabled:
		draw_style_box(panel_style(ink),Rect2(w-302,145,274,142))
		text(Vector2(w-284,170),"YOUR BUILD · %d CARDS" % run.card_history.size(),14,gold)
		var recent=run.card_history.slice(maxi(0,run.card_history.size()-3))
		for i in range(recent.size()):
			var card=DefenseCards.get_card(recent[i].id)
			text(Vector2(w-284,194+i*21),card.title,13,Color(card.color))
		text(Vector2(w-284,271),"Runners · Armor · Front shields",11,Color("c4d3cc"))
	if run.beta_mode and is_instance_valid(game.kennel):
		var pack=game.kennel
		draw_style_box(panel_style(ink),Rect2(w-302,301,274,166))
		text(Vector2(w-284,326),"G · CASTLE KENNEL",16,Color("a1e9df"))
		var dog_status="%d / %d DOGS · READY" % [pack.living_count(),pack.MAX_DOGS]
		if pack.living_count()>=pack.MAX_DOGS:dog_status="%d / %d DOGS · SQUAD FULL" % [pack.living_count(),pack.MAX_DOGS]
		elif pack.cooldown_left>0:dog_status="%d / %d DOGS · %.1fs" % [pack.living_count(),pack.MAX_DOGS,pack.cooldown_left]
		text(Vector2(w-284,352),dog_status,13)
		text(Vector2(w-284,376),"10 companions · From 150 gold",12,Color("bcd5d3"))
		if is_instance_valid(game.barracks):
			var allies=game.barracks
			text(Vector2(w-284,409),"H · CASTLE BARRACKS",16,Color("eed3a1"))
			var hero_status="%d / %d HEROES · READY" % [allies.living_count(),allies.MAX_HEROES]
			if allies.living_count()>=allies.MAX_HEROES:hero_status="%d / %d HEROES · SQUAD FULL" % [allies.living_count(),allies.MAX_HEROES]
			elif allies.cooldown_left>0:hero_status="%d / %d HEROES · %.1fs" % [allies.living_count(),allies.MAX_HEROES,allies.cooldown_left]
			text(Vector2(w-284,433),hero_status,13)
			text(Vector2(w-284,456),"10 characters · 300 gold each",12,Color("d8cfbb"))
	if is_instance_valid(siege_boss):
		draw_style_box(panel_style(ink),Rect2(left,216,410,76))
		text(Vector2(left+18,240),"BOSS · "+("SHRINEBREAKER" if siege_boss.defense_boss_tier==1 else "INFERNO WARLORD"),16,Color("f5a2c0"))
		draw_rect(Rect2(left+18,251,374,10),Color("563442"))
		draw_rect(Rect2(left+18,251,374*maxf(0,siege_boss.hp/siege_boss.max_hp),10),Color("ee8fae"))
		var vulnerable=siege_boss.defense_traits!=null and siege_boss.defense_traits.phase=="recovery"
		text(Vector2(left+18,281),"WEAK POINT OPEN · Double damage now!" if vulnerable else "Dodge the warning ring · Strike during recovery",12,Color("8ff2cd") if vulnerable else Color("f2d8dd"))

func draw_descent(w: float,ink: Color,gold: Color):
	var run=game.encounters
	var sky=game.world.sky_islands
	var index=run.current_island
	var layer=sky.layer_at_height(game.player.position.y)
	var landed=sky.island_at(game.player.position,2)
	var cloud=sky.cloud_at(game.player.position,2) if landed<0 and game.player.is_on_floor() else -1
	draw_style_box(panel_style(ink),Rect2(w/2-225,24,450,155))
	text(Vector2(w/2-90 if game.rogue_battle_mode else w/2-72,48),"ROGUE BATTLE" if game.rogue_battle_mode else "SKY DESCENT",16,gold)
	var title=("TIDEFALL LIBERATED" if run.ground_cleared else "TIDEFALL GROUND BATTLE") if run.completed else ("LAYER %02d / %d · CHOOSE YOUR ROUTE" % [layer+1,sky.LAYERS])
	var width=font.get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,19).x
	text(Vector2((w-width)/2,81),title,19)
	var status=("All ground enemies defeated · Explore Tidefall" if run.ground_cleared else "%d GIANTS · %d RAIDERS" % [run.ground_remaining(),run.ground_raiders().size()]) if run.completed else ("%s · %d ENEMIES" % [sky.island_name(landed),run.remaining_on(landed)] if landed>=0 else ("CLOUD REST · JUMP TO ANY ISLAND" if cloud>=0 else ("GOLD CLOAK · FREE FLIGHT" if game.player.flying else "FREE FALL · STEER TOWARD ANY LANDING")))
	width=font.get_string_size(status,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x
	text(Vector2((w-width)/2,111),status,13,gold)
	var caption="%d / %d islands cleared" % [run.cleared.size(),sky.COUNT]+("" if run.completed else (" · Spawns stopped" if landed>=0 and (run.cleared.has(landed) or game.adventure.is_complete(landed)) else " · Reinforcements %ds" % ceili(maxf(0,run.next_reinforcement-run.elapsed))))
	width=font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x
	text(Vector2((w-width)/2,138),caption,13)
	var objective=game.adventure.objective_text(landed) if landed>=0 else "Land on an island to pursue its objective"
	if run.completed:objective="Break buildings for growth and combat pickups"
	width=font.get_string_size(objective,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
	text(Vector2((w-width)/2,164),objective,14,Color("ffbd83"))
	draw_style_box(panel_style(ink),Rect2(w-230,28,202,306))
	text(Vector2(w-211,54),"NEARBY SKY ISLANDS",12,gold)
	text(Vector2(w-211,77),"%d ISLANDS · FULL MAP" % sky.COUNT,11)
	if nearby_refresh<=0 or nearby_origin.distance_squared_to(game.player.position)>20*20:
		nearby_cache=sky.nearby_islands(game.player.position,8)
		nearby_origin=game.player.position;nearby_refresh=.2
	var nearby=nearby_cache
	for row in range(nearby.size()):
		var i=nearby[row]
		var color=gold if i==landed else (Color("85e6c0") if run.cleared.has(i) else Color("bdd5df"))
		var zone=String.chr(65+(i%sky.PER_LAYER)%sky.COLUMNS)+str(1+floori((i%sky.PER_LAYER)/float(sky.COLUMNS)))
		var label="%s L%d-%s · %dm" % [game.adventure.SHORT_NAMES[game.adventure.kind(i)],sky.layer_of(i)+1,zone,int(sky.islands[i].distance_to(game.player.position))]
		if i==landed:label+=" HERE"
		elif run.cleared.has(i):label+=" CLEAR"
		text(Vector2(w-211,103+row*23),label,11,color)
	text(Vector2(w-211,297),"Sprint + double jump gaps",11,gold)
	text(Vector2(w-211,319),"5 Gold cloak · Fly anywhere",11)

func panel_style(color: Color)->StyleBoxFlat:
	if panel_styles.has(color):return panel_styles[color]
	var s=StyleBoxFlat.new()
	s.bg_color=color
	s.corner_radius_top_left=8
	s.corner_radius_top_right=8
	s.corner_radius_bottom_left=8
	s.corner_radius_bottom_right=8
	panel_styles[color]=s
	return s

func rogue_cooldown(seconds: float)->String:
	return " (%.1fs)" % seconds if seconds>0 else ""
