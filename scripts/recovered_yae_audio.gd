extends RefCounted
## Native Yae combat events. Original pitch, envelope and random weights retained.
## Dry ROM reconstruction; provenance.json documents the remaining DSP differences.
const ROOT = "res://assets/audio/recovered_yae/"
const FILES = {
	"jump": ["jump_a", "jump_b", "jump_c"], "land": ["event_21e"],
	"hurt": ["event_399", "event_39a", "event_39b"], "death": ["event_3a5", "event_39e"],
	"swing": ["event_214"], "heavy_swing": ["katana_finish"],
	"hit": ["event_221"], "heavy_hit": ["event_221"],
	"yae_katana_1": ["event_214"], "yae_katana_2": ["event_215"], "yae_katana_3": ["katana_finish"],
	"yae_katana_3_follow": ["event_216"], "yae_katana_land": ["event_217"],
	"yae_katana_hit": ["event_221"], "yae_katana_impact": ["event_221"],
	"move_primary_1_weapon": ["event_214"], "move_primary_2_weapon": ["event_215"], "move_primary_3_weapon": ["katana_finish"],
	"move_primary_1_voice": ["event_396", "event_397", "event_398"], "move_primary_2_voice": [],
	"move_primary_3_voice": ["event_3a6", "event_3a2", "event_3a2"],
	"yae_bazooka": ["event_102"], "yae_bazooka_fire": ["event_102"], "yae_lock_on": ["event_102"],
	"yae_bazooka_impact": ["event_24f"], "yae_lock_on_impact": ["event_24f"],
	"move_secondary_weapon": ["event_102"], "move_charged_weapon": ["event_102"],
	"move_secondary_voice": ["event_3a6", "event_3a2", "event_3a2"],
	"move_charged_voice": ["event_3a6", "event_3a2", "event_3a2"],
	"yae_bazooka_charge": ["event_24c"], "yae_bazooka_charge_a": ["event_24d"], "yae_bazooka_charge_b": ["event_24e"],
	"yae_lock_on_charge": ["event_24c"], "yae_lock_on_charge_a": ["event_24d"], "yae_lock_on_charge_b": ["event_24e"],
	"yae_shield": ["event_214"], "yae_shield_spin": ["event_214"], "yae_shield_block": ["event_23b"],
	"move_utility_weapon": ["event_214"], "move_utility_voice": [],
	"yae_jump_voice": ["event_39f", "event_3a0", "event_3a1"], "yae_jump_launch": ["event_21d"],
	"yae_land": ["event_21e"], "yae_land_hard": ["event_217"],
	# No source event has been verified for these adaptation actions.
	"step": ["event_217"], "dash": [], "environment_hit": [], "move_evade_weapon": [], "move_evade_voice": [],
	"yae_bazooka_explosion": [], "yae_lock_on_ready": []
}
static var cache = {}
static func stream_for(slot: String) -> AudioStream:
	if not FILES.has(slot) or FILES[slot].is_empty():
		return null
	if not cache.has(slot):
		var files: Array = FILES[slot]
		if files.size() == 1:
			cache[slot] = load(ROOT + files[0] + ".wav")
		else:
			var variants := AudioStreamRandomizer.new()
			variants.random_pitch = 1.0
			variants.random_volume_offset_db = 0
			variants.playback_mode = AudioStreamRandomizer.PLAYBACK_RANDOM
			for file in files:
				variants.add_stream(-1, load(ROOT + file + ".wav"), 1.0)
			cache[slot] = variants
	return cache[slot]
static func slot_labels() -> Dictionary:
	var labels := {}
	for slot in FILES:
		labels[slot] = "Yae · " + str(slot).trim_prefix("yae_").trim_prefix("move_").replace("_", " ").capitalize()
	return labels
