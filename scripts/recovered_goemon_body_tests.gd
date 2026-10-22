extends SceneTree
const Body=preload("res://scripts/recovered_goemon_body.gd")
var checks=0
var failures=0
func _initialize():run.call_deferred()
func check(ok:bool,label_:String):
 checks+=1
 if not ok:failures+=1
 print("PASS: " if ok else "FAIL: ",label_)
func channels_match(parts:Dictionary,pair:Array)->bool:
 var seen=[0,0]
 for mesh in parts[Body.HEAD_POINTER].get_children():
  for i in range(mesh.mesh.get_surface_count()):
   var mat=mesh.mesh.surface_get_material(i)
   if mat.has_meta("native_face_channel"):
    var channel:int=mat.get_meta("native_face_channel")
    var texture:Texture2D=mat.get_shader_parameter("source_texture")
    if not texture.resource_path.ends_with("face_%s.png"%pair[channel]):return false
    seen[channel]+=1
 return seen[0]>0 and seen[1]>0
func run():
 var parts=Body.create_parts()
 check(parts.size()==13,"Original body still has thirteen rigid parts")
 check(channels_match(parts,["823f","823f"]),"Idle face uses matching original half-face expressions")
 Body.set_face(parts,15,0)
 check(channels_match(parts,["823e","823e"]),"Running selects the original matching neutral expressions")
 Body.set_face(parts,104,0)
 check(channels_match(parts,["8249","824c"]),"Gold Pipe attack uses its original paired grimace on normal and golden heads")
 Body.set_face(parts,0,1.01/12.0)
 check(channels_match(parts,["8240","8240"]),"Idle blinking follows the original ROM frame-one facial event")
 var pelvis:MeshInstance3D=parts["0x9004f48"].get_node("mesh")
 var material:ShaderMaterial=pelvis.mesh.surface_get_material(0)
 check(material.get_shader_parameter("tile_modes")==Vector2(1,2),"Clothing preserves native mirror-S and clamp-T")
 check(material.get_shader_parameter("mask_period")==Vector2(32,32),"Clothing wraps its original32-texel mask inside64-pixel image")
 var head:MeshInstance3D=parts[Body.HEAD_POINTER].get_node("normal")
 var face:ShaderMaterial=head.mesh.surface_get_material(1)
 check(face.get_shader_parameter("tile_modes")==Vector2(2,2),"Facial texture clamps rather than repeating across the face seam")
 check(Body.data().face.actions.size()==232,"All232 original actions have recovered facial timelines")
 Body.set_golden(parts,true)
 check(parts[Body.HEAD_POINTER].get_node("golden").visible and not head.visible,"Original golden head swap remains intact")
 Body.set_golden(parts,false)
 check(head.visible and not parts[Body.HEAD_POINTER].get_node("golden").visible,"Original normal head restores without material loss")
 for part in parts.values():part.free()
 print("GOEMON_BODY_RENDER_RESULT checks=%d failures=%d"%[checks,failures]);quit(1 if failures else 0)
