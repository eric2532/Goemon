extends RefCounted
## Disc-derived dry samples at retail playback rates. Voice trigger reuse and
## original target/material distinctions are documented with the assets.
const ROOT="res://assets/audio/recovered_musashi/"
const FILES={
	"swing":"fusion_swing", "heavy_swing":"lumina_swing",
	"hit":"sword_hit", "heavy_hit":"sword_hit", "fusion_finisher_hit":"fusion_finisher_hit",
	"environment_hit":"sword_environment_hit", "hurt":"voice_hurt", "jump":"", "land":"foot_contact",
	"musashi_step_0":"foot_contact", "musashi_step_1":"foot_contact", "ground_stop":"land",
	"musashi_rotation":"lumina_rotation", "musashi_spin":"lumina_spin", "musashi_guard_spark":"guard_spark",
	"fusion_air_swing":"fusion_air_swing", "fusion_fourth_hit":"lumina_rotation",
	"move_primary_1_weapon":"fusion_swing", "move_primary_2_weapon":"fusion_swing_2", "move_primary_3_weapon":"fusion_swing",
	"move_heavy_weapon":"lumina_swing",
	"move_primary_1_voice":"", "move_primary_2_voice":"", "move_primary_3_voice":"",
	"move_primary_4_weapon":"fusion_air_swing", "move_primary_4_voice":"voice_exertion",
	"move_heavy_voice":"", "move_rotation_weapon":"lumina_spin", "move_rotation_voice":""
}
static var cache={}
static func stream_for(slot: String)->AudioStream:
	if not FILES.has(slot):return null
	var file: String=FILES[slot]
	if file.is_empty():return null
	if not cache.has(file):cache[file]=load(ROOT+file+".wav")
	return cache[file]
