extends SceneTree
var checks=0
var failures=0
func check(ok: bool,label: String):
	checks+=1
	if not ok:failures+=1;push_error(label)
func _initialize():
	call_deferred("run")
func run():
	var path="res://scripts/recovered_sasuke_audio.gd"
	check(ResourceLoader.exists(path),"Sasuke original event library must exist")
	if not ResourceLoader.exists(path):
		print("SASUKE_AUDIO_RESULT checks=",checks," failures=",failures);quit(1);return
	var original=load(path)
	for slot in original.FILES:
		var stream=original.stream_for(slot)
		if original.FILES[slot].is_empty():
			check(stream==null,"Source silent action returns no fabricated sound: "+slot)
		elif stream is AudioStreamWAV:
			check(stream.mix_rate==44100 and stream.stereo and stream.get_length()>.01,"Source event is playable stereo PCM: "+slot)
		elif stream is AudioStreamRandomizer:
			check(stream.random_pitch==1.0 and stream.random_volume_offset_db==0,"Source variant preserves pitch and level: "+slot)
			for n in stream.streams_count:check(stream.get_stream(n)!=null,"Weighted source variant loads: "+slot)
		else:check(false,"Verified Sasuke event must load: "+slot)
	var jump=original.stream_for("jump") as AudioStreamRandomizer
	check(jump!=null and jump.streams_count==3,"Jump retains all three native random choices")
	if jump!=null:check(jump.get_stream(1)==jump.get_stream(2),"Native jump voice38C has its original two-of-three weight")
	check(original.stream_for("move_primary_2_voice")==null,"Second kunai strike is source silent")
	check(original.stream_for("move_hair_up_voice")==null,"Native hair attack adds no invented voice")
	check(original.stream_for("unverified_foreign_sound")==null,"Unknown slots return no substitute")
	check(original.stream_for("sasuke_kunai_impact")==original.stream_for("sasuke_ice_impact"),"Native tier3 kunai class24 uses source victim event221")
	check(original.stream_for("sasuke_kunai_impact")!=original.stream_for("sasuke_hair_impact"),"Kunai tier3 and hair preserve different source contact events")
	check(original.stream_for("sasuke_jetpack_loop") is AudioStreamWAV,"Original jetpack sustain loads")
	var jet=original.stream_for("sasuke_jetpack_loop") as AudioStreamWAV
	if jet!=null:check(jet.loop_mode==AudioStreamWAV.LOOP_DISABLED and jet.get_length()>1.52 and jet.get_length()<1.55,"Jetpack preserves the finite source event with its internal ADPCM loops")
	check(original.slot_labels().has("sasuke_bomb_explode"),"Source impact events are exposed to the audio studio")
	print("SASUKE_AUDIO_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
