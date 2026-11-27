extends "res://tests/forest-shrine/east_carved_pier_maps_review.gd"
## Uses canonical scenery dispatch. No scene-only mesh replacement.
func review_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Mouse Room Piers/Carved Published Actual/"
func source_census_path()->String:return "res://build/Other Files/Asset Toolkit/East Gate Region/Mouse Room Piers/Carved Private Actual/native-placements.json"
func fixture_scope()->String:return "Canonical1230051dispatch: full178placement/10map source census, six33608scene instances, original walk/links and reachable camera pair. No mesh swap; other carved appearances and room art remain unfinished."
func camera_view(id:int,wanted:Vector2i,center:Vector2,height:float,second:bool,target_bounds:AABB)->Dictionary:
 if not swapped:
  var total=0
  for node:MultiMeshInstance3D in game.world.map_features.find_children("*","MultiMeshInstance3D",true,false):
   if int(node.get_meta("source_graphic",-1))!=1230051:continue
   check(node.multimesh.mesh==Carved.mesh(1230051,Maps.Art.data().graphics["1230051"]),"Canonical dispatch owns this exact source appearance without a fixture swap")
   total+=node.multimesh.instance_count
  check(total==6,"Canonical room retains all six original1230051placements")
  check(game.FalanTour.Regions.private_source_context==null,"Canonical source context remains default-off")
  observations.append({"canonical_owner":1230051,"placements":total,"fixture_mesh_swap":false})
  swapped=true
 return await super.camera_view(id,wanted,center,height,second,target_bounds)
