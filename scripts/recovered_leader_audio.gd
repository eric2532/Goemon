extends Node
## Original disc samples. Local action timing and the dry charge mix are
## adaptations; source IDs, banks, pitch, and loop evidence accompany the WAVs.
const ROOT="res://assets/audio/recovered_leaders/"
const FILES={
	14:{"ed_assault_bounce":"assault_bounce","ed_assault_reposition":"assault_reposition","ed_assault_leap":"assault_leap","ed_assault_burst":"assault_burst","move_utility_weapon":"assault_reposition","ed_beam_charge":"beam_charge","ed_beam_bed":"beam_bed","edo_beam_start":"beam_release","edo_beam_loop":"beam_release","throw":"fireball_cast","hurt":"hurt",
		"move_primary_1_weapon":"beam_release","move_primary_2_weapon":"beam_release","move_primary_3_weapon":"beam_release",
		# Requested restoration of source-called A92, disabled in the US dispatch.
		"move_primary_1_voice":"beam_voice","move_primary_2_voice":"beam_voice","move_primary_3_voice":"beam_voice",
		"move_secondary_weapon":"fireball_cast","move_secondary_voice":"fireball_voice"},
	15:{"ben_axe_voice":"axe_voice","heavy_swing":"guandao_swing","throw":"bomb_throw","ben_bomb_settle":"bomb_throw","ben_projectile_throw":"projectile_fan","fire_impact":"bomb_end","ben_bomb_explosion":"bomb_end","ben_bomb_end":"bomb_end","ben_polearm_strike_voice":"guandao_strike_voice","ben_polearm_dash":"guandao_dash","ben_polearm_finish":"guandao_swing","hurt":"hurt","ben_propeller":"flight_loop",
		"move_primary_1_weapon":"guandao_swing","move_primary_2_weapon":"guandao_swing","move_primary_3_weapon":"guandao_swing",
		"move_primary_1_voice":"guandao_voice","move_primary_2_voice":"guandao_voice","move_primary_3_voice":"guandao_voice",
		"move_secondary_weapon":"bomb_throw","move_utility_weapon":"projectile_fan","move_utility_voice":"projectile_fan_voice"}
}
static var cache={}
static func stream_for(id: int,slot: String)->AudioStream:
	if not FILES.has(id) or not FILES[id].has(slot):return null
	var path=ROOT+("ed/" if id==14 else "ben/")+FILES[id][slot]+".wav"
	if not cache.has(path):cache[path]=load(path)
	return cache[path]

var combat: Node
var charge: AudioStreamPlayer
var rotor: AudioStreamPlayer3D
var rotor_source: AudioStream
var focused=true

func _ready():
	process_mode=Node.PROCESS_MODE_ALWAYS
	charge=AudioStreamPlayer.new();charge.name="BeamChargeAudio";add_child(charge)
	rotor=AudioStreamPlayer3D.new();rotor.name="PropellerAudio"
	rotor.unit_size=6;rotor.max_distance=32;add_child(rotor)

func _notification(what: int):
	if what==NOTIFICATION_APPLICATION_FOCUS_OUT:
		focused=false;stop()
	elif what==NOTIFICATION_APPLICATION_FOCUS_IN:focused=true

func live()->bool:
	return focused and is_instance_valid(combat) and combat.active and is_instance_valid(combat.hero) and is_instance_valid(combat.game) and combat.game.playing and not combat.game.transitioning and combat.hero.hp>0 and not combat.game.sound_library.recording

func begin_charge():
	charge.stop()
	if not live() or combat.hero.character_id!=14 or combat.hero.attack_heavy:return
	var playback=combat.game.sound_library.playback_for(14,"ed_beam_charge",stream_for(14,"ed_beam_charge"))
	if playback.muted or playback.stream==null:return
	charge.stream=playback.stream;charge.pitch_scale=1;charge.volume_db=linear_to_db(.22*playback.gain)
	charge.play()

func release_charge():
	if is_instance_valid(charge):charge.stop()

func stop():
	if is_instance_valid(charge):charge.stop()
	if is_instance_valid(rotor):rotor.stop()

func _process(_delta: float):
	if not live():stop();return
	var game=combat.game;var hero=combat.hero
	var paused=game.paused or get_tree().paused
	charge.stream_paused=paused;rotor.stream_paused=paused
	if not combat.is_attacking() or combat.contact_done:release_charge()
	elif charge.playing:
		var lib=game.sound_library
		if lib.is_muted_for(14,"ed_beam_charge"):release_charge()
		else:charge.volume_db=linear_to_db(.22*lib.gain_for(14,"ed_beam_charge"))
	if hero.character_id!=15 or not (hero.flying or combat.is_bombing()):rotor.stop();return
	var playback=game.sound_library.playback_for(15,"ben_propeller",stream_for(15,"ben_propeller"))
	if playback.muted or playback.stream==null:rotor.stop();return
	if rotor_source!=playback.stream:
		rotor.stop();rotor_source=playback.stream
		var loop=rotor_source.duplicate() as AudioStreamWAV
		if loop==null:return
		loop.loop_mode=AudioStreamWAV.LOOP_FORWARD
		# Only source942 has this audible sustain loop. Terminal silent ADPCM
		# loops in attack/voice samples must remain ordinary one-shot sounds.
		loop.loop_begin=28 if playback.original else 0
		loop.loop_end=3276 if playback.original else maxi(1,roundi(loop.get_length()*loop.mix_rate))
		rotor.stream=loop
	rotor.global_position=hero.global_position+Vector3.UP*1.5
	rotor.pitch_scale=1;rotor.volume_db=linear_to_db(.3*playback.gain)
	if not rotor.playing and not paused:rotor.play()
