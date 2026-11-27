extends RefCounted
## An optional art file can change atlas paths and frame rectangles, not the motion clock.

static func paths(root:String,data:Dictionary)->Array[String]:
 var result:Array[String]=[]
 if data.has("art_pages"):
  result.assign(data.art_pages)
  return result
 for i in int(data.pages):result.append(root+"atlas-%d.png"%i)
 if data.get("has_cast_atlas",false):
  for i in int(data.get("cast_pages",1)):result.append(root+"cast-%d.png"%i)
 return result

static func apply(root:String,data:Dictionary,art:Variant)->String:
 if not art is Dictionary:return "Expected a JSON object."
 for field in art:
  if field not in ["pages","stances"]:return "Unknown art field: "+field
 var new_pages=art.get("pages",[])
 var overrides=art.get("stances",[])
 var stances=[data]+data.get("weapons",[])
 if not new_pages is Array or not overrides is Array or overrides.size()>stances.size():
  return "Expected a page list and at most %d stance maps."%stances.size()
 var sheets=paths(root,data).duplicate()
 var changed_pages={}
 var sizes={}
 for i in new_pages.size():
  var name=new_pages[i]
  if name==null and i<sheets.size():continue
  if not name is String or name.is_empty():return "Missing texture for page %d."%i
  var path:String=name if name.begins_with("res://") else root+name
  if not ResourceLoader.exists(path,"Texture2D"):return "Cannot find texture "+path
  var texture=load(path) as Texture2D
  if texture==null:return "Cannot load texture "+path
  if i==sheets.size():sheets.append(path)
  else:sheets[i]=path
  changed_pages[i]=true
  sizes[i]=texture.get_size()
 for i in stances.size():
  var clips:Dictionary=stances[i].clips
  var replacement=overrides[i] if i<overrides.size() else {}
  if not replacement is Dictionary:return "Expected a clip map for stance %d."%i
  for key in replacement:
   if not clips.has(key):return "Unknown clip %s in stance %d."%[key,i]
  for key in clips:
   var replaces_frames:bool=replacement.has(key)
   if not replaces_frames and changed_pages.is_empty():continue
   var old:Array=clips[key].frames
   var frames=replacement.get(key,old)
   if not frames is Array or frames.size()!=old.size():
    return "Stance %d clip %s needs %d frames to keep its original timing."%[i,key,old.size()]
   for frame in frames:
    if replaces_frames and not valid_frame(frame,sheets.size()):
     return "Invalid frame in stance %d clip %s."%[i,key]
    var page=int(frame[0])
    if not replaces_frames and not changed_pages.has(page):continue
    if not sizes.has(page):
     var texture=load(sheets[page]) as Texture2D
     if texture==null:return "Cannot load texture "+sheets[page]
     sizes[page]=texture.get_size()
    var limit:Vector2=sizes[page]
    if frame[1]+frame[3]>limit.x or frame[2]+frame[4]>limit.y:
     return "Frame exceeds page %d in stance %d clip %s."%[page,i,key]
 for i in overrides.size():
  for key in overrides[i]:stances[i].clips[key].frames=overrides[i][key]
 data.art_pages=sheets
 return ""

static func valid_frame(frame:Variant,page_count:int)->bool:
 if not frame is Array or frame.size()!=7:return false
 for value in frame:
  if not (value is float or value is int) or not is_finite(value) or value!=floorf(value):return false
 return frame[0]>=0 and frame[0]<page_count and frame[1]>=0 and frame[2]>=0 and frame[3]>0 and frame[4]>0
