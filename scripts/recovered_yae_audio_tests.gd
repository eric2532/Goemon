extends SceneTree
## Catches missing original events, collapsed source variants, fabricated silent
## actions and named-move playback accidentally doubling the separate voice cue.
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var path := "res://scripts/recovered_yae_audio.gd"
	check(ResourceLoader.exists(path), "Yae original audio helper must exist")
	if not ResourceLoader.exists(path):
		print("YAE_AUDIO_RESULT checks=", checks, " failures=", failures)
		quit(1)
		return
	var original = load(path)
	for slot in original.FILES:
		var stream = original.stream_for(slot)
		if original.FILES[slot].is_empty():
			check(stream == null, "Source silent action has no fabricated sound: " + slot)
		elif stream is AudioStreamWAV:
			check(stream.mix_rate == 44100 and stream.stereo and stream.get_length() > .01, "Original event loads as stereo PCM: " + slot)
		elif stream is AudioStreamRandomizer:
			check(stream.random_pitch == 1.0 and stream.random_volume_offset_db == 0, "Native pitch and volume are preserved: " + slot)
			for i in stream.streams_count:
				check(stream.get_stream(i) is AudioStreamWAV, "Native weighted variant loads: " + slot)
		else:
			check(false, "Verified source event loads: " + slot)
	var jump = original.stream_for("jump") as AudioStreamRandomizer
	check(jump != null and jump.streams_count == 3, "Jump retains three native random choices")
	if jump != null:
		check(jump.get_stream(0) != jump.get_stream(1) and jump.get_stream(1) != jump.get_stream(2), "Yae jump choices retain three different source voices")
	var hurt = original.stream_for("hurt") as AudioStreamRandomizer
	check(hurt != null and hurt.streams_count == 3, "Hurt retains three native voices")
	var death = original.stream_for("death") as AudioStreamRandomizer
	check(death != null and death.streams_count == 2, "Death retains two native voices")
	var finish = original.stream_for("move_primary_3_voice") as AudioStreamRandomizer
	check(finish != null and finish.streams_count == 3, "Finisher retains all native random choices")
	if finish != null:
		check(finish.get_stream(1) == finish.get_stream(2), "Finisher preserves source 3A2 two-of-three weight")
	check(original.stream_for("move_primary_2_voice") == null, "Second katana strike is source silent")
	check(original.stream_for("move_utility_voice") == null, "Sword Shield adds no invented voice")
	check(original.stream_for("dash") == null, "Unverified dash remains source silent")
	check(original.stream_for("step") is AudioStreamWAV, "Native land locomotion uses its recovered footfall event")
	check(original.stream_for("unverified_foreign_sound") == null, "Unknown slots return no substitute")
	check(original.stream_for("yae_katana_1") == original.stream_for("move_primary_1_weapon"), "Named first katana slot uses only weapon layer")
	check(original.stream_for("yae_bazooka") == original.stream_for("move_secondary_weapon"), "Named bazooka slot does not replay the separate voice")
	check(original.stream_for("yae_lock_on") == original.stream_for("move_charged_weapon"), "Named lock-on slot uses only weapon layer")
	check(original.slot_labels().has("yae_bazooka_impact"), "Original impacts are available in Sound Studio")
	print("YAE_AUDIO_RESULT checks=", checks, " failures=", failures)
	quit(1 if failures else 0)
