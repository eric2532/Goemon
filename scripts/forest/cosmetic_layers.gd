extends RefCounted
## At most five layers on an existing character model; no simulation or target owner.
const Catalog=preload("res://scripts/forest/cosmetic_catalog.gd")
const Proportions=preload("res://scripts/character_proportions.gd")
const FOOT_EFFECTS=["cosmetic:115354","cosmetic:115469","cosmetic:115470","cosmetic:115606"]
var nodes:Array[Sprite3D]=[]
var selected:Array=[]
var elapsed=0.0

func configure(parent:Node3D,ids:Array):
 selected=ids.duplicate()
 while nodes.size()<selected.size():
  var node=Sprite3D.new();node.name="Cosmetic%d"%nodes.size();node.region_enabled=true
  node.billboard=BaseMaterial3D.BILLBOARD_ENABLED;node.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
  node.texture_filter=BaseMaterial3D.TEXTURE_FILTER_LINEAR
  node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
  parent.add_child(node);nodes.append(node)
 for i in nodes.size():
  nodes[i].visible=i<selected.size()
  if i<selected.size():Catalog.prepare(selected[i])

func update(delta:float,body:Sprite3D,pose:String,grounded:bool):
 elapsed+=delta
 if selected.is_empty():return
 var direction=int(pose.get_slice(":",pose.get_slice_count(":")-1))
 var action=int(pose.get_slice(":",pose.get_slice_count(":")-2))
 var head=Catalog.head(body.texture,body.region_rect)
 var head_anchor=body.offset+Vector2(head.x-body.region_rect.size.x*.5,body.region_rect.size.y*.5-head.y)
 for i in selected.size():
  var node=nodes[i];var item:Dictionary=Catalog.items()[selected[i]]
  var facing=0 if item.fixed_facing else direction
  var clip:Dictionary=item.clips.get("%d:%d"%[action,facing],item.clips.get("0:%d"%facing,{}))
  node.visible=body.visible and not clip.is_empty()
  if not node.visible:continue
  var count:int=clip.frames.size()
  var index=posmod(floori(elapsed/maxf(.001,float(clip.duration))*count),count)
  var frame:Array=clip.frames[index];var page=int(frame[0])
  node.texture=Catalog.pages[page];node.material_override=Catalog.materials[page]
  node.region_rect=Rect2(frame[1],frame[2],frame[3],frame[4])
  node.pixel_size=body.pixel_size;node.position=body.position;node.modulate=body.modulate
  var anchor=Vector2(0,Proportions.CROSSGATE_FEET_PIXELS) if selected[i] in FOOT_EFFECTS else head_anchor
  node.offset=anchor+Vector2(float(frame[5])+float(frame[3])*.5,-float(frame[6])-float(frame[4])*.5)
  node.set_instance_shader_parameter("grounded",grounded)
  node.set_instance_shader_parameter("layer_depth",-.025-float(i)*.001 if item.kind=="wings" and direction not in [0,1,2] else .008+float(i)*.001)
