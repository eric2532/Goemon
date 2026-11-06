extends MeshInstance3D
## Original MDX geometry/particles sampled offline; all instances share immutable frames.
const ROOT="res://assets/characters/warcraft/mountain-king/effects/"
static var resources={}
var clips:Dictionary={}
func setup(key:String):
 if not resources.has(key):resources[key]=load(ROOT+key+".res")
 clips=resources[key].get_meta("clips")
 cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func pose(clip:String,time:float,loop:bool=false):
 if not clips.has(clip):hide();return
 var track:Dictionary=clips[clip]
 var at=fposmod(time,float(track.duration)) if loop and track.duration>0 else time
 mesh=track.frames[clampi(floori(at*30),0,track.frames.size()-1)]
 visible=at<=float(track.duration) and mesh.get_surface_count()>0
