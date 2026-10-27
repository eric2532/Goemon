extends RefCounted
## One immutable sample/weighted-variant cache; character files supply event maps.
static var streams:Dictionary={}
static func event(root:String,files:Dictionary,slot:String)->AudioStream:
	if not files.has(slot) or files[slot].is_empty():return null
	var names:Array=files[slot] if files[slot] is Array else [files[slot]]
	var key=root+JSON.stringify(names)
	if not streams.has(key):
		if names.size()==1:streams[key]=sample(root+names[0]+".wav")
		else:
			var variants=AudioStreamRandomizer.new()
			variants.random_pitch=1;variants.random_volume_offset_db=0
			variants.playback_mode=AudioStreamRandomizer.PLAYBACK_RANDOM
			for name in names:variants.add_stream(-1,sample(root+name+".wav"),1)
			streams[key]=variants
	return streams[key]

static func sample(path:String)->AudioStream:
	if not streams.has(path):streams[path]=load(path)
	return streams[path]
