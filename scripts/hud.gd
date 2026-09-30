class_name GameHUD
extends Control
var game: Node
var zone="TIDEFALL SHORE"
var banner=""
var banner_time=0.0
var toast_text=""
var toast_time=0.0
var font=ThemeDB.fallback_font

func _ready():
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func text(p: Vector2,s: String,size: int=18,color: Color=Color("edf4e9")):
	draw_string(font,p+Vector2(0,2),s,HORIZONTAL_ALIGNMENT_LEFT,-1,size,Color(0,0.08,0.12,0.65))
	draw_string(font,p,s,HORIZONTAL_ALIGNMENT_LEFT,-1,size,color)

func _process(delta):
	banner_time=maxf(0,banner_time-delta)
	toast_time=maxf(0,toast_time-delta)
	queue_redraw()

func _draw():
	if not game or not game.playing or game.paused: return
	var w=size.x
	var h=size.y
	var p=game.player
	var ink=Color(0.025,0.10,0.14,0.82)
	var gold=Color("f6d485")
	draw_style_box(panel_style(ink),Rect2(28,28,305,97))
	draw_circle(Vector2(68,76),27,Color("173d64"))
	draw_arc(Vector2(68,76),29,-PI/2,PI*1.5,48,gold,2,true)
	text(Vector2(53,85),"蒼",25,gold)
	text(Vector2(112,58),"E D O / FIRE" if p.character_id==2 else "G O E M O N",15,gold)
	draw_rect(Rect2(112,73,193,10),Color("23404a"))
	draw_rect(Rect2(112,73,193*p.hp/p.max_hp,10),Color("80dfac"))
	text(Vector2(112,107),"VITALITY  %03d / %03d" % [int(p.hp),int(p.max_hp)],13)
	draw_style_box(panel_style(Color(0.025,0.10,0.14,0.76)),Rect2(20,h-134,538,117))
	draw_style_box(panel_style(Color(0.025,0.10,0.14,0.76)),Rect2(w-275,198,252,119))
	var speed=Vector2(p.velocity.x,p.velocity.z).length()
	var primary=""
	if p.character_id==2:
		primary="Hold LMB · Piercing beam" if p.musashi.empowered() else "LMB / Hold · Triple fireball"
		primary+="   RMB · Giant fireball"
	else:
		var slot=p.quick_attacks.return_slot if p.quick_attacks.active else p.weapon_slot
		primary=("LMB · Wind spin" if p.surge_left>0 else "LMB · 3-hit combo")+"   RMB · Heavy" if slot==1 else (("LMB · Giant toss" if p.surge_left>0 else "LMB · Toss")+"   RMB · Split")
		if slot==3:primary="LMB · Explosive throw   RMB · Fire fan" if p.surge_left>0 else "LMB · Chain throw   RMB · Fan swing"
	var number_actions="1 Wide swing · 2 Giant coin · 3 Long fire sweep · 4 Cloak" if p.surge_left>0 else "1 Wide swing · 2 Coin throw · 3 Long sweep · 4 Cloak"
	text(Vector2(32,h-108),"E D O · FIRECASTER · Q Switch character" if p.character_id==2 else number_actions,15,gold)
	text(Vector2(32,h-80),primary,15)
	text(Vector2(32,h-53),"WASD   CTRL Walk   SHIFT Sprint   SPACE ×%d Jump   C Evade" % p.maximum_jumps(),13)
	text(Vector2(32,h-28),"E Fire dodge   T Meteor rain   R Blue surge   F1 Lab   ESC Pause" if p.character_id==2 else "E Dash   R Surge   T Sky strike   Q Switch   F1 Lab   ESC Pause",13,Color("c0d3d1"))
	if p.scarf_equipped and p.character_id==1:
		draw_style_box(panel_style(Color(0.16,0.025,0.04,0.90)),Rect2(20,h-170,440,29))
		text(Vector2(31,h-149),"RONIN CLOAK · 3× SPEED · QUAD JUMP · BONUS COINS",13,Color("ffe1d6"))
	# Small speed instrument.
	var bx=w/2-100
	draw_rect(Rect2(bx,h-43,200,4),Color(0.05,0.2,0.23,0.6))
	draw_rect(Rect2(bx,h-43,200*minf(1,speed/(18*p.movement_multiplier())),4),gold)
	text(Vector2(bx+47,h-56),"%02d  /  MOMENTUM" % int(speed),12,gold)
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
	text(Vector2(32,145),"JUMPS",11,gold)
	for i in range(p.maximum_jumps()):
		draw_circle(Vector2(94+i*19,140),5,Color("99e4d6") if i<p.maximum_jumps()-p.jumps_used else Color("344e53"))
	if p.character_id==2:
		text(Vector2(32,215),"BLUE SURGE · %ds" % ceili(p.musashi.shield_left) if p.musashi.empowered() else ("BLUE SHIELD · Beam protected" if p.musashi.beam_guard else ("R · Blue surge ready" if p.musashi.shield_cooldown<=0 else "Blue surge cooldown · %ds" % ceili(p.musashi.shield_cooldown))),16,gold)
		if p.musashi.state==MusashiCombat.State.BEAM and is_instance_valid(p.musashi.beam):
			text(Vector2(w/2-205,h-245),"HOLD LMB · PIERCING BEAM · %dm" % int(p.musashi.beam.length_now),18,Color("ffac54"))
		elif p.musashi.is_casting_meteors():
			text(Vector2(w/2-145,h-245),"METEOR RAIN"+(" · %d queued" % p.musashi.meteor_pending if p.musashi.meteor_pending>0 else ""),18,Color("ffac54"))
	else:
		text(Vector2(32,215),"R · GOLDEN SURGE  %02ds" % ceili(p.surge_left) if p.surge_left>0 else "R · Golden surge ready",16,gold)
	var buff_y=260.0
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
		draw_rect(Rect2(32,228,220,4),ink)
		draw_rect(Rect2(32,228,220*minf(1,p.surge_left/game.tuning.surge_duration),4),gold)
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
	if game.chain>1:
		text(Vector2(41,173),"%d" % game.chain,38,gold)
		text(Vector2(86,166),"HIT CHAIN",14,gold)
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

func panel_style(color: Color)->StyleBoxFlat:
	var s=StyleBoxFlat.new()
	s.bg_color=color
	s.corner_radius_top_left=8
	s.corner_radius_top_right=8
	s.corner_radius_bottom_left=8
	s.corner_radius_bottom_right=8
	return s
