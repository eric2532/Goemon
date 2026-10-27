extends SceneTree
const Bank=preload("res://scripts/character_audio_bank.gd")
const MoveAudio=preload("res://scripts/move_audio.gd")
var checks=0
var failures=0
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: ",label_)
func _initialize():run.call_deferred()
func run():
 var lib=SoundLibrary.new();lib.config_path="user://skill-audio-prepare-%d.cfg"%OS.get_process_id();root.add_child(lib)
 var owner=Node.new();root.add_child(owner);var audio=MoveAudio.new();audio.prepare(owner)
 var voices=audio.voices.duplicate();audio.prepare(owner)
 check(audio.voices==voices and owner.get_child_count()==8,"Paired voices are prepared once without playing or replacing them")
 check(audio.voices.all(func(v):return not v.playing),"Preparing voices produces no combat audio")
 seed(91824);var expected=randf();seed(91824)
 for id in [14,15,16,17,28,29,30]:lib.prepare_character(id)
 check(randf()==expected,"Audio preparation preserves gameplay randomness")
 check(lib.character_id==1,"Preparing a selected fighter does not switch Sound Studio")
 var cached=Bank.streams.size();var resources=Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
 for repeat in 3:
  for id in [14,15,16,17,28,29,30]:
   lib.prepare_character(id)
   for slot in SoundLibrary.slots_for(id):lib.playback_for(id,slot,null)
 check(Bank.streams.size()==cached,"Every audited cue reuses its prepared audio sample or variant")
 check(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)==resources,"Repeated cue resolution creates no resources")
 lib.free();owner.free();print("SKILL_AUDIO_PREPARATION_RESULT checks=",checks," failures=",failures);quit(1 if failures else 0)
