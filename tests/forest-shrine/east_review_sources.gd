extends RefCounted
## Record the code actually loaded by a review, not a later on-disk revision.
static func snapshot(paths:Array)->Dictionary:
 var result={}
 for raw_path:String in paths:
  var path=raw_path.trim_prefix("res://")
  if path.ends_with(".gd"):
   var script=load("res://"+path)
   result[path]=script.get_source_code().sha256_text()
  else:result[path]=FileAccess.get_sha256("res://"+path)
 return result
static func changed(before:Dictionary)->Array:
 var result=[]
 for raw_path:String in before:
  var path=raw_path.trim_prefix("res://")
  if FileAccess.get_sha256("res://"+path)!=before[raw_path]:result.append(path)
 return result
