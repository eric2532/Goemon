extends RefCounted
## Original Sasuke sound events, with native pitch, envelopes and variant weights.
## Dry ROM reconstruction: provenance.json documents the remaining DSP differences.
const ROOT="res://assets/audio/recovered_sasuke/"
const FILES={
	"jump":["jump_a","jump_b","jump_b"], "land":["event_220"],
	"hurt":["event_388"], "death":["event_392","event_38a"],
	"swing":["event_210"], "heavy_swing":["kunai_finish"],
	"hit":["event_221"], "heavy_hit":["event_221"],
	"sasuke_kunai_1":["event_210"], "sasuke_kunai_2":["event_210"], "sasuke_kunai_3":["kunai_finish"],
	"sasuke_kunai_hit":["event_221"], "sasuke_kunai_impact":["event_221"],
	"move_primary_1_weapon":["event_210"], "move_primary_2_weapon":["event_210"], "move_primary_3_weapon":["kunai_finish"],
	"move_primary_1_voice":["event_387"], "move_primary_2_voice":[], "move_primary_3_voice":["event_393"],
	"sasuke_bomb":["bomb_release"], "sasuke_bomb_throw":["bomb_release"],
	"sasuke_bomb_explosion":["event_104"], "sasuke_bomb_explode":["event_104"], "sasuke_bomb_impact":["event_24f"],
	"move_secondary_weapon":["event_20b"], "move_secondary_voice":["event_387"],
	"sasuke_ice":["ice_release"], "sasuke_ice_throw":["ice_release"],
	"sasuke_hail":["ice_release"], "sasuke_ice_charged":["ice_release"],
	"move_utility_weapon":["event_103"], "move_utility_voice":["event_393"],
	"move_ice_charged_weapon":["event_103"], "move_ice_charged_voice":["event_393"],
	"sasuke_ice_charge":["event_24c"], "sasuke_ice_charge_a":["event_24d"], "sasuke_ice_charge_b":["event_24e"],
	"sasuke_ice_impact":["event_221"], "sasuke_freeze":["event_221"],
	"sasuke_hair":["event_213"], "sasuke_hair_up":["event_213"], "sasuke_hair_forward":["event_213"],
	"sasuke_hair_hit":["event_24f"], "sasuke_hair_impact":["event_24f"],
	"move_hair_up_weapon":["event_213"], "move_hair_forward_weapon":["event_213"],
	"move_hair_up_voice":[], "move_hair_forward_voice":[],
	"sasuke_super_jump":["jetpack_entry"], "sasuke_jetpack":["jetpack_entry"],
	"sasuke_jetpack_launch":["event_21f"], "sasuke_jetpack_loop":["event_14f"], "sasuke_jetpack_voice":["event_394"],
	"move_skill_weapon":["jetpack_weapon"], "move_skill_voice":["event_394"],
	"sasuke_land_hard":["event_218"], "sasuke_land":["event_220"],
	# These adaptation actions have no verified native source sound.
	"dash":[], "step":[], "environment_hit":[], "move_evade_weapon":[], "move_evade_voice":[]
}
static var cache={}
static func stream_for(slot: String)->AudioStream:
	if not FILES.has(slot) or FILES[slot].is_empty():return null
	if not cache.has(slot):
		var files: Array=FILES[slot]
		if files.size()==1:cache[slot]=load(ROOT+files[0]+".wav")
		else:
			var variants=AudioStreamRandomizer.new()
			variants.random_pitch=1.0;variants.random_volume_offset_db=0
			variants.playback_mode=AudioStreamRandomizer.PLAYBACK_RANDOM
			for file in files:variants.add_stream(-1,load(ROOT+file+".wav"),1.0)
			cache[slot]=variants
	return cache[slot]
static func slot_labels()->Dictionary:
	var labels={}
	for slot in FILES:
		labels[slot]="Sasuke · "+str(slot).trim_prefix("sasuke_").trim_prefix("move_").replace("_"," ").capitalize()
	return labels
