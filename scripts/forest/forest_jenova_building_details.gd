extends RefCounted
## Jenova's original paint fitted to the shared solid town architecture.
const Parts=preload("res://scripts/forest/forest_tina_building_details.gd")
const Harbor=preload("res://scripts/forest/forest_tina_harbor_details.gd")
const IDS=[11400,11404,11405]
const ROOFS={
 11400:[Vector2(163,35),Vector2(16,136),Vector2(145,239),Vector2(305,128)],
 11404:[Vector2(223,1),Vector2(68,130),Vector2(286,291),Vector2(444,187)],
 11405:[Vector2(176,28),Vector2(25,135),Vector2(174,245),Vector2(329,128)]
}
const DOORS={
 11400:[Vector2(96,281),Vector2(96,213),Vector2(99,200),Vector2(107,194),Vector2(115,197),Vector2(124,210),Vector2(125,302)],
 11405:[Vector2(200,385),Vector2(200,319),Vector2(204,306),Vector2(215,302),Vector2(225,308),Vector2(233,320),Vector2(233,363)]
}

static func well(g:Dictionary,pixel_height:float)->Mesh:
 var native=Harbor.skin(g);var wood=Harbor.structure()
 native.texture=Harbor.Art.solid_texture(int(g.page))
 var stone=Harbor.Paint.new([Rect2(0,0,g.rect[2],g.rect[3]),Vector2.ZERO,Vector2.ONE,0],load("res://assets/maps/original_crossgate/jenova-well-stone.png"),Harbor.PIXEL_HEIGHT)
 var center=Harbor.point(Vector2(65,137),0,g)
 var pixel=Harbor.PIXEL_HEIGHT;var radius=42*3/(32*sqrt(2.0))
 # shortcut: Hidden stone and shingles mirror the visible half until original rear views are available.
 Parts.round_roof(stone,center,radius,radius,[[1,0,137,29],[1.03,2.4,113,29],[.72,2.4,110,20],[.72,.8,100,12],[.01,.8,108,0]],65,42,true)
 var roof_center=center+Vector3(.09375,0,.09375)
 Parts.round_roof(native,roof_center,55*3/(32*sqrt(2.0)),55*3/(32*sqrt(2.0)),[[1,82*pixel,55,36],[1,83*pixel,54,36],[.91,98*pixel,39,28],[.94,98*pixel,39,28],[.94,99*pixel,38,28],[.69,116*pixel,21,19],[.72,116*pixel,21,19],[.72,117*pixel,20,19],[.34,129*pixel,8,8],[.36,129*pixel,8,8],[.36,130*pixel,7,8],[.01,134*pixel,3,0]],67,55,true)
 wood.part="jenova_well_wood"
 Parts.Parts.kili_round(wood,roof_center,[Vector2(0,82*pixel-.08),Vector2(55*3/(32*sqrt(2.0)),82*pixel-.08),Vector2(55*3/(32*sqrt(2.0)),82*pixel)])
 for post in [[Vector2(6,141),Vector2(22,61)],[Vector2(78,190),Vector2(73,81)],[Vector2(119,162),Vector2(109,63)]]:
  Harbor.rod(wood,Harbor.point(post[0],0,g),Harbor.point(post[1],82*pixel,g),.21,"jenova_well_wood")
 var pose=Transform3D(Basis.IDENTITY.scaled(Vector3(1,pixel_height/Harbor.PIXEL_HEIGHT,1)),Vector3.ZERO)
 var result=Parts.join(wood.finish(),native.finish(),pose,stone.finish())
 result.set_meta("native_well",true)
 return result

static func doorway(native,skin,serial:int,body:Vector3,w:float,d:float,h:float)->Dictionary:
 var face="left" if serial==11400 else "right"
 var quad:Array=Parts.crops()["jenova_%d_%s"%[serial,face]][1]
 var pixels:Array=DOORS[serial]
 Parts.frame(native,skin,pixels,quad,body,w,d,h,face,"stone")
 var a=Parts.face_point(pixels[0],quad,body,w,d,h,face)
 var b=Parts.face_point(pixels[-1],quad,body,w,d,h,face)
 return {"at":(a+b)*.5,"width":a.distance_to(b)+.6,"face":face}

static func green_details(native,skin,body:Vector3,w:float,d:float,h:float):
 var quad:Array=Parts.crops().tina_11403_left[1]
 for item in [[Vector2(139,312),1.0],[Vector2(164,334),.9]]:
  var at=Parts.face_point(item[0],quad,body,w,d,h,"left")
  at.x-=.75;at.y=.50
  Harbor.cask(skin,at+Vector3.UP*h*.105*item[1],Vector3.UP,h*.21*item[1],d*.083*item[1],"tina_barrel_brown")
  if item[1]==1.0:
   skin.part="tina_barrel_brown"
   Parts.Parts.kili_round(skin,at+Vector3.UP*h*.21,[Vector2(d*.04,0),Vector2(d*.045,h*.10),Vector2(d*.034,h*.10),Vector2(d*.03,.03)])
 var post=Parts.face_point(Vector2(207,397),quad,body,w,d,h,"left")
 post.x-=.8;post.y=.50
 var levels=[[0,.66],[.55,.66],[.57,1],[.64,1],[.67,.8],[.84,.8],[.87,.56],[1,.65]]
 var left=[[Vector2(185,394),Vector2(204,407)],[Vector2(185,327),Vector2(204,339)],[Vector2(174,319),Vector2(204,340)],[Vector2(174,309),Vector2(204,330)],[Vector2(185,302),Vector2(206,316)],[Vector2(185,283),Vector2(206,296)],[Vector2(190,279),Vector2(207,290)],[Vector2(194,269),Vector2(210,280)]]
 var right=[[Vector2(204,407),Vector2(225,393)],[Vector2(204,339),Vector2(225,325)],[Vector2(204,340),Vector2(235,319)],[Vector2(204,330),Vector2(235,309)],[Vector2(206,316),Vector2(229,301)],[Vector2(206,296),Vector2(229,281)],[Vector2(207,290),Vector2(226,278)],[Vector2(210,280),Vector2(226,269)]]
 Parts.pub_post(native,post,d*.12,h*.55,Vector2.ZERO,levels,[left,right])
 var windows=[["right",[Vector2(245,224),Vector2(278,201),Vector2(278,258),Vector2(245,281)]],
              ["right",[Vector2(308,180),Vector2(341,157),Vector2(341,214),Vector2(308,237)]]]
 Parts.gables(native,11403,body,w,d,h,windows,"tina")
 var bucket=Parts.face_point(Vector2(296,261),Parts.crops().tina_11403_right[1],body,w,d,h,"right")
 bucket.z+=.50;bucket.y=.50;skin.part="tina_barrel_brown"
 Parts.Parts.kili_round(skin,bucket,[Vector2(h*.055,0),Vector2(h*.070,h*.10),Vector2(h*.055,h*.10),Vector2(h*.04,h*.02)])

static func round_details(skin,w:float,height:float):
 var radius=w*.482;var body=height*.62
 skin.part="trim"
 for level in [.12,.65]:
  Parts.Parts.kili_round(skin,Vector3.ZERO,[Vector2(radius,body*level),Vector2(radius*1.012,body*level),Vector2(radius*1.012,body*(level+.035)),Vector2(radius,body*(level+.035))])

static func facade_details(native,serial:int,body:Vector3,w:float,d:float,h:float):
 var records=[]
 if serial==11400:
  records=[["left",[Vector2(88,222),Vector2(88,193),Vector2(93,177),Vector2(103,167),Vector2(114,169),Vector2(130,184),Vector2(137,202),Vector2(137,255)]]]
  records.append_array([
   ["left",[Vector2(43,190),Vector2(78,214),Vector2(78,266),Vector2(43,242)]],
   ["right",[Vector2(169,248),Vector2(200,226),Vector2(200,279),Vector2(169,301)]],
   ["right",[Vector2(249,193),Vector2(285,168),Vector2(285,223),Vector2(249,248)]]])
 elif serial==11404:
  records=[["left",[Vector2(98,168),Vector2(124,186),Vector2(124,243),Vector2(98,225)]],
           ["right",[Vector2(329,287),Vector2(361,265),Vector2(361,317),Vector2(329,339)]],
           ["right",[Vector2(384,249),Vector2(416,227),Vector2(416,279),Vector2(384,301)]]]
 elif serial==11405:
  records=[["left",[Vector2(34,212),Vector2(34,164),Vector2(44,149),Vector2(55,145),Vector2(69,152),Vector2(90,174),Vector2(99,191),Vector2(99,255)]],
           ["left",[Vector2(102,275),Vector2(102,221),Vector2(110,203),Vector2(122,198),Vector2(138,205),Vector2(155,224),Vector2(161,243),Vector2(161,315)]],
           ["right",[Vector2(178,312),Vector2(178,254),Vector2(186,235),Vector2(196,230),Vector2(210,234),Vector2(222,245),Vector2(225,264),Vector2(225,279)]],
           ["right",[Vector2(268,251),Vector2(268,192),Vector2(277,174),Vector2(288,169),Vector2(303,177),Vector2(316,194),Vector2(318,212),Vector2(318,216)]]]
 Parts.gables(native,serial,body,w,d,h,records,"jenova")

static func porch(native,skin,body:Vector3,w:float,d:float,h:float,doorway:Dictionary):
 var floor_y=maxf(.35,doorway.at.y)
 skin.part="trim"
 skin.box(AABB(body+Vector3(-w*.5-1.65,floor_y-.18,-d*.5),Vector3(1.65,.18,d)))
 Parts.painted_quad(native,body+Vector3(-w*.5-1.65,floor_y+.01,-d*.5),body+Vector3(-w*.5,floor_y+.01,-d*.5),body+Vector3(-w*.5,floor_y+.01,d*.5),body+Vector3(-w*.5-1.65,floor_y+.01,d*.5),[Vector2(7,273),Vector2(29,258),Vector2(96,304),Vector2(74,319)])
 for fraction in [0.0,.33,.67,1.0]:
  skin.box(AABB(body+Vector3(-w*.5-1.55,0,d*(fraction-.5)-.10),Vector3(.22,floor_y,.22)))
 Parts.porch(skin,body+Vector3.UP*floor_y,w,d,h,doorway,11400,["left"])

static func pub_details(native,skin,body:Vector3,w:float,d:float,h:float):
 var left_quad:Array=Parts.crops().jenova_11405_left[1]
 var floor_at=Parts.face_point(Vector2(89,331),left_quad,body,w,d,h,"left")
 var balcony_width=d*44.0/140;var depth=1.1;var rail=h*21.0/146
 skin.part="trim"
 skin.box(AABB(floor_at+Vector3(-depth,-.12,-balcony_width*.5),Vector3(depth,.18,balcony_width)))
 Parts.painted_quad(native,floor_at+Vector3(-depth,.065,-balcony_width*.5),floor_at+Vector3(0,.065,-balcony_width*.5),floor_at+Vector3(0,.065,balcony_width*.5),floor_at+Vector3(-depth,.065,balcony_width*.5),[Vector2(63,317),Vector2(86,302),Vector2(113,320),Vector2(90,335)])
 for side in [-1,1]:
  skin.box(AABB(floor_at+Vector3(-depth,rail,side*balcony_width*.5-.06),Vector3(depth,.12,.12)))
 skin.box(AABB(floor_at+Vector3(-depth,rail,-balcony_width*.5),Vector3(.12,.12,balcony_width)))
 for i in 7:
  var z=balcony_width*(float(i)/6-.5)
  skin.box(AABB(floor_at+Vector3(-depth,.05,z-.05),Vector3(.12,rail,.10)))
 var signs=[]
 var oval=[]
 var sign_quad=[Vector2(263,288),Vector2(304,260),Vector2(304,320),Vector2(263,348)]
 for i in 32:
  var uv=Vector2(.5+cos(i*TAU/32)*.5,.5+sin(i*TAU/32)*.5)
  oval.append(sign_quad[0].lerp(sign_quad[1],uv.x).lerp(sign_quad[3].lerp(sign_quad[2],uv.x),uv.y))
 signs.append(["right",oval])
 signs.append(["right",[Vector2(214,229),Vector2(254,201),Vector2(254,237),Vector2(214,265)]])
 Parts.gables(native,11405,body,w,d,h,signs,"jenova")
 var flags=[
  ["left",[Vector2(11,163),Vector2(29,174),Vector2(29,210),Vector2(11,198)]],
  ["left",[Vector2(148,245),Vector2(169,259),Vector2(169,302),Vector2(148,288)]],
  ["right",[Vector2(190,260),Vector2(211,245),Vector2(211,293),Vector2(190,308)]],
  ["right",[Vector2(321,171),Vector2(341,157),Vector2(341,200),Vector2(321,214)]]]
 for flag in flags:
  var face:String=flag[0];var pixels:Array=flag[1]
  var quad:Array=Parts.crops()["jenova_11405_"+face][1]
  var normal=Vector3.LEFT if face=="left" else Vector3.BACK
  var points=[]
  for pixel in pixels:points.append(Parts.face_point(pixel,quad,body,w,d,h,face)+normal*.22)
  Parts.outward_quad(native,points.duplicate(),pixels.duplicate(),normal)
  Parts.outward_quad(native,points.duplicate(),pixels.duplicate(),-normal)
  var a:Vector3=points[0];var b:Vector3=points[1]
  skin.box(AABB(a.min(b)-Vector3.ONE*.05,(b-a).abs()+Vector3.ONE*.10))
  skin.box(AABB(a.min(a-normal*.22)-Vector3.ONE*.05,normal.abs()*.22+Vector3.ONE*.10))

static func bay(native,at:Vector3,radius:float,wall:float,rise:float):
 Parts.round_roof(native,at,radius*1.12,radius*1.12,[[1,wall*.91,214,64],[.98,wall*.91+rise*.16,199,58],[.85,wall*.91+rise*.34,176,46],[.58,wall*.91+rise*.51,150,28],[.27,wall*.91+rise*.60,136,11],[.01,wall*.91+rise*.62,133,.5]],234,130,true)

static func round_door(native,skin,center:Vector3,width:float,height:float):
 var quad=[[153,315],[188,337],[188,421],[153,399]]
 var outline=[Vector2(quad[3][0],quad[3][1]),Vector2(quad[0][0],quad[0][1]+15),Vector2(quad[0][0]+4,quad[0][1]+2),Vector2(quad[0][0]+14,quad[0][1]-3),Vector2(quad[1][0]-8,quad[1][1]-8),Vector2(quad[1][0],quad[1][1]+6),Vector2(quad[2][0],quad[2][1])]
 var body=center+Vector3(.070,-height*.5,0)
 var pixels=[Vector2(quad[3][0],quad[3][1]),Vector2(quad[0][0],quad[0][1]),Vector2(quad[1][0],quad[1][1]),Vector2(quad[2][0],quad[2][1])]
 var points=[]
 for pixel in pixels:points.append(Parts.face_point(pixel,quad,body,.01,width,height,"left"))
 Parts.outward_quad(native,points,pixels,Vector3.LEFT)
 Parts.frame(native,skin,outline,quad,body,.01,width,height,"left","stone")
