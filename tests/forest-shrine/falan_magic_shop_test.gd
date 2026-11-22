extends "res://tests/forest-shrine/falan_workshop_test.gd"
const MagicShop=preload("res://scripts/forest/forest_falan_magic_shop.gd")

func check_east_il_road():
 game.tuning.invincible=true;game.settings.forest_level_up_cards=false
 check(MagicShop.active(game.model),"The unchanged original magic shop marker activates its source exterior")
 var nodes=game.world.find_children("RecoveredFalanMagicShop10075","MeshInstance3D",true,false)
 check(nodes.size()==1,"Magic shop is one static solid assembly")
 if not nodes.is_empty():
  var bounds:AABB=nodes[0].mesh.get_aabb()
  check(MagicShop.Proportions.matches(nodes[0].mesh,"special_10075",0),"Magic shop height and width match its native source")
  var roofs_up=true;var roof_vertices=0
  for part in nodes[0].mesh.get_surface_count():
   var arrays=nodes[0].mesh.surface_get_arrays(part)
   for i in arrays[Mesh.ARRAY_VERTEX].size():
    if not arrays[Mesh.ARRAY_NORMAL][i].is_finite():roofs_up=false
    if arrays[Mesh.ARRAY_TEX_UV2][i]==Houses.Data.TILES["magic_roof"]:
     roof_vertices+=1
     if arrays[Mesh.ARRAY_NORMAL][i].y<-.001:roofs_up=false
  check(roofs_up and roof_vertices>0,"Native purple roof surfaces face upward and normals remain finite")
 var original=game.model.props[MagicShop.ANCHOR]
 var changed=original.duplicate();changed.scale+=.01;game.model.props[MagicShop.ANCHOR]=changed
 check(not MagicShop.active(game.model),"User-scaled magic shops retain their custom appearance")
 game.model.props[MagicShop.ANCHOR]=original
 var source_box:AABB=game.model.scenery_obstacles[MagicShop.ANCHOR]
 check(not source_box.grow(.55).has_point(Vector3(-168,1,177)),"The original magic shop door stays clear of its corrected source collision")
 var scale_:float=game.model.falan_scale
 await shot("magic-shop-city",Vector3(-139,23,195)*scale_,Vector3(-168,7,165)*scale_,52)
 await shot("magic-shop-front",Vector3(-168,11,195)*scale_,Vector3(-168,6,172)*scale_,48)
 var cached=MagicShop.prepare()
 await room(1041)
 if Tour.area(game.model)!="interior":return
 var exits=game.model.get_meta("falan_links",[]).filter(func(link):return link.to=="city")
 check(not exits.is_empty(),"Magic shop retains its original city exit")
 if exits.is_empty():return
 await position_at(exits[0].at)
 if Tour.area(game.model)=="interior":await walk_through_entry()
 check(Tour.area(game.model)=="city","Magic shop original room returns to Falan")
 await super.check_east_il_road()
 check(is_same(cached,MagicShop.prepare()),"Room and gate returns reuse the magic shop mesh")
 print("FALAN_MAGIC_SHOP_RESULT checks=",checks," failures=",errors)
