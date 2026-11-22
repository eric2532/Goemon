extends "res://tests/forest-shrine/falan_architecture_test.gd"
const Fit=preload("res://scripts/forest/forest_falan_proportions.gd")

func check_east_il_road():
 var fortifications=game.model.CityFortifications.obstacles().duplicate()
 preload("res://tests/forest-shrine/falan_buildings_props_test.gd").model_signature(game.model)
 check(game.model.CityFortifications.obstacles()==fortifications,"Historical collider comparison preserves the shared native fortification bounds")
 check(Fit.Data.FITS.size()==40,"All 40 building archetypes have measured source proportions")
 for serial in Architecture.Data.GRAPHICS:check(Fit.matches(Architecture.prepare(serial),"house_%d"%serial,PI*.5),"House height and width match original pixels: "+str(serial))
 for anchor in Special.SPECS:
  var row:Array=Special.SPECS[anchor]
  check(Fit.matches(Special.prepare(row),"special_%d"%row[0],row[7]),"Distinctive exterior matches original dimensions: "+str(row[0]))
 check(Fit.matches(Workshop.prepare(),"special_10301",0),"Workshop source proportions are exact")
 check(Fit.matches(MagicShop.prepare(),"special_10075",0),"Magic shop source proportions are exact")
 for anchor in game.model.CivicExterior.SHELLS:
  var spec:Array=game.model.CivicExterior.SHELLS[anchor];var key="civic_%d"%spec[0]
  var node=game.world.find_child("FalanCivicFacade_%d"%spec[0],true,false)
  check(node!=null,"Native civic facade is present")
  if node==null:continue
  var measured=Fit.projected_bounds(Fit.node_points(node),Transform3D(node.basis,Vector3.ZERO));var source:Rect2=Fit.References.RECTS[key]
  check(measured.position.distance_to(source.position)<.05 and measured.size.distance_to(source.size)<.05,"Built civic geometry matches original height/width: "+key)
  if spec[0]==1301:
   var targets=Fit.References.COMPONENTS[key].duplicate();var wings=targets.slice(1);wings.sort_custom(func(a,b):return a.get_center().x<b.get_center().x)
   targets=[targets[0],wings[0],wings[1]]
   for i in 3:
    var part=node.find_child("MansionMainRotunda" if i==0 else "MansionPavilion%d"%(i-1),true,false)
    var pose=Transform3D(node.basis,Vector3.ZERO)*node.global_transform.affine_inverse()*part.global_transform
    var actual=Fit.projected_bounds(Fit.node_points(part),pose)
    check(actual.position.distance_to(targets[i].position)<.05 and actual.size.distance_to(targets[i].size)<.05,"Mansion component matches its own original source proportions: "+str(i))
  var samples=node.find_children("*","MeshInstance3D",true,false)
  var panes=samples.filter(func(part):return part.has_meta("falan_source_feature"))
  check((not game.model.CivicExterior.Details.Data.FACADES.has(spec[0]) or not panes.is_empty()) and panes.all(func(part):return part.get_active_material(0)==game.model.CivicExterior.Details.material(part.get_meta("falan_source_feature"))),"Native windows and signs retain their individual rectified materials: "+key)
 var native:Array=Tour.Indoor.Data.DOORS[1000]
 for row in native:
  var p=Vector3(row[0].x,game.model.surface_height(row[0].x,row[0].y)+.5,row[0].y)
  for anchor in game.model.CivicExterior.SHELLS:
   var spec:Array=game.model.CivicExterior.SHELLS[anchor]
   var clear=true
   for part:AABB in game.model.CivicExterior.collision_parts(anchor,spec):
    part.position+=game.model.scenery_point(anchor)
    if part.grow(.55).has_point(p):clear=false
   check(clear,"Source-scaled civic footprint preserves native doorway "+str(row[0])+" at "+str(anchor))
 for npc in Tour.NPCS.AREAS.city:
  var p=Vector3(npc[0].x,game.model.surface_height(npc[0].x,npc[0].y)+.5,npc[0].y)
  var clear=true
  for anchor in game.model.CivicExterior.SHELLS:
   for part:AABB in game.model.CivicExterior.collision_parts(anchor,game.model.CivicExterior.SHELLS[anchor]):
    part.position+=game.model.scenery_point(anchor)
    if part.has_point(p):clear=false
  check(clear,"Original NPC station remains clear of source-scaled civic bodies: "+str(npc[0]))
 await super.check_east_il_road()
 print("FALAN_CITY_PROPORTIONS_RESULT checks=",checks," failures=",errors)
