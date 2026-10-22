extends "res://scripts/recovered_ed_beam_tests.gd"
## Lifecycle values are literal source actor updates, not cast elapsed aliases.

func run():
	beam_script=load("res://scripts/recovered_ed_beam.gd")
	arena=Arena.new();root.add_child(arena)
	lib=SoundLibrary.new();lib.config_path="user://ed-beam-phase-%d/studio.cfg"%OS.get_process_id();lib.folder="user://ed-beam-phase-%d/recordings"%OS.get_process_id()
	arena.add_child(lib);lib.set_process(false);arena.sound_library=lib;lib.custom_for(14,"ed_beam_charge")
	caster=Caster.new();caster.character_id=14;caster.game=arena;arena.player=caster;arena.add_child(caster)
	var first=beam()
	check(first.has_method("native_state"),"Beam exposes persistent source actor phase separately from cast age")
	if failures:clear();arena.free();quit(1);return
	var native=first.native_state()
	check(native.main_updates==1 and native.roll_angle==120 and native.main_palette_row==0,"First cast performs original roll120 and phase15 update")
	check(native.shield_updates==1 and native.shield_phase==1337,"Shield's first active update is phase minus199 modulo1536")
	check(native.roll_basis_q12.x==Vector3(4026,750,0) and native.roll_basis_q12.y==Vector3(-750,4026,0),"First roll uses literal packed RotMatrix pair750/4026")
	check(first.visual.entry.position==Vector3(-5,32,-128),"Entry orbit uses source integer transformation")
	first.advance(10.25/30.0)
	check(first.native_state().main_updates==11 and first.native_state().shield_updates==11,"Only complete30Hz updates advance both active phases")
	var before=first.native_state();first.update_path();first.damage_tick();first.advance(0)
	check(first.native_state()==before,"Repeated aim and contact sampling cannot advance native actor phases")
	arena.paused=true;first.advance(4);first._process(4)
	var global_before=first.companion_clock.ticks;first.companion_clock.advance(2)
	await create_timer(.08).timeout
	check(first.native_state()==before,"Pause freezes active native actor phases")
	check(first.companion_clock.ticks==global_before,"Companion gameplay clock cannot jump across paused engine frames")
	arena.paused=false;first.release()
	check(first.native_state().main_updates==12 and first.native_state().shield_updates==12,"Release transition performs its own native actor update")
	check(first.shield.material.get_shader_parameter("release_tick")==1,"First native ownerstate6 update already subtracts one Q12 intensity step")
	first._process(15.0/30.0)
	check(first.native_state().main_updates==27 and first.native_state().shield_updates==27,"Release advances both phases through its fifteenth timed update")
	first._process(1.0/30.0)
	var saved=caster.get_meta("ed_native_beam_phase")
	var gameplay_clock=first.companion_clock
	check(saved.main_updates==28 and saved.shield_updates==27,"Final hidden main tick advances independently after the shield owner leaves state6")
	global_before=gameplay_clock.ticks;gameplay_clock.advance(3.0/30.0)
	check(gameplay_clock.ticks==posmod(global_before+3,65536),"Companion global clock continues with gameplay while Ed's effect is idle")
	await create_timer(.12).timeout
	check(saved.main_updates==28 and saved.shield_updates==27,"Native phases remain frozen between casts")
	var second=beam();var second_state=second.native_state()
	check(second_state.main_updates==29 and second_state.roll_angle==3480 and second_state.main_palette_row==12,"Second cast resumes persistent roll and main palette phase")
	check(second_state.shield_updates==28 and second_state.shield_phase==572,"Second shield resumes its independent source color phase")
	check(second.visual.main.scale.is_zero_approx() and second.shield.material.get_shader_parameter("native_scale")==Vector3.ONE*.25,"New cast resets growth independently of persistent phases")
	check(second.visual.entry.position==Vector3(26,19,-128),"Second cast's entry orbit follows persistent source roll")
	check(second.native_state().companion_palette_row==posmod(gameplay_clock.ticks,8),"Companion palette follows global gameplay frames independently of cast age")
	second.stop()
	var another=Caster.new();another.character_id=14;another.game=arena;arena.add_child(another)
	var other_beam=beam_script.new();other_beam.hero=another;other_beam.game=arena;arena.add_child(other_beam)
	check(other_beam.native_state().main_updates==1 and other_beam.native_state().shield_updates==1,"Different playable Ed actors own independent native phases")
	other_beam.free();another.free();clear();arena.free();await process_frame
	await create_timer(.35).timeout
	print("RECOVERED_ED_BEAM_PHASE_RESULT checks=",checks," failures=",failures)
	quit(1 if failures else 0)
