extends "res://tests/forest-shrine/east_root_core_asset_review.gd"
## Retain exact original alpha/depth and color only surface ownership for diagnosis.
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Visual Landmarks/Ancient Root Surface Ownership/"
func root_mesh()->Mesh:
 var original:Mesh=RootTree.mesh();var result=original.duplicate();var rows=[]
 for slot in result.get_surface_count():
  var paint:ShaderMaterial=result.surface_get_material(slot).duplicate();var source:Texture2D=paint.get_shader_parameter("base_texture");var rgba=Image.load_from_file(ProjectSettings.globalize_path(source.resource_path));rgba.convert(Image.FORMAT_RGBA8);var color=Color.from_hsv(slot/10.,.9,.95);var bytes=rgba.get_data()
  for i in range(0,bytes.size(),4):bytes[i]=roundi(color.r*255);bytes[i+1]=roundi(color.g*255);bytes[i+2]=roundi(color.b*255)
  var flat=Image.create_from_data(rgba.get_width(),rgba.get_height(),false,Image.FORMAT_RGBA8,bytes);paint.set_shader_parameter("base_texture",ImageTexture.create_from_image(flat));paint.set_shader_parameter("original_palette",true);result.surface_set_material(slot,paint);rows.append({"surface":slot,"color":color.to_html(),"source_texture":source.resource_path})
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(review_path()));var f=FileAccess.open(review_path()+"surface-colors.json",FileAccess.WRITE);f.store_string(JSON.stringify(rows,"  "));f.close();return result
