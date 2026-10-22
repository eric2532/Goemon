"""Individually authored equipment and breed-specific forms from the ten approved drawings."""
# This module receives the modeling helpers from build_dogs.py.
def install(d):globals().update(d)

def panel(name,c,w,h,m,bow=.04):
 c=Vector(c);vs=[];fs=[]
 for j in range(7):
  for k in range(9):
   u=k/8-.5;v=j/6-.5;vs.append(c+Vector((u*w,-bow*(1-(2*u)**2),v*h)))
 for j in range(6):
  for k in range(8):a=j*9+k;fs.append((a,a+1,a+10,a+9))
 o=mesh(name,vs,fs,m);mo=o.modifiers.new('Shaped sheet thickness','SOLIDIFY');mo.thickness=.012;mo=o.modifiers.new('Rounded edge','BEVEL');mo.width=.006;mo.segments=2;return o

def border(name,c,w,h,M):
 c=Vector(c)
 for s in [-1,1]:
  curve(name+' edge', [c+Vector((s*w*.5,-.008,-h*.5)),c+Vector((s*w*.5,-.008,h*.5))],M['gold'],.009)
  curve(name+' edge', [c+Vector((-w*.5,-.008,s*h*.5)),c+Vector((w*.5,-.008,s*h*.5))],M['gold'],.009)
 for x in [-.40,.40]:
  for z in [-.40,.40]:uv(name+' rivet',c+Vector((w*x,-.020,h*z)),(.013,.008,.013),M['gold'],12,8)

def medallion(c,M,r=.085,kind='swirl'):
 c=Vector(c);o=uv('ORNAMENT | bronze medallion',c,(r,.018,r),M['gold']);torus('ORNAMENT | raised border',c+Vector((0,-.018,0)),r*.89,.005,M['thread'])
 for j in range(3 if kind=='swirl' else 4):
  ang=j*TAU/(3 if kind=='swirl' else 4);ps=[]
  for k in range(28):
   t=k/27;a=ang+t*math.pi*1.75;rr=r*(.66-.49*t);ps.append(c+Vector((rr*math.cos(a),-.025,rr*math.sin(a))))
  curve('ORNAMENT | engraved swirl',ps,M['leather'] if kind=='swirl' else M['red'],.006)

def saddle(r,M,color='cloth'):
 z=(r['chest'][2]+r['hip'][2])*.5;rx=r['body'][1]+.055;rz=r['body'][2]+.035
 band('TACK | fitted saddle cloth',(-.12,0,z),rx,rz,.70,M[color],axis='X',start=-.05,end=math.pi+.05)
 for x in [-.43,.19]:
  ps=[(x,rx*math.cos(a),z+rz*math.sin(a)) for a in [k/48*math.pi for k in range(49)]];curve('TACK | saddle piping',ps,M['thread'],.008)
 return z

def lamellar(r,M):
 z=r['chest'][2];y=-r['body'][1]-.18
 saddle(r,M,'metal')
 # Each shoulder has curved overlapping lames with visible lacing and rivets.
 for side in [-1,1]:
  for j in range(4):
   c=Vector((.35,side*(abs(y)+.015*j),z+.22-j*.14));o=panel('ARMOR | shoulder lame',c,.43,.18,M['metal'],bow=.035*side*-1)
   for k in range(5):
    x=.35+(k-2)*.073;curve('ARMOR | inset scale seam',[(x,side*(abs(y)+.025*j+.017),c.z-.064),(x,side*(abs(y)+.025*j+.017),c.z+.065)],M['leather'],.005)
    for dz in [-.045,.04]:tube('ARMOR | red lacing',[(x-.012,side*(abs(y)+.04+.015*j),c.z+dz-.018),(x+.012,side*(abs(y)+.04+.015*j),c.z+dz+.018)],.009,M['red'],8)
   curve('ARMOR | bronze lame edge',[(c.x-.21,c.y+.025*side,c.z-.073),(c.x,c.y+.04*side,c.z-.08),(c.x+.21,c.y+.025*side,c.z-.073)],M['gold'],.012)
   for sx in [-1,1]:uv('ARMOR | fastening rivet',(c.x+sx*.18,c.y+.02*side,c.z+.04),(.017,.014,.017),M['gold'],12,8)
 # Fore-chest cuirass built in an X-facing plane.
 for j in range(3):
  o=panel('ARMOR | front chest lame',(0,0,0),.65,.18,M['metal'],bow=.06);o.rotation_euler.z=math.pi/2;o.location=(.81,0,z-.05-j*.135)
  c=Vector((.59,-.16,z-.18));
 before=set(bpy.data.objects);mc=Vector((.85,0,z-.08));medallion(mc,M,.105);bpy.context.view_layer.update();T=Matrix.Translation(mc)@Matrix.Rotation(math.pi/2,4,'Z')@Matrix.Translation(-mc)
 for ob in set(bpy.data.objects)-before:ob.matrix_world=T@ob.matrix_world
 for s in [-1,1]:
  rope('ARMOR | front red knot',[(.83,s*.22,z-.09),(.86,s*.05,z-.18),(.84,s*.20,z-.30)],M,.026,'red');tassel('ARMOR | red tassel',(.84,s*.20,z-.30),M,'red',.23)
 for side in [-1,1]:ribbon('ARMOR | shoulder suspension',[(.35,side*.28,z+.39),(.35,side*.44,z+.34),(.35,side*(abs(y)),z+.28)],.085,M['leather'],across=(1,0,0))
 # Ear-opening helmet band and slatted cheek guards.
 head_start=set(bpy.data.objects);h=Vector(r['head']);band('ARMOR | brow helmet band',(h.x,0,h.z+.27),r['hs'][0]*.97,r['hs'][1]*1.08,.12,M['metal'],axis='Z')
 for s in [-1,1]:
  for j in range(3):panel('ARMOR | helmet cheek guard',(h.x-.08,s*(r['hs'][1]+.08),h.z+.21-j*.095),.28,.12,M['metal'],.02)
 medal_start=set(bpy.data.objects);mc=h+Vector((r['hs'][0]+.025,0,.27));medallion(mc,M,.080)
 T=Matrix.Translation(mc)@Matrix.Rotation(math.pi/2,4,'Z')@Matrix.Translation(-mc)
 bpy.context.view_layer.update()
 for ob in set(bpy.data.objects)-medal_start:ob.matrix_world=T@ob.matrix_world
 for k in range(7):uv('ARMOR | helmet rivet',(h.x+.22-k*.07,-r['hs'][1]*1.065,h.z+.26),(.011,.01,.012),M['gold'],12,8)

 bpy.context.view_layer.update();T=Matrix.Translation(h)@Matrix.Rotation(math.radians(-35),4,'Z')@Matrix.Translation(-h)
 for ob in set(bpy.data.objects)-head_start:ob.matrix_world=T@ob.matrix_world

def leaf_mantle(r,M):
 leafm=[mat('Leaf olive '+str(k),c,0,.95) for k,c in enumerate([(.055,.060,.023),(.085,.073,.031),(.040,.049,.014),(.115,.089,.040)])];random.seed(330)
 # Layered lobed leaves run down both sides from a shoulder mantle.
 for side in [-1,1]:
  for row in range(4):
   for col in range(8):
    x=-.54+col*.15+random.uniform(-.04,.04);z=r['chest'][2]+.30-row*.14;y=side*(r['body'][1]+.04+row*.012);length=random.uniform(.19,.34);w=length*random.uniform(.22,.37);c=Vector((x,y,z));R=Matrix.Rotation(random.uniform(-.65,.65),3,'Y');vs=[c]
    outline=[(-.25,.12),(-.72,-.13),(-.52,-.30),(-1,-.40),(-.57,-.55),(-.73,-.74),(0,-1),(.58,-.73),(.42,-.52),(.90,-.34),(.50,-.20),(.25,.10)]
    for u,v in outline:vs.append(c+R@Vector((u*w,side*.013*(1-v),v*length)))
    vs.append(c+R@Vector((0,side*.035,-length*.43)));idx=len(vs)-1;fs=[(idx,k,1+(k%len(outline))) for k in range(1,len(outline)+1)];o=mesh('CAMOUFLAGE | lobed oak leaf',vs,fs,leafm[(row+col)%4],False);mo=o.modifiers.new('Leaf thickness','SOLIDIFY');mo.thickness=.003
    curve('CAMOUFLAGE | leaf midrib',[c+R@Vector((0,side*.015,0)),c+R@Vector((0,side*.04,-length*.88))],M['rope'],.002)
 # Plum hood folded behind the ears, with an open face.
 h=Vector(r['head']);ribbon('CLOTH | folded ambusher hood',[(h.x-.30,-.30,h.z-.16),(h.x-.30,-.27,h.z+.18),(h.x-.32,0,h.z+.32),(h.x-.30,.27,h.z+.18),(h.x-.30,.30,h.z-.16)],.28,M['cloth'],across=(1,0,0))
 for j in range(2):
  c=Vector((-.25+j*.30,-r['body'][1]-.10,r['chest'][2]-.10));box('KIT | stitched leather pouch',c,(.25,.12,.23),M['leather'],.035);panel('KIT | overlapping pouch flap',c+Vector((0,-.075,.075)),.24,.105,M['leather'],.025);box('KIT | pouch clasp',c+Vector((0,-.10,-.005)),(.034,.016,.073),M['gold'],.004)
  for s in [-1,1]:curve('KIT | pouch stitching',[c+Vector((s*.103,-.068,-.09)),c+Vector((s*.103,-.068,.055))],M['thread'],.002)


def wraps(r,M,limbs,color='cloth'):
 for back,side,ps,paw in limbs:
  a=Vector(ps[-2]);b=Vector(ps[-1]);axis=(a-b).normalized();length=(a-b).length;rad=r['leg']*.72
  tube('TACK | fitted ankle wrap',[b,b.lerp(a,.35),a],[rad,rad*1.10,rad*1.20],M[color],20)
  u=axis.cross(Vector((0,1,0))).normalized();v=axis.cross(u);pts=[]
  for k in range(61):t=k/60;ang=t*TAU*3.3;pts.append(b.lerp(a,t)+(u*math.cos(ang)+v*math.sin(ang))*rad*(1.06+.20*t))
  rope('TACK | crossed ankle binding',pts,M,.008,'rope' if r['gear']=='climber' else 'leather')


def tracker(r,M):
 z=r['chest'][2];y=-r['body'][1]-.11
 scroll((-.04,y,z+.16),M,axis=(.10,0,1),length=.49,radius=.068)
 c=Vector((-.34,-.035,z+.28));box('KIT | map satchel',c,(.38,.28,.17),M['leather'],.040)
 for x in [-.45,-.24]:box('KIT | satchel buckle',(x,-.19,z+.26),(.045,.025,.056),M['gold'],.005)
 glass=[mat('Vial jade',(.08,.23,.16),.2,.18),mat('Vial pale aqua',(.19,.30,.29),.1,.16),mat('Vial amber',(.44,.19,.03),.1,.20)]
 for j in range(3):
  c=Vector((-.19+j*.15,y-.035,z-.27));tube('KIT | colored potion vial',[c,c+Vector((0,0,.13))],.040,glass[j],24);tube('KIT | vial neck',[c+Vector((0,0,.12)),c+Vector((0,0,.18))],.023,M['gold'],16);tube('KIT | cork stopper',[c+Vector((0,0,.175)),c+Vector((0,0,.195))],.025,M['rope'],16);band('KIT | vial leather retainer',c+Vector((0,0,.08)),.043,.043,.027,M['leather'],axis='Z')
 medallion((.10,y-.025,z+.02),M,.042)


def sword(r,M):
 saddle(r,M);y=-r['body'][1]-.115;z=r['chest'][2]+.03
 tube('WEAPON | dark lacquer scabbard',[(-.75,y,z-.03),(-.20,y,z+.02),(.24,y,z+.06)],[.037,.046,.046],M['cloth'],16,1)
 for x in [-.73,-.22,.20]:tube('WEAPON | bronze scabbard fitting',[(x-.017,y,z+.04*x),(x+.017,y,z+.04*x)],.049,M['gold'],20)
 tube('WEAPON | sword grip',[(.26,y,z+.06),(.54,y,z+.075)],.036,M['leather'],16);torus('WEAPON | oval guard',(.255,y,z+.06),.074,.012,M['gold'],normal=(1,0,0))
 for j in range(9):
  x=.28+j*.028;rope('WEAPON | crossed hilt wrap',[(x,y-.034,z+.044),(x+.019,y-.035,z+.092),(x+.038,y-.034,z+.044)],M,.004,'cloth')
 for x in [-.18,.14]:
  ps=[(x,y-.060,z+.02),(x-.035,y-.055,z+.11),(x,y+.075,z+.12),(x+.035,y+.075,z-.05),(x,y-.060,z+.02)];rope('WEAPON | sword retaining cord',ps,M,.014,'thread')
 tassel('WEAPON | pale cord tassel',(-.18,y-.04,z-.07),M,'thread',.20)

def flower(c,M,size=.09):
 c=Vector(c)
 for j in range(5):
  a=j/5*TAU;pts=[]
  for k in range(25):
   t=k/24*TAU;rad=size*(.38+.18*math.cos(t));pts.append(c+Vector((math.cos(a)*rad+math.cos(a+math.pi/2)*size*.18*math.sin(t),-.010,math.sin(a)*rad+math.sin(a+math.pi/2)*size*.18*math.sin(t))))
  curve('RITUAL | five-petal crest',pts,M['red'],size*.080)
 uv('RITUAL | flower center',c+Vector((0,-.01,0)),(size*.12,.004,size*.12),M['red'],16,10)

def ritual(r,M):
 z=saddle(r,M,'parchment');y=-r['body'][1]-.08
 for x in [-.36,.12]:
  panel('RITUAL | cream hanging panel',(x,y,z),.25,.39,M['parchment'],.025);border('RITUAL | vermilion border',(x,y-.01,z),.25,.39,dict(M,gold=M['red']));flower((x,y-.041,z+.025),M,.12)
 h=Vector(r['head']);c=h+Vector((-.10,0,-.29));ry=r['hs'][1]*1.26
 ps=[c+Vector((.08*math.cos(k/60*TAU),ry*math.sin(k/60*TAU),.20*math.cos(k/60*TAU))) for k in range(61)];rope('RITUAL | navy braided collar',ps,M,.025,'cloth')
 bell=Vector((h.x+.05,-.23,h.z-.36));uv('RITUAL | polished throat bell',bell,(.077,.057,.071),M['gold']);torus('RITUAL | bell rim',bell+Vector((0,-.043,-.025)),.055,.009,M['gold']);curve('RITUAL | bell slit',[bell+Vector((-.04,-.058,-.015)),bell+Vector((.04,-.058,-.015))],M['ink'],.006);uv('RITUAL | bell sound hole',bell+Vector((0,-.06,.013)),(.015,.005,.015),M['ink'],16,10)
 for x in [-.35,.14,.59]:tassel('RITUAL | vermilion tassel',(x,y-.06,z-.01),M,'red',.24)
 for j,c in enumerate([(-.70,-.16,1.47),(.13,.08,1.80),(.95,.12,1.63)]):
  c=Vector(c);panel('DISPLAY | floating paper ward '+str(j),c,.16,.32,M['parchment'],.009);border('DISPLAY | ward border',c,.16,.32,dict(M,gold=M['red']));flower(c+Vector((0,-.018,.075)),M,.062)
  curve('DISPLAY | abstract ward strokes',[c+Vector((.023*math.sin(k*.95),-.02,.025-k*.013)) for k in range(10)],M['red'],.004)


def long_locks(name,center,length,width,color,M,direction=(0,0,-1),count=15):
 center=Vector(center);direction=Vector(direction).normalized();random.seed(len(name));vs=[];fs=[];cols=[]
 for j in range(count):
  a=j/count*TAU;offset=Vector((math.cos(a)*width,math.sin(a)*width*.60,0));start=center+offset;v=Vector((0,1,0));u=direction.cross(v).normalized();base=len(vs);ll=length*random.uniform(.75,1.10);ww=width*.35
  for k in range(6):
   t=k/5;cen=start+direction*ll*t+Vector((-.06*math.sin(t*math.pi),.04*math.sin(a+t*3),0));w=ww*math.sin(math.pi*(.10+.89*t))
   for s in [-1,0,1]:vs.append(cen+u*w*s+v*.018*(1-abs(s))*math.sin(t*math.pi));cols.append(color)
  for k in range(5):
   for s in range(2):i=base+k*3+s;fs.append((i,i+1,i+4,i+3))
 mesh(name,vs,fs,M['fur'],True,cols)

def mirage(r,M):
 h=Vector(r['head'])
 for s in [-1,1]:long_locks('FUR | long feathered Chin ear',h+Vector((-.06,s*.28,.13)),.53,.11,r['coat'],M,count=28)
 long_locks('FUR | silky white chest',(.52,0,.79),.40,.17,r['cream'],M,count=28)
 c=Vector((.57,-.28,.81));ps=[]
 for k in range(38):a=(.17+k/37*1.68)*math.pi;ps.append(c+Vector((.061*math.cos(a),0,.061*math.sin(a))))
 curve('ORNAMENT | crescent moon clasp',ps,M['gold'],.019)
 for x in [.41,.66]:tassel('ORNAMENT | violet moon tassel',(x,-.30,.68),M,'cloth',.19)


def shield(r,M):
 z=r['chest'][2];y=-r['body'][1]-.13;saddle(r,M,'leather')
 for j in range(4):
  o=panel('ARMOR | mastiff chest plate',(0,0,0),.78,.19,M['metal'],.07);o.rotation_euler.z=math.pi/2;o.location=(.87,0,z-.02-j*.14)
 c=Vector((-.21,y-.07,z+.02));w=.91;h=.87
 # Shield is a curved continuous shell with a pointed foot and reinforced corners.
 vs=[];fs=[]
 for row in range(12):
  t=row/11
  for k in range(15):
   u=k/14-.5;zoff=(.5-t)*h;zoff-=.10*(1-abs(u)*2)*max(0,(t-.75)*4);vs.append(c+Vector((u*w,-.10*(1-(u*2)**2),zoff)))
 for j in range(11):
  for k in range(14):a=j*15+k;fs.append((a,a+1,a+16,a+15))
 o=mesh('ARMOR | massive curved flank shield',vs,fs,M['metal']);mo=o.modifiers.new('Forged shield thickness','SOLIDIFY');mo.thickness=.035
 for edge in [[vs[k] for k in range(15)],[vs[165+k] for k in range(15)],[vs[j*15] for j in range(12)],[vs[j*15+14] for j in range(12)]]:curve('ARMOR | shield bronze edge',edge,M['gold'],.020)
 for x in [-.41,.41]:
  for zz in [-.32,.32]:box('ARMOR | shield corner shoe',c+Vector((x,-.036,zz)),(.12,.035,.13),M['gold'],.013);uv('ARMOR | shield rivet',c+Vector((x,-.062,zz)),(.016,.01,.016),M['leather'],12,8)
 medallion(c+Vector((0,-.122,.045)),M,.22)
 for zz in [-.20,.26]:
  rope('ARMOR | shield retaining loop',[c+Vector((.44,-.045,zz)),c+Vector((.31,-.12,zz+.08)),c+Vector((.34,-.13,zz-.02)),c+Vector((.46,.08,zz-.02))],M,.025,'cloth');tassel('ARMOR | shield blue tassel',c+Vector((.34,-.13,zz-.05)),M,'cloth',.20)


def climber(r,M,limbs):
 z=saddle(r,M);y=-r['body'][1]-.11
 # Coiled climbing rope sits above the saddle rather than intersecting the body.
 c=Vector((-.20,y-.065,z+.25))
 ps=[]
 for k in range(289):
  a=k/288*TAU*4;rad=.14+.005*a;ps.append(c+Vector((rad*math.cos(a),-.035,rad*.88*math.sin(a))))
 rope('CLIMB | coiled hemp rope',ps,M,.012,'rope')
 scroll((-.48,.08,z+.36),M,axis=(0,1,0),length=.38,radius=.065)
 c=Vector((-.37,y-.12,z-.26));torus('CLIMB | grappling eye',c+Vector((0,0,.15)),.045,.012,M['gold']);tube('CLIMB | grappling shank',[c+Vector((0,0,.13)),c+Vector((0,0,-.10))],.025,M['metal'],16)
 for j in range(3):
  a=j/3*TAU;direction=Vector((math.cos(a),math.sin(a),0));ps=[c+Vector((0,0,-.08)),c+direction*.13+Vector((0,0,-.18)),c+direction*.17+Vector((0,0,-.10)),c+direction*.15+Vector((0,0,.005))];tube('CLIMB | curved grappling prong',ps,[.024,.023,.016,.001],M['metal'],12,1)
 rope('CLIMB | hook leash',[c+Vector((0,0,.15)),c+Vector((.04,0,.25)),c+Vector((.03,.05,.43))],M,.019)
 # Small rock support is an editable display prop matching the raised paw.
 rock=mat('Rock',(.19,.18,.155),0,.96);bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=(.91,-r['body'][1]*.74,.17));o=bpy.context.object;o.name='DISPLAY | cliff foothold';o.scale=(.28,.23,.21);o.data.materials.append(rock)
 for v in o.data.vertices:v.co.z=min(.95,max(v.co.z,-.8));v.co.x*=1+.14*math.sin(v.index*23);v.co.y*=1+.10*math.sin(v.index*17)


def wind(r,M,limbs):
 h=Vector(r['head'])
 for s in [-1,1]:long_locks('FUR | swept sighthound ear',h+Vector((-.13,s*.18,.14)),.34,.065,r['coat'],M,direction=(-1,0,.25),count=20)
 for back,side,ps,paw in limbs:
  c=Vector(ps[-2]);axis=(Vector(ps[-1])-c).normalized();torus('WIND | ankle binding',c,r['leg']*.78,.010,M['cloth'],normal=axis)
  for j in range(3):uv('WIND | small ankle bell',c+Vector((.02,-.06,.018*j)),(.014,.012,.014),M['gold'],12,8)
  tassel('WIND | ankle streamer',c+Vector((-.03,-.045,.015)),M,'cloth',.11)


def equipment_full(r,M,limbs):
 harness(r,M);gear=r['gear']
 if gear not in ['armor','ward']:scarf(r,M)
 if gear=='scout':scout_gear(r,M)
 elif gear=='armor':lamellar(r,M)
 elif gear=='leaves':leaf_mantle(r,M);wraps(r,M,limbs)
 elif gear=='tracker':tracker(r,M);wraps(r,M,limbs,'parchment')
 elif gear=='blade':sword(r,M)
 elif gear=='ward':ritual(r,M)
 elif gear=='mirage':mirage(r,M)
 elif gear=='shield':shield(r,M)
 elif gear=='climber':climber(r,M,limbs);wraps(r,M,limbs)
 elif gear=='wind':wind(r,M,limbs)
