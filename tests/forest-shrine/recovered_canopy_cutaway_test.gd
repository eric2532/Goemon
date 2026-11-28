extends "res://tests/forest-shrine/original_maps_test.gd"
const Art=preload("res://scripts/forest/forest_wind_meadow_art.gd")
func run():
 var source=ArrayMesh.new();var box=BoxMesh.new()
 source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,box.surface_get_arrays(0));source.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,box.surface_get_arrays(0))
 var wood=StandardMaterial3D.new();source.surface_set_material(0,wood)
 var leaves=ShaderMaterial.new();leaves.shader=preload("res://scripts/forest/forest_painterly_environment.gd").SURFACE
 var texture=load("res://assets/maps/falan/east_region/native_trees/10066-foliage.png");leaves.set_shader_parameter("base_texture",texture);leaves.set_shader_parameter("original_palette",true);leaves.set_shader_parameter("alpha_cutout",true);source.surface_set_material(1,leaves)
 var parent=Node3D.new();root.add_child(parent);var batches=[]
 for i in 2:
  var node=MultiMeshInstance3D.new();node.set_meta("source_graphic",10066);node.multimesh=MultiMesh.new();node.multimesh.transform_format=MultiMesh.TRANSFORM_3D;node.multimesh.mesh=source;node.multimesh.instance_count=2;parent.add_child(node);batches.append(node)
 var world={"fog_materials":[]};Art.register_recovered_canopies(world,parent)
 var owned:Mesh=batches[0].multimesh.mesh;var canopy:ShaderMaterial=owned.surface_get_material(1)
 check(owned!=source and batches[1].multimesh.mesh==owned,"Recovered batches share one scene-owned mesh without mutating the cached source")
 check(owned.get_surface_count()==source.get_surface_count()and owned.get_aabb()==source.get_aabb(),"Canopy binding preserves source geometry bounds and surfaces")
 check(owned.surface_get_arrays(0)==source.surface_get_arrays(0)and owned.surface_get_arrays(1)==source.surface_get_arrays(1),"Every original leaf/trunk vertex, normal, UV and index is preserved")
 check(owned.surface_get_material(0)==wood,"The original trunk material remains untouched")
 check(canopy!=leaves and leaves.get_shader_parameter("canopy_layer")!=true,"Leaf-only cutaway owns its material without changing source resources")
 check(canopy.get_shader_parameter("base_texture")==texture and canopy.get_shader_parameter("original_palette")==true and canopy.get_shader_parameter("alpha_cutout")==true,"Original leaf paint, palette and alpha remain intact")
 check(canopy.get_shader_parameter("canopy_layer")==true and canopy.get_shader_parameter("fog_enabled")!=true,"Source canopy uses the existing cutaway without enabling arena fog")
 check(world.fog_materials==[canopy]and batches.all(func(node):return node.multimesh.instance_count==2),"One material joins existing live hero/cutaway updates and all source instances remain")
 Art.register_recovered_canopies(world,parent)
 check(batches[0].multimesh.mesh==owned and world.fog_materials==[canopy],"Repeated setup does not duplicate meshes or bindings")
 world.fog_materials=[];Art.register_recovered_canopies(world,parent)
 check(batches[0].multimesh.mesh==owned and world.fog_materials==[canopy],"Cached scenery reconnects to the active world without reconstructing resources")
 parent.free()
 print("RECOVERED_CANOPY_RESULT checks=",checks," failures=",failures)
 finish()
