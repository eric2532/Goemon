extends RefCounted
## Cached native tag graph and original bitmap sprite atlas lookup.
const MANIFEST_PATH="res://assets/characters/master_chief/effects/manifest.json"
const METRES_PER_WORLD_UNIT=3.048
static var _cached_manifest:Dictionary={}
var tags:Dictionary={}
var revision:int=0
var _manifest:Dictionary={}
var _textures:Dictionary={}
var _frames:Dictionary={}
var _sequence_lengths:Dictionary={}

func _init(source:Dictionary={}):
	configure(source)

func configure(source:Dictionary={}):
	revision+=1
	if source.is_empty():
		if _cached_manifest.is_empty() and FileAccess.file_exists(MANIFEST_PATH):
			var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
			if parsed is Dictionary:_cached_manifest=parsed
		_manifest=_cached_manifest
	else:_manifest=source
	tags=_manifest.get("tags",{})
	_frames.clear();_sequence_lengths.clear()

func manifest()->Dictionary:
	return _manifest

func resolve(reference:Variant,class_name_:String="")->Dictionary:
	var path:String=""
	var cls:String=class_name_
	if reference is String:path=reference
	elif reference is Dictionary:
		# Already resolved native definitions can pass through unchanged.
		if not reference.has("path"):
			return reference.get("data",reference)
		path=str(reference.get("path",""))
		if cls.is_empty():cls=str(reference.get("class",""))
	if path.is_empty():return {}
	var key:String=str(_manifest.get("tag_keys",{}).get(cls,{}).get(path,path))
	var entry:Dictionary=tags.get(key,{})
	if not cls.is_empty() and str(entry.get("class",""))!=cls:return {}
	return entry.get("data",{})

func _lengths(bitmap_ref:Variant,path:String)->Array:
	if _sequence_lengths.has(path):return _sequence_lengths[path]
	var definition:Dictionary=resolve(bitmap_ref,"bitmap")
	var sequences:Array=definition.get("sequences",[])
	var lengths:Array=[]
	if sequences.is_empty():lengths.append(maxi(1,definition.get("bitmaps",[]).size()))
	else:
		for seq:Dictionary in sequences:
			lengths.append(maxi(1,maxi(seq.get("sprites",[]).size(),int(seq.get("bitmap_count",0)))))
	_sequence_lengths[path]=lengths
	return lengths

func sequence_length(bitmap_ref:Variant,sequence:int=0)->int:
	var path:String=str(bitmap_ref.get("path","")) if bitmap_ref is Dictionary else str(bitmap_ref)
	var lengths:Array=_lengths(bitmap_ref,path)
	return lengths[clampi(sequence,0,lengths.size()-1)]

func bitmap_frame(bitmap_ref:Variant,sequence:int=0,frame:float=0)->Dictionary:
	var path:String=str(bitmap_ref.get("path","")) if bitmap_ref is Dictionary else str(bitmap_ref)
	var lengths:Array=_lengths(bitmap_ref,path)
	var count:int=lengths[clampi(sequence,0,lengths.size()-1)]
	var frame_index:int=posmod(int(floor(frame)),count)
	# Array slots avoid rebuilding path/sequence/frame strings for every live
	# smoke sprite and casing on every frame. Atlases are immutable per manifest.
	if not _frames.has(path):_frames[path]={}
	var sequences_cache:Dictionary=_frames[path]
	if not sequences_cache.has(sequence):
		var slots:Array=[];slots.resize(count);sequences_cache[sequence]=slots
	var frames:Array=sequences_cache[sequence]
	if frames[frame_index] is Dictionary:return frames[frame_index]
	var definition:Dictionary=resolve(bitmap_ref,"bitmap")
	if definition.is_empty():return {}
	var bitmap_index:int=0
	var rect:Rect2=Rect2(0,0,1,1)
	var registration:Vector2=Vector2(.5,.5)
	var sequences:Array=definition.get("sequences",[])
	if not sequences.is_empty():
		var seq:Dictionary=sequences[clampi(sequence,0,sequences.size()-1)]
		var sprites:Array=seq.get("sprites",[])
		if not sprites.is_empty():
			var sprite:Dictionary=sprites[posmod(frame_index,sprites.size())]
			bitmap_index=int(sprite.get("bitmap_index",0))
			var left:float=float(sprite.get("left_side",0))
			var top:float=float(sprite.get("top_side",0))
			rect=Rect2(left,top,float(sprite.get("right_side",1))-left,float(sprite.get("bottom_side",1))-top)
			registration=Vector2(float(sprite.get("registration_point_x",rect.size.x*.5)),float(sprite.get("registration_point_y",rect.size.y*.5)))
		else:bitmap_index=int(seq.get("first_bitmap_index",0))+frame_index
	else:bitmap_index=frame_index
	var files:Array=_manifest.get("bitmaps",{}).get(path,{}).get("files",[])
	for file:Dictionary in files:
		if int(file.get("bitmap_index",0))!=bitmap_index:continue
		var file_path:String=str(file.get("path",""))
		if not _textures.has(file_path):
			_textures[file_path]=load(file_path) if ResourceLoader.exists(file_path) else null
		var texture:Texture2D=_textures[file_path]
		if texture==null:return {}
		var atlas_size:Vector2=Vector2(float(file.get("width",texture.get_width())),float(file.get("height",texture.get_height())))
		var result:Dictionary={"texture":texture,"path":file_path,"rect":rect,"uv_rect":rect,"registration":registration,"sprite_size":rect.size,"atlas_size":atlas_size,"bitmap_index":bitmap_index,"sequence":sequence,"frame":frame_index}
		frames[frame_index]=result
		return result
	return {}

func bitmap_sequence(bitmap_ref:Variant,sequence:int=0)->Array:
	var path:String=str(bitmap_ref.get("path","")) if bitmap_ref is Dictionary else str(bitmap_ref)
	var count:int=sequence_length(bitmap_ref,sequence)
	if not _frames.has(path) or not _frames[path].has(sequence):bitmap_frame(bitmap_ref,sequence,0)
	var frames:Array=_frames[path][sequence]
	for index:int in count:
		if not frames[index] is Dictionary:frames[index]=bitmap_frame(bitmap_ref,sequence,index)
	return frames
