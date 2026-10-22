"""Rebuild the ten approved ninja dogs as original, skinned game assets in Blender.

Blender --background --python tools/build_defense_dogs.py -- --only kogane
Blender --background --python tools/build_defense_dogs.py -- --all --replace
Blender --background --threads 4 --python tools/build_defense_dogs.py -- --all --replace --resume --skip-full-review
Blender --background --threads 4 --python tools/build_defense_dogs.py -- --lineup-only

The source pack is reference-only. No dense static source or reference is changed.
Geometry is authored in canine coordinates (+X forward, +Z up), then the entire
rig is rotated to Blender +Y / Godot -Z. One skinned mesh, four material surfaces.
"""
import argparse
import bpy
import bmesh
import hashlib
import json
import math
import random
import sys
from pathlib import Path
from mathutils import Vector, Matrix, Quaternion

ROOT = Path(__file__).resolve().parents[1]
PACK = ROOT / "asset_packs/ninja_dogs"
SOURCE = ROOT / "assets/blender/dogs"
OUT = ROOT / "assets/models/dogs"
PORTRAITS = ROOT / "assets/ui/dogs"
EVIDENCE = ROOT / "tests/defense-dogs/art"
for directory in (SOURCE, OUT, PORTRAITS, EVIDENCE):
    directory.mkdir(parents=True, exist_ok=True)
args = argparse.ArgumentParser()
args.add_argument("--only")
args.add_argument("--all", action="store_true")
args.add_argument("--replace", action="store_true")
args.add_argument("--skip-render", action="store_true")
args.add_argument("--skip-full-review", action="store_true")
args.add_argument("--resume", action="store_true")
args.add_argument("--lineup-only", action="store_true")
args.add_argument("--portraits-only", action="store_true")
ARGS = args.parse_args(sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else [])
FPS = 60
DURATIONS = {"idle":2.0, "run":.8, "attack":1.0, "hurt":.45, "death":.9}
R90 = Matrix.Rotation(math.pi/2, 3, "Z")
TAU = math.tau

# Breed silhouettes and equipment follow the ten approved drawings, not a tint swap.
DOGS = [
    dict(id="kogane", name="Kogane", breed="shiba", height=1.08, length=1.48, width=.30, head=(.94,0,1.40), hs=(.34,.30,.31), muzzle=.29, ear=.36, leg=.115, coat="c36c2d", cream="f3dbaf", cloth="253650", tail="curl", gear="scout"),
    dict(id="daigo", name="Daigo", breed="akita", height=1.21, length=1.58, width=.40, head=(.98,0,1.59), hs=(.40,.37,.39), muzzle=.31, ear=.35, leg=.17, coat="a96d3d", cream="f2e3c6", cloth="32393f", tail="curl", gear="armor"),
    dict(id="kage", name="Kage", breed="shepherd", height=1.15, length=1.70, width=.27, head=(1.02,0,1.44), hs=(.32,.255,.30), muzzle=.44, ear=.51, leg=.105, coat="45433b", cream="9a8768", cloth="655065", tail="low", gear="leaves"),
    dict(id="arashi", name="Arashi", breed="shikoku", height=1.22, length=1.53, width=.28, head=(.98,0,1.60), hs=(.31,.26,.30), muzzle=.35, ear=.40, leg=.11, coat="8c6848", cream="e9d6b2", cloth="38666b", tail="curl", gear="tracker"),
    dict(id="haku", name="Haku", breed="kishu", height=1.22, length=1.56, width=.255, head=(.97,0,1.58), hs=(.30,.25,.31), muzzle=.36, ear=.43, leg=.10, coat="e7e1d0", cream="fcf4df", cloth="334360", tail="curl", gear="blade"),
    dict(id="suzu", name="Suzu", breed="spitz", height=.98, length=1.29, width=.32, head=(.80,0,1.35), hs=(.32,.29,.32), muzzle=.23, ear=.35, leg=.105, coat="eee5d1", cream="fff4dc", cloth="343d58", tail="plume", gear="ward"),
    dict(id="maboro", name="Maboro", breed="chin", height=.85, length=1.22, width=.27, head=(.76,0,1.17), hs=(.34,.30,.31), muzzle=.15, ear=.31, leg=.085, coat="292a35", cream="f5ead7", cloth="6c508f", tail="silk", gear="mirage"),
    dict(id="iwa", name="Iwa", breed="mastiff", height=1.28, length=1.78, width=.43, head=(1.03,0,1.64), hs=(.42,.37,.42), muzzle=.30, ear=.45, leg=.19, coat="a87948", cream="b68b56", cloth="344262", tail="straight", gear="shield"),
    dict(id="mine", name="Mine", breed="husky", height=1.22, length=1.62, width=.32, head=(1.0,0,1.55), hs=(.34,.29,.32), muzzle=.33, ear=.40, leg=.12, coat="606b75", cream="eee2c6", cloth="37475e", tail="curl", gear="climber"),
    dict(id="hayate", name="Hayate", breed="sighthound", height=1.32, length=1.90, width=.235, head=(1.19,0,1.57), hs=(.31,.20,.27), muzzle=.52, ear=.33, leg=.083, coat="303440", cream="efe8d7", cloth="344766", tail="flow", gear="wind"),
]


def rgb(value):
    values = [int(value[i:i+2],16)/255 for i in (0,2,4)]
    return tuple(v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in values)


def make_material(name, metal=0, rough=.75, emission=0):
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    node = material.node_tree.nodes.get("Principled BSDF")
    node.inputs["Base Color"].default_value = (1,1,1,1)
    node.inputs["Metallic"].default_value = metal
    node.inputs["Roughness"].default_value = rough
    color = material.node_tree.nodes.new("ShaderNodeVertexColor")
    color.layer_name = "DogColor"
    material.node_tree.links.new(color.outputs["Color"],node.inputs["Base Color"])
    if emission:
        material.node_tree.links.new(color.outputs["Color"],node.inputs["Emission Color"])
        node.inputs["Emission Strength"].default_value = emission
    return material


class DogBuilder:
    def __init__(self, config):
        self.r = config
        self.id = config["id"]
        self.objects = []
        self.anatomy = []
        self.bones = {}
        self.legs = {}
        self.rig = None
        self.h = Vector(config["head"])
        self.hs = Vector(config["hs"])
        self.colors = {key:rgb(config[key]) for key in ("coat","cream","cloth")}
        self.colors.update(ink=rgb("202631"), gold=rgb("c7a462"), leather=rgb("594638"), red=rgb("a34635"), pink=rgb("b48172"), white=rgb("fff9e8"))
        self.materials = {
            "fur":make_material("Canine coat · painted breed markings",0,.85),
            "cloth":make_material("Woven cloth and leather equipment",0,.82),
            "metal":make_material("Forged bronze and indigo iron",.68,.36),
            "eyes":make_material("Eyes, polished nose and living accents",.05,.22),
        }

    def paint(self,obj,color,kind="fur",bone=None):
        obj.data.materials.clear();obj.data.materials.append(self.materials[kind])
        attr=obj.data.color_attributes.get("DogColor") or obj.data.color_attributes.new(name="DogColor",type="FLOAT_COLOR",domain="POINT")
        for vertex,item in zip(obj.data.vertices,attr.data):
            c=color(vertex.co) if callable(color) else self.colors.get(color,color)
            item.color=(*c,1)
        for polygon in obj.data.polygons:polygon.use_smooth=True
        if bone:
            group=obj.vertex_groups.new(name=bone)
            group.add(list(range(len(obj.data.vertices))),1,"REPLACE")
        self.objects.append(obj)
        return obj

    def finish(self,obj,name):
        obj.name=name
        bpy.context.view_layer.objects.active=obj
        bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
        return obj

    def ell(self,name,p,size,color=None,kind="fur",bone=None,segments=16,rings=10):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=segments,ring_count=rings,radius=1,location=p)
        obj=bpy.context.object;obj.scale=size
        self.finish(obj,name)
        if color is None:self.anatomy.append(obj);return obj
        return self.paint(obj,color,kind,bone)

    def box(self,name,p,size,color,kind="cloth",bone="chest",bevel=.025):
        bpy.ops.mesh.primitive_cube_add(size=1,location=p)
        obj=bpy.context.object;obj.scale=size;self.finish(obj,name)
        if bevel:
            modifier=obj.modifiers.new("Forged and sewn edge bevels","BEVEL");modifier.width=bevel;modifier.segments=1 if max(size)<.65 else 2
            bpy.context.view_layer.objects.active=obj;bpy.ops.object.modifier_apply(modifier=modifier.name)
        return self.paint(obj,color,kind,bone)

    def mesh(self,name,vertices,faces,color,kind="fur",bone=None):
        mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update()
        bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(mesh);bm.free()
        obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj)
        return self.paint(obj,color,kind,bone)

    def tube(self,name,points,radii,color=None,kind="fur",bone=None,sides=10):
        points=list(map(Vector,points));vertices=[];faces=[]
        if isinstance(radii,(int,float)):radii=[radii]*len(points)
        for i,p in enumerate(points):
            tangent=(points[min(i+1,len(points)-1)]-points[max(0,i-1)]).normalized()
            u=tangent.cross(Vector((0,0,1)))
            if u.length<.01:u=tangent.cross(Vector((0,1,0)))
            u.normalize();v=tangent.cross(u).normalized()
            for j in range(sides):
                angle=j*TAU/sides;vertices.append(p+radii[i]*(math.cos(angle)*u+math.sin(angle)*v))
        for i in range(len(points)-1):
            for j in range(sides):
                a=i*sides+j;b=i*sides+(j+1)%sides;faces.append((a,b,b+sides,a+sides))
        faces.extend([tuple(reversed(range(sides))),tuple((len(points)-1)*sides+j for j in range(sides))])
        if color is None:
            mesh=bpy.data.meshes.new(name);mesh.from_pydata(vertices,[],faces);mesh.update();obj=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(obj);self.anatomy.append(obj);return obj
        return self.mesh(name,vertices,faces,color,kind,bone)

    def band(self,name,p,rx,rz,width,color,bone="chest",kind="cloth"):
        vertices=[];faces=[];p=Vector(p)
        for ring in range(2):
            for i in range(24):
                a=i*TAU/24;vertices.append(p+Vector(((ring-.5)*width,rx*math.cos(a),rz*math.sin(a))))
        for i in range(24):faces.append((i,(i+1)%24,(i+1)%24+24,i+24))
        return self.mesh(name,vertices,faces,color,kind,bone)

    def bone(self,name,head,tail,parent=None,deform=True):
        self.bones[name]=(Vector(head),Vector(tail),parent,deform)

    def anatomy_mesh(self):
        r=self.r;h=self.h;hs=self.hs;H=r["height"];L=r["length"];W=r["width"]
        self.ell("Sculpted canine ribcage",(-.08,0,H-.10),(L*.46,W,.32 if r["breed"]!="mastiff" else .40))
        self.ell("Deep sternum and shoulders",(.40,0,H-.02),(.36,W*1.06,.40 if r["breed"]!="sighthound" else .43))
        self.ell("Powerful rump",(-L*.36,0,H-.08),(.35,W*.96,.33))
        self.tube("Sloping muscular neck",[(.40,0,H),h+Vector((-.19,0,-.15)),h+Vector((-.10,0,-.06))],[W*.86,hs.y*.9,hs.y*.91],sides=16)
        self.ell("Defined skull",h,hs)
        for side in (-1,1):self.ell("Cheek",h+Vector((.08,side*hs.y*.45,-.095)),(hs.x*.72,hs.y*.68,hs.z*.63))
        self.ell("Tapered upper muzzle",h+Vector((hs.x*.68+r["muzzle"]*.23,0,-.065)),(r["muzzle"]*.70,hs.y*.58,hs.z*.35))
        if r["breed"] in ("spitz","akita"):
            self.ell("Thick breed ruff",h+Vector((-.22,0,-.28)),(.36,W*1.2,.43))
        self.bone("root",(0,0,0),(0,0,.3))
        self.bone("spine",(-.55,0,H-.06),(.02,0,H-.06),"root")
        self.bone("chest",(.02,0,H-.06),(.45,0,H),"spine")
        self.bone("neck",(.45,0,H),h+Vector((-.10,0,-.08)),"chest")
        self.bone("head",h+Vector((-.10,0,-.08)),h+Vector((.38,0,-.03)),"neck")
        jaw_hinge=h+Vector((.10,0,-.17))
        self.bone("jaw",jaw_hinge,h+Vector((hs.x+r["muzzle"]*.4,0,-.19)),"head")
        for back in (False,True):
            for side in (-1,1):
                tag=("back" if back else "front")+("_L" if side<0 else "_R")
                x=-L*.35 if back else .43;y=side*W*.81
                hip=Vector((x,y,H-.10 if back else H-.01))
                knee=Vector((x+.17 if back else x-.10,y,H*.49))
                ankle=Vector((x-.10 if back else x+.09,y,.17))
                toe=ankle+Vector((.21,0,-.07))
                self.tube("Articulated upper limb",[hip,hip.lerp(knee,.45),knee],[r["leg"]*1.55,r["leg"]*1.15,r["leg"]*.90],sides=14)
                self.tube("Articulated lower limb",[knee,knee.lerp(ankle,.55),ankle],[r["leg"]*.91,r["leg"]*.67,r["leg"]*.67],sides=12)
                self.ell("Shaped paw",ankle+Vector((.12,0,-.065)),(.20,r["leg"]*1.12,.115))
                self.ell("Shoulder or haunch",hip,(r["leg"]*1.6,r["leg"]*1.28,r["leg"]*1.95))
                parent="spine" if back else "chest"
                self.bone(tag+"_upper",hip,knee,parent)
                self.bone(tag+"_lower",knee,ankle,tag+"_upper")
                self.bone(tag+"_paw",ankle,toe,tag+"_lower")
                self.bone(tag+"_ik",ankle,toe,"root",False)
                self.legs[tag]=(hip,knee,ankle,toe)
        bpy.ops.object.select_all(action="DESELECT")
        for obj in self.anatomy:obj.select_set(True)
        bpy.context.view_layer.objects.active=self.anatomy[0];bpy.ops.object.join();body=bpy.context.object
        body.name="Unified canine anatomy"
        body.data.remesh_voxel_size=.048 if r["breed"] in ("chin","spitz") else .055
        bpy.ops.object.voxel_remesh()
        smooth=body.modifiers.new("Organic sculpt smoothing","SMOOTH");smooth.factor=.85;smooth.iterations=4;bpy.ops.object.modifier_apply(modifier=smooth.name)
        triangles=sum(len(p.vertices)-2 for p in body.data.polygons)
        if triangles>6200:
            decimate=body.modifiers.new("Game retopology budget","DECIMATE");decimate.ratio=6200/triangles;bpy.ops.object.modifier_apply(modifier=decimate.name)
        # Ground the remeshed paws exactly without changing skeletal proportions.
        for vertex in body.data.vertices:
            if vertex.co.z<.065:vertex.co.z=max(0,vertex.co.z-.015)
        self.paint(body,self.coat_color)
        self.skin_body(body)

    def coat_color(self,p):
        r=self.r;h=self.h;hs=self.hs;coat=self.colors["coat"];cream=self.colors["cream"];x,y,z=p
        mix=0.0
        if r["breed"] in ("shiba","akita","shikoku","husky","shepherd"):
            if z<.30:mix=1
            if -.72<x<.45 and z<r["height"]-.27:mix=.98
            if x>.44 and z<h.z-.11 and z>h.z-.53:mix=1
            if x>h.x+.12 and z<h.z+.035:mix=1
            if x>.18 and x<.74 and abs(y)<.22 and z<r["height"]+.13:mix=1
            for side in (-1,1):
                if ((x-h.x-.17)/.075)**2+((y-side*hs.y*.57)/.085)**2+((z-h.z-.13)/.068)**2<1:mix=1
            if r["breed"] in ("shikoku","husky") and x<h.x-.14 and z>r["height"]-.05:coat=tuple(c*.48 for c in coat)
            if r["breed"]=="shepherd":
                mix*=.64;coat=tuple(c*(.68 if math.sin(x*26+z*19+math.sin(y*31))>0 else 1.8) for c in coat)
        elif r["breed"] in ("kishu","spitz"):mix=.3+.5*max(0,min(1,(z-.3)/1.4))
        elif r["breed"]=="chin":
            mix=1 if z<.45 or (.22<x<.58) or (x>h.x+.02 and abs(y)<.09) or (x>h.x+.15 and z<h.z-.035) else 0
        elif r["breed"]=="sighthound":
            mix=1 if z<.34 or (x>.28 and z<r["height"]-.08) or (x>h.x+.16 and z<h.z+.03) else 0
        elif r["breed"]=="mastiff":
            if x>h.x+.09 and z<h.z+.09:coat=rgb("4b4039")
        subtle=.97+.035*math.sin(x*39+y*41+z*33)
        return tuple(max(0,min(1,(a*(1-mix)+b*mix)*subtle)) for a,b in zip(coat,cream))

    def skin_body(self,obj):
        groups={name:obj.vertex_groups.new(name=name) for name,(_,_,_,deform) in self.bones.items() if deform}
        def distance(p,a,b):
            v=b-a;t=max(0,min(1,(p-a).dot(v)/max(.00001,v.length_squared)));return (p-(a+t*v)).length
        for vertex in obj.data.vertices:
            p=vertex.co
            # Inner toe vertices also belong to the leg; a lateral-only cutoff
            # leaves them attached to the torso and creates spikes on a lifted paw.
            if p.z<self.r["height"]*.79 and (p.z<self.r["height"]*.50 or abs(p.y)>self.r["width"]*.42):
                side="_L" if p.y<0 else "_R"
                front="back" if p.x<-.1 else "front"
                prefix=front+side
                names=[prefix+suffix for suffix in ("_upper","_lower","_paw")]
                if p.z<.24:names=[prefix+"_paw"]
            elif p.x>self.h.x-.04 and p.z>self.h.z-.36:names=["head"]
            else:names=["spine","chest","neck","head"]
            nearest=sorted([(distance(p,*self.bones[name][:2]),name) for name in names])[:2]
            weights=[1/max(.06,d)**5 for d,name in nearest];total=sum(weights)
            for (_,name),weight in zip(nearest,weights):groups[name].add([vertex.index],weight/total,"REPLACE")

    def details(self):
        r=self.r;h=self.h;hs=self.hs
        muzzle_tip=h.x+hs.x*.7+r["muzzle"]*.82
        jaw_center=h+Vector((hs.x*.62+r["muzzle"]*.24,0,-.22))
        self.ell("Lower jaw silhouette",jaw_center,(r["muzzle"]*.65,hs.y*.49,.065 if r["breed"]!="mastiff" else .115),"cream",bone="jaw")
        self.ell("Mouth dark interior",jaw_center+Vector((.025,0,.065)),(r["muzzle"]*.61,hs.y*.45,.025),"ink",bone="jaw",segments=12,rings=6)
        self.ell("Soft triangular nose",(muzzle_tip,0,h.z-.055),(.079 if r["breed"]!="mastiff" else .12,hs.y*.34,.065),"ink","eyes","head",segments=14,rings=8)
        for side in (-1,1):
            # Flattened eye sockets and forward pupils give an alert canine expression.
            eye=h+Vector((hs.x*.48,side*hs.y*.78,.075))
            radius=.071 if r["breed"] not in ("chin","mastiff") else (.105 if r["breed"]=="chin" else .068)
            self.ell("Sculpted eye rim",eye,(radius*1.22,.035,radius*.95),"ink",bone="head",segments=12,rings=8)
            self.ell("Amber or violet iris",eye+Vector((.006,side*.024,.006)),(radius*.79,.018,radius*.74),rgb("a77ee7" if r["breed"]=="chin" else "a76f30"),"eyes","head",segments=12,rings=8)
            self.ell("Focused pupil",eye+Vector((.014,side*.040,.008)),(radius*.43,.014,radius*.57),"ink","eyes","head",segments=12,rings=8)
            self.ell("Eye glint",eye+Vector((.001,side*.052,.035)),(.019,.010,.020),"white","eyes","head",segments=8,rings=6)
            self.tube("Soft expressive eyebrow",[eye+Vector((-.055,0,.10)),eye+Vector((.016,side*.008,.125)),eye+Vector((.08,0,.08))],[.025,.035,.013],"coat",bone="head",sides=8)
            for i in range(3):
                self.ell("Whisker follicle",(muzzle_tip-.07-i*.045,side*hs.y*.40,h.z-.11-(i%2)*.024),(.008,.008,.008),"ink",bone="head",segments=6,rings=4)
            self.tube("Curved smile seam",[jaw_center+Vector((-.13,side*hs.y*.46,.048)),jaw_center+Vector((.02,side*hs.y*.49,.052)),jaw_center+Vector((r["muzzle"]*.45,side*hs.y*.25,.052))],.009,"ink",bone="jaw",sides=6)
            for i in range(2):
                p=jaw_center+Vector((r["muzzle"]*.27-i*.12,side*hs.y*.35,.09))
                self.tube("Small canine fang",[p,p+Vector((0,0,.072 if i==0 else .045))],[.021,.002],"cream",bone="jaw",sides=6)
            ear_base=h+Vector((-.03,side*hs.y*.68,hs.z*.61))
            if r["breed"] in ("chin","mastiff"):
                tip=ear_base+Vector((-.10,side*.15,-r["ear"]))
                self.bone("ear"+str(side),ear_base,tip,"head")
                self.tube("Folded breed ear",[ear_base,ear_base+Vector((-.07,side*.12,-.08)),tip],[.16,.17,.085],"coat",bone="ear"+str(side),sides=10)
            else:
                tip=ear_base+Vector((-.08,side*.07,r["ear"]))
                self.bone("ear"+str(side),ear_base,tip,"head")
                a=ear_base+Vector((.12,-.12,0));b=ear_base+Vector((.12,.12,0));back=ear_base+Vector((-.12,0,.025))
                self.mesh("Pointed triangular ear",[a,b,tip,back],[(0,1,2),(0,3,1),(1,3,2),(2,3,0)],"coat",bone="ear"+str(side))
                mid=ear_base+Vector((.10,0,.035))
                self.mesh("Warm recessed inner ear",[mid+Vector((.009,-.076,0)),mid+Vector((.009,.076,0)),tip.lerp(mid,.20)+Vector((.012,0,0))],[(0,1,2)],"pink",bone="ear"+str(side))
            # Graphic fur locks add silhouette without thousands of loose strands.
            count=6 if r["breed"] in ("spitz","chin","husky","akita") else 3
            for i in range(count):
                start=h+Vector((-.05-i*.045,side*(hs.y*.73+i*.008),-.10-i*.045))
                tip=start+Vector((-.15,side*.07,-.12 if r["breed"]!="chin" else -.25))
                self.tube("Layered cheek fur lock",[start,start.lerp(tip,.45),tip],[.070,.060,.004],"cream" if r["breed"]!="chin" else "coat",bone="head",sides=6)
        for tag,(_,_,ankle,toe) in self.legs.items():
            for i in range(3):
                self.ell("Distinct paw toe",ankle+Vector((.245,(i-1)*self.r["leg"]*.56,-.08)),(.075,.045,.065),self.coat_color, bone=tag+"_paw",segments=8,rings=6)
                self.ell("Rounded claw",ankle+Vector((.31,(i-1)*self.r["leg"]*.56,-.073)),(.029,.018,.027),"ink",bone=tag+"_paw",segments=8,rings=4)
        if r["breed"]=="mastiff":
            for i in range(3):
                self.tube("Mastiff forehead wrinkle",[h+Vector((.27, -.17, .19-i*.055)),h+Vector((.31,0,.22-i*.055)),h+Vector((.27,.17,.19-i*.055))],.014,rgb("715238"),bone="head",sides=6)
        self.tail()

    def tail(self):
        r=self.r;H=r["height"];base=Vector((-r["length"]*.45,0,H+.01))
        if r["tail"] in ("curl","plume"):
            # A tight spitz curl rests over the rump, never a squirrel-sized plume.
            points=[base,base+Vector((-.10,0,.13)),base+Vector((-.12,0,.36)),base+Vector((.08,0,.49)),base+Vector((.28,0,.39)),base+Vector((.26,0,.21)),base+Vector((.11,0,.19))]
            radii=[.105,.13,.145,.15,.13,.10,.025]
            if r["tail"]=="plume":radii=[v*1.15 for v in radii]
        else:
            lift=.36 if r["tail"] in ("flow","silk") else -.38
            points=[base,base+Vector((-.28,.02,.02)),base+Vector((-.60,.04,lift*.5)),base+Vector((-.92,.07,lift)),base+Vector((-1.13,.08,lift+.16))]
            radii=[.12,.16,.15,.10,.01]
            if r["tail"]=="silk":
                points=[base+(p-base)*.70 for p in points]
                radii=[v*1.15 for v in radii]
        for i in range(3):
            a=points[min(i*2,len(points)-2)];b=points[min(i*2+2,len(points)-1)]
            self.bone("tail"+str(i),a,b,"spine" if i==0 else "tail"+str(i-1))
        # Add curved interpolated rings for a continuous, fluffy articulated tail.
        refined=[];rr=[]
        for i in range(len(points)-1):
            a,b,c,d=points[max(0,i-1)],points[i],points[i+1],points[min(len(points)-1,i+2)]
            for j in range(4):
                t=j/4
                refined.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
                rr.append(radii[i]*(1-t)+radii[i+1]*t)
        refined.append(points[-1]);rr.append(radii[-1])
        def tail_color(p):
            near=min(range(len(refined)),key=lambda i:(p-refined[i]).length_squared)
            underside=p.z<refined[near].z-.025
            return self.colors["cream"] if r["tail"] in ("plume","silk") or (r["tail"]=="curl" and (underside or near>len(refined)*.72)) else self.colors["coat"]
        tail=self.tube("Continuous expressive breed tail",refined,rr,tail_color,sides=12)
        groups=[tail.vertex_groups.new(name="tail"+str(i)) for i in range(3)]
        for vertex in tail.data.vertices:
            near=min(range(len(refined)),key=lambda i:(vertex.co-refined[i]).length_squared)
            t=near/max(1,len(refined)-1)*2;lo=min(2,int(t));hi=min(2,lo+1)
            groups[lo].add([vertex.index],1-(t-lo),"REPLACE")
            if hi!=lo:groups[hi].add([vertex.index],t-lo,"REPLACE")

    def ribbon(self,name,points,width,color,bone="scarf"):
        vertices=[];faces=[]
        for i,p in enumerate(map(Vector,points)):
            for j in range(3):
                offset=(j-1)*width*.5
                vertices.append(p+Vector((0,offset,.025*math.sin(i*1.4+j))))
        for i in range(len(points)-1):
            for j in range(2):a=i*3+j;faces.append((a,a+1,a+4,a+3))
        obj=self.mesh(name,vertices,faces,color,"cloth",bone)
        modifier=obj.modifiers.new("Cloth thickness","SOLIDIFY");modifier.thickness=.012
        bpy.context.view_layer.objects.active=obj;bpy.ops.object.modifier_apply(modifier=modifier.name)
        return obj

    def equipment(self):
        r=self.r;h=self.h;H=r["height"];W=r["width"];gear=r["gear"]
        self.bone("scarf",(.35,0,H+.14),(-.65,0,H+.48),"chest")
        self.band("Fitted indigo neck scarf",h+Vector((-.20,0,-.30)),W*1.12,.25,.23,"cloth","neck")
        self.band("Chest leather harness",(.38,0,H-.05),W*1.05,.41,.085,"leather")
        self.band("Rear leather harness",(-.40,0,H-.09),W*1.01,.35,.07,"leather","spine")
        self.ribbon("Long patterned scarf pennant",[(.32,-.09,H+.20),(-.12,-.29,H+.39),(-.62,-.44,H+.62),(-1.09,-.50,H+.62)],.27 if gear!="wind" else .40,"cloth")
        self.ribbon("Second scarf tail",[(.29,.08,H+.19),(-.05,.28,H+.37),(-.52,.41,H+.35),(-.87,.45,H+.21)],.19,"cloth")
        for side in (-1,1):
            self.box("Square bronze harness buckle",(.32,side*(W+.07),H-.17),(.11,.035,.13),"gold","metal",bevel=.012)
            self.ell("Collar bronze clasp",h+Vector((.12,side*W*.55,-.36)),(.063,.025,.064),"gold","metal","neck",segments=10,rings=6)
        # Embroidered wave lines are low-poly contrasting geometry, not a texture dependency.
        for i in range(3):
            x=-.24-i*.23
            z=H+.40+min(1,(-x-.12)/.5)*.22
            y=-.29-min(1,(-x-.12)/.5)*.15
            self.tube("Scarf wave embroidery",[(x-.06,y-.03,z+.03),(x,y+.015,z+.045),(x+.06,y+.04,z+.01)],.008,rgb("aab4bd"),"cloth","scarf",sides=5)
        if gear in ("scout","tracker"):
            p=Vector((-.10,-W-.115,H+.045));vertical=gear=="tracker"
            axis=Vector((0,0,1)) if vertical else Vector((1,0,.08))
            self.tube("Bound scout scroll",[p-axis*.32,p+axis*.32],.085,rgb("d9c79b"),"cloth","chest",sides=12)
            for t in [-.31,.31]:self.tube("Scroll bronze end",[p+axis*(t-.022),p+axis*(t+.022)],.102,"gold","metal","chest",sides=12)
            for t in [-.16,.16]:self.tube("Scroll indigo binding",[p+axis*(t-.02),p+axis*(t+.02)],.092,"cloth","cloth","chest",sides=12)
            if gear=="scout":
                for i in range(2):
                    p=Vector((-.31+i*.27,-W-.12,H-.29))
                    self.ell("Scout smoke bomb",p,(.115,.095,.13),"ink","metal","chest",segments=12,rings=8)
                    self.tube("Bomb rope and tassel",[p+Vector((0,0,.13)),p+Vector((0,0,.23))],.022,"cloth","cloth","chest",sides=6)
            else:
                for i,color in enumerate(["5b8b76","7996aa","aa7843"]):
                    p=Vector((-.20+i*.18,-W-.14,H-.26))
                    self.tube("Tracker vial",[p,p+Vector((0,0,.20))],[.047,.047],rgb(color),"eyes","chest",sides=10)
                    self.tube("Vial stopper",[p+Vector((0,0,.20)),p+Vector((0,0,.245))],.031,"gold","metal","chest",sides=8)
                self.box("Map satchel",(-.39,0,H+.27),(.42,.38,.19),"leather",bone="spine")
        if gear in ("armor","shield"):
            for side in (-1,1):
                for row in range(3):
                    p=(.29,side*(W+.11+row*.02),H+.20-row*.17)
                    self.box("Layered lamellar shoulder",p,(.50,.08,.21),"ink","metal",bevel=.035)
                    self.box("Bronze shoulder edge",(p[0],p[1]+side*.045,p[2]-.075),(.51,.026,.035),"gold","metal",bevel=.008)
                    for column in range(4):
                        self.box("Red armor lacing",(p[0]-.18+column*.12,p[1]+side*.055,p[2]),(.025,.021,.12),"red",bevel=.007)
            for row in range(3):
                self.box("Overlapping chest cuirass",(.73,0,H-.15-row*.15),(.10,W*1.65,.19),"ink","metal",bevel=.035)
                self.box("Chest bronze trim",(.79,0,H-.21-row*.15),(.04,W*1.69,.04),"gold","metal",bevel=.01)
            if gear=="armor":
                self.band("Akita iron brow helmet",h+Vector((-.03,0,.18)),self.hs.y*1.11,.28,.18,"ink","head","metal")
                self.ell("Guardian sun crest",h+Vector((self.hs.x*.70,0,.26)),(.045,.095,.095),"gold","metal","head",segments=12,rings=8)
            else:
                self.box("Massive curved shield",(-.18,-W-.25,H-.05),(1.0,.11,.89),"ink","metal","spine",.11)
                for z in [-.39,.39]:self.box("Shield bronze edge",(-.18,-W-.32,H-.05+z),(1.01,.05,.07),"gold","metal","spine",.02)
                for x in [-.45,.45]:self.box("Shield bronze side",(-.18+x,-W-.32,H-.05),(.07,.05,.86),"gold","metal","spine",.02)
                p=Vector((-.18,-W-.33,H-.04))
                points=[p+Vector((math.cos(i/28*TAU*2)*(.26-i*.006),-.008,math.sin(i/28*TAU*2)*(.26-i*.006))) for i in range(29)]
                self.tube("Shield spiral crest",points,.020,"gold","metal","spine",sides=6)
        if gear=="leaves":
            rng=random.Random(301)
            for side in (-1,1):
                for row in range(3):
                    for column in range(6):
                        p=Vector((-.64+column*.21,side*(W+.055+row*.03),H+.29-row*.18))
                        vertices=[p+Vector((-.08,0,.06)),p+Vector((.07,0,.04)),p+Vector((.13,side*.028,-.12)),p+Vector((0,side*.045,-.29)),p+Vector((-.14,side*.028,-.12)),p+Vector((0,side*.07,-.09))]
                        self.mesh("Layered camouflage leaf",vertices,[(5,0,1),(5,1,2),(5,2,3),(5,3,4),(5,4,0)],rgb(rng.choice(["5d653e","777451","454f32"])),"cloth","chest" if column>3 else "spine")
            for x in [-.4,.0]:self.box("Ambusher leather pouch",(x,-W-.16,H-.15),(.30,.14,.28),"leather",bone="spine",bevel=.05)
        if gear=="blade":
            y=-W-.12;p=Vector((-.16,y,H+.08))
            self.tube("Guard katana scabbard",[p+Vector((-.64,0,-.08)),p+Vector((.40,0,.04))],.055,"cloth","cloth","spine",sides=10)
            self.tube("Sword hilt",[p+Vector((.40,0,.04)),p+Vector((.73,0,.07))],.049,"ink","cloth","spine",sides=10)
            self.ell("Bronze sword guard",p+Vector((.39,0,.035)),(.034,.115,.12),"gold","metal","spine",segments=12,rings=8)
            for i in range(6):self.tube("Hilt wrap",[p+Vector((.44+i*.045,-.041,.03)),p+Vector((.47+i*.045,-.041,.09))],.014,rgb("b6cbd0"),"cloth","spine",sides=5)
        if gear in ("ward","mirage"):
            for side in (-1,1):
                for x in [-.33,.10]:
                    p=Vector((x,side*(W+.09),H-.12))
                    self.box("Sacred ward or silk panel",p,(.28,.05,.45),"cream" if gear=="ward" else "cloth",bone="spine",bevel=.015)
                    if gear=="ward":
                        for z in [-.195,.195]:self.box("Vermilion ward border",p+Vector((0,side*.033,z)),(.25,.012,.025),"red",bone="spine",bevel=.003)
                        for angle in range(5):
                            a=angle*TAU/5;self.ell("Five-petal ward crest",p+Vector((math.cos(a)*.055,side*.034,math.sin(a)*.055)),(.035,.011,.035),"red","cloth","spine",segments=8,rings=5)
            p=h+Vector((.09,-.10,-.40))
            if gear=="ward":
                self.ell("Large guardian bell",p,(.095,.082,.10),"gold","metal","neck",segments=14,rings=8)
                self.box("Bell slit",p+Vector((.076,-.02,-.04)),(.019,.12,.014),"ink",bone="neck",bevel=.002)
            else:
                points=[p+Vector((.018,math.cos(.30+i/18*5.3)*.09,math.sin(.30+i/18*5.3)*.09)) for i in range(19)]
                self.tube("Mirage crescent clasp",points,.025,"gold","metal","neck",sides=8)
        if gear=="climber":
            p=Vector((-.10,-W-.16,H+.07));points=[]
            for i in range(65):
                t=i/64;a=t*TAU*3.3;radius=.27-.13*t;points.append(p+Vector((math.cos(a)*radius,0,math.sin(a)*radius)))
            self.tube("Coiled climbing rope",points,.024,rgb("cbb587"),"cloth","spine",sides=6)
            p=Vector((-.49,-W-.14,H-.26))
            self.tube("Grappling hook shaft",[p,p+Vector((0,0,-.29))],.03,"gold","metal","spine",sides=8)
            for side in [-1,1]:self.tube("Grappling hook prong",[p+Vector((0,0,-.29)),p+Vector((side*.12,0,-.34)),p+Vector((side*.16,0,-.17))],[.03,.03,.012],rgb("a4b7bd"),"metal","spine",sides=8)
        if gear in ("leaves","tracker","climber","wind"):
            for tag,(_,_,ankle,toe) in self.legs.items():
                self.tube("Bound ankle wrap",[ankle+Vector((0,0,.03)),ankle+Vector((0,0,.23))],[r["leg"]*.81,r["leg"]*.95],"cloth","cloth",tag+"_lower",sides=12)
                for i in range(3):self.tube("Ankle binding stitch",[ankle+Vector((-.06,-r["leg"],.065+i*.048)),ankle+Vector((.065,-r["leg"],.09+i*.048))],.009,"gold","cloth",tag+"_lower",sides=5)

    def create_rig(self):
        bpy.ops.object.select_all(action="DESELECT")
        data=bpy.data.armatures.new(self.r["name"]+" canine skeleton")
        rig=bpy.data.objects.new("DogRig",data);bpy.context.collection.objects.link(rig)
        bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode="EDIT")
        for name,(head,tail,parent,deform) in self.bones.items():
            bone=data.edit_bones.new(name);bone.head=head;bone.tail=tail;bone.use_deform=deform
            if parent:bone.parent=data.edit_bones[parent]
        bpy.ops.object.mode_set(mode="OBJECT")
        for tag in self.legs:
            lower=rig.pose.bones[tag+"_lower"]
            constraint=lower.constraints.new("IK");constraint.target=rig;constraint.subtarget=tag+"_ik";constraint.chain_count=2;constraint.use_stretch=False
            paw=rig.pose.bones[tag+"_paw"]
            constraint=paw.constraints.new("COPY_ROTATION");constraint.target=rig;constraint.subtarget=tag+"_ik";constraint.owner_space="WORLD";constraint.target_space="WORLD"
            # IK targets share the paw's rest orientation for flat planted toes.
        # Join every fur/equipment surface into one weighted mesh.
        bpy.ops.object.select_all(action="DESELECT")
        for obj in self.objects:obj.select_set(True)
        bpy.context.view_layer.objects.active=self.objects[0];bpy.ops.object.join();mesh=bpy.context.object
        mesh.name=self.r["name"]+"_Skinned"
        mesh.parent=rig;mesh.matrix_parent_inverse=Matrix.Identity(4)
        modifier=mesh.modifiers.new("Canine skin deformation","ARMATURE");modifier.object=rig
        for vertex in mesh.data.vertices:
            if not vertex.groups:
                group=mesh.vertex_groups.get("chest") or mesh.vertex_groups.new(name="chest");group.add([vertex.index],1,"REPLACE")
        rig.rotation_euler.z=math.pi/2
        self.rig=rig;self.mesh=mesh
        assert sum(len(p.vertices)-2 for p in mesh.data.polygons)<=15000,(self.id,"triangle budget exceeded")
        assert len(mesh.data.materials)<=6
        rig["forward_axis"]="Godot -Z";rig["attack_contact_seconds"]=.38
        rig["run_reference_speed_mps"]=2.4
        for bone in rig.pose.bones:bone.rotation_mode="QUATERNION"
        return rig,mesh

    def turn(self,name,axis,angle):
        bone=self.rig.pose.bones[name]
        local_axis=bone.bone.matrix_local.to_3x3().inverted()@Vector(axis)
        bone.rotation_quaternion=Quaternion(local_axis.normalized(),angle)

    def move(self,name,offset):
        bone=self.rig.pose.bones[name]
        bone.location=bone.bone.matrix_local.to_3x3().inverted()@Vector(offset)

    def animate(self):
        rig=self.rig
        def envelope(t,points):
            for i in range(len(points)-1):
                if t<=points[i+1][0]:
                    a,v=points[i];b,w=points[i+1];f=max(0,min(1,(t-a)/(b-a)));f=f*f*(3-2*f);return v+(w-v)*f
            return points[-1][1]
        for clip,duration in DURATIONS.items():
            rig.animation_data_create();rig.animation_data.action=None
            for track in rig.animation_data.nla_tracks:track.mute=True
            end=round(duration*FPS)
            for frame in sorted(set(range(0,end+1,2))|{end}):
                t=frame/FPS;phase=t/duration
                for bone in rig.pose.bones:bone.location=(0,0,0);bone.rotation_quaternion=(1,0,0,0);bone.scale=(1,1,1)
                if clip=="idle":
                    breath=math.sin(phase*TAU)
                    self.move("chest",(0,0,.012*breath));self.turn("head",(0,0,1),.025*breath)
                    self.turn("tail0",(1,0,0),.08*breath);self.turn("tail1",(0,0,1),.05*math.sin(phase*TAU+.4))
                    self.turn("scarf",(0,0,1),.035*math.sin(phase*TAU+.7))
                    for side in (-1,1):self.turn("ear"+str(side),(1,0,0),.025*math.sin(phase*TAU+side*.6))
                elif clip=="run":
                    self.move("chest",(0,0,.045*math.cos(phase*TAU*2)));self.turn("neck",(0,1,0),.045*math.sin(phase*TAU*2))
                    for tag,(_,_,ankle,toe) in self.legs.items():
                        offset=0 if tag in ("front_L","back_R") else .5
                        p=(phase+offset)%1
                        if p<.55:x=.53-(p/.55)*1.06;z=0.0
                        else:
                            f=(p-.55)/.45;x=-.53+1.06*(f*f*(3-2*f));z=.26*math.sin(f*math.pi)
                        self.move(tag+"_ik",(x,0,z))
                    self.turn("tail0",(0,1,0),.06*math.sin(phase*TAU));self.turn("scarf",(0,0,1),.09*math.sin(phase*TAU))
                elif clip=="attack":
                    lunge=envelope(t,[(0,0),(.17,-.13),(.38,.28),(.49,.20),(.75,0),(1,0)])
                    bite=envelope(t,[(0,0),(.16,.12),(.30,.62),(.38,.025),(.48,.12),(.75,0),(1,0)])
                    self.move("chest",(lunge,0,-abs(lunge)*.16));self.turn("neck",(0,1,0),-.10 if .2<t<.5 else 0)
                    self.turn("head",(0,1,0),envelope(t,[(0,0),(.19,-.09),(.38,.10),(.60,0),(1,0)]))
                    self.turn("jaw",(0,1,0),bite)
                    for tag in self.legs:
                        if tag.startswith("front"):
                            self.move(tag+"_ik",(lunge*.6,0,.12*math.sin(min(1,t/.38)*math.pi) if t<.38 else 0))
                    self.turn("scarf",(0,1,0),-lunge*.5)
                elif clip=="hurt":
                    f=envelope(t,[(0,0),(.12,1),(.30,.45),(.45,0)])
                    self.move("chest",(-.16*f,0,-.07*f));self.turn("head",(0,0,1),.18*f);self.turn("jaw",(0,1,0),.12*f)
                    self.turn("tail0",(0,1,0),.18*f)
                else:
                    f=envelope(t,[(0,0),(.18,.15),(.60,1),(.9,1)])
                    self.move("spine",(0,.12*f,-self.r["height"]*.53*f));self.turn("spine",(1,0,0),.86*f)
                    self.turn("neck",(0,1,0),.37*f);self.turn("head",(1,0,0),.15*f);self.turn("jaw",(0,1,0),.14*f)
                    for tag in self.legs:self.move(tag+"_ik",(.04,.16*f if tag.endswith("R") else -.16*f,.02*f))
                    self.turn("tail0",(0,1,0),.3*f)
                for bone in rig.pose.bones:
                    bone.keyframe_insert("location",frame=frame,group=bone.name)
                    bone.keyframe_insert("rotation_quaternion",frame=frame,group=bone.name)
            # Include fractional endpoints such as hurt(.45s) exactly.
            for bone in rig.pose.bones:
                bone.keyframe_insert("location",frame=end,group=bone.name)
                bone.keyframe_insert("rotation_quaternion",frame=end,group=bone.name)
            action=rig.animation_data.action;action.name=self.id+"_"+clip
            track=rig.animation_data.nla_tracks.new();track.name=clip+"_loop" if clip in ("idle","run") else clip
            strip=track.strips.new(action.name,0,action);strip.action_frame_start=0;strip.action_frame_end=end;strip.frame_start=0;strip.frame_end=end
            track.mute=True;rig.animation_data.action=None
        for track in rig.animation_data.nla_tracks:track.mute=False
        self.actions={track.name:track.strips[0].action for track in rig.animation_data.nla_tracks}

    def preview_pose(self,clip="idle",seconds=.35):
        for track in self.rig.animation_data.nla_tracks:track.mute=True
        self.rig.animation_data.action=self.actions[clip+"_loop" if clip in ("idle","run") else clip]
        bpy.context.scene.frame_set(int(seconds*FPS))


def studio(builder):
    scene=bpy.context.scene;scene.render.engine="CYCLES";scene.cycles.samples=40
    scene.world.color=(.20,.23,.29);scene.view_settings.view_transform="AgX"
    scene.render.image_settings.file_format="PNG";scene.render.film_transparent=False
    ground=bpy.data.materials.new("Studio warm slate");ground.diffuse_color=(.11,.14,.16,1)
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.018));floor=bpy.context.object;floor.name="STUDIO floor · excluded from exports";floor.data.materials.append(ground)
    for name,p,power,size,color in [
        ("Warm key",(4,-5,7),800,5,(1,.82,.65)),
        ("Sky fill",(1,4,5),650,4,(.60,.77,1)),
        ("Rim",(-4,1,6),1000,4,(1,.88,.7))]:
        point=R90@Vector(p);bpy.ops.object.light_add(type="AREA",location=point);light=bpy.context.object;light.name=name;light.data.energy=power;light.data.shape="DISK";light.data.size=size;light.data.color=color
        light.rotation_euler=(R90@Vector((0,0,1))-point).to_track_quat("-Z","Y").to_euler()
    bpy.ops.object.camera_add(location=R90@Vector((4.9,-6.3,3.3)));camera=bpy.context.object;camera.name="Full body review camera";camera.data.type="ORTHO";camera.data.ortho_scale=4.35
    camera.rotation_euler=(R90@Vector((0,0,1.02))-camera.location).to_track_quat("-Z","Y").to_euler();scene.camera=camera
    return floor,camera


def build(config):
    source=SOURCE/(config["id"]+".blend")
    if source.exists() and not ARGS.replace:raise RuntimeError(f"{source} already exists; pass --replace for an intentional rebuild")
    bpy.ops.object.select_all(action="SELECT");bpy.ops.object.delete(use_global=False)
    for data in list(bpy.data.actions):bpy.data.actions.remove(data)
    # Primitives consumed by joins/remeshing retain datablocks until purged.
    # Keep the ten-model batch at one model's working-set size.
    bpy.data.orphans_purge(do_local_ids=True,do_linked_ids=True,do_recursive=True)
    scene=bpy.context.scene;scene.unit_settings.system="METRIC";scene.render.fps=FPS;scene.frame_start=0;scene.frame_end=120
    builder=DogBuilder(config);builder.anatomy_mesh();builder.details();builder.equipment();rig,mesh=builder.create_rig();builder.animate()
    bpy.ops.object.select_all(action="DESELECT");rig.select_set(True);mesh.select_set(True);bpy.context.view_layer.objects.active=rig
    rig.animation_data.action=None;scene.frame_set(0)
    bpy.ops.export_scene.gltf(filepath=str(OUT/(config["id"]+".glb")),export_format="GLB",use_selection=True,export_yup=True,export_cameras=False,export_lights=False,
        export_animations=True,export_animation_mode="NLA_TRACKS",export_force_sampling=True,export_frame_range=False,export_frame_step=1,export_def_bones=True,
        export_skins=True,export_all_influences=False)
    builder.preview_pose("idle",.35)
    floor,camera=studio(builder)
    scene["source_reference_branch"]="feat/ninja-dog-models @ f511c48"
    scene["rebuild_notes"]="Original game-ready remeshed anatomy, breed paint, simplified reference equipment, 4-material skinned mesh and authored IK quadruped animation. Upstream static sculpts preserved untouched."
    scene["attack_contact_seconds"]=.38
    scene["game_forward"]="-Z"
    scene.render.resolution_x=1100;scene.render.resolution_y=800;scene.render.resolution_percentage=100
    scene.render.filepath=str(EVIDENCE/(config["id"]+"-full.png"))
    bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True)
    if not ARGS.skip_render and not ARGS.skip_full_review:bpy.ops.render.render(write_still=True)
    # A true Blender-rendered transparent bust, consistently lit across the roster.
    floor.hide_render=True;scene.render.film_transparent=True
    camera.name="Portrait three-quarter camera"
    aim=builder.h+Vector((-.10,0,.04 if config["breed"] not in ("chin","mastiff") else -.07));camera.location=R90@(aim+Vector((3.3,-4.2,1.50)))
    camera.rotation_euler=(R90@aim-camera.location).to_track_quat("-Z","Y").to_euler();camera.data.ortho_scale=max(1.55,config["hs"][2]*3.9+config["ear"]*.75)
    scene.render.resolution_x=512;scene.render.resolution_y=512;scene.render.filepath=str(PORTRAITS/(config["id"]+".png"))
    if not ARGS.skip_render:bpy.ops.render.render(write_still=True)
    triangles=sum(len(p.vertices)-2 for p in mesh.data.polygons)
    ref=next((PACK/"references").glob("*-"+config["id"]+"-*.png"))
    record={"id":config["id"],"name":config["name"],"breed":config["breed"],"gear":config["gear"],"source":str(source.relative_to(ROOT)),"model":str((OUT/(config["id"]+".glb")).relative_to(ROOT)),"portrait":str((PORTRAITS/(config["id"]+".png")).relative_to(ROOT)),"triangles":triangles,"meshes":1,"materials":len(mesh.data.materials),"bones":len(rig.data.bones),"deform_bones":sum(b.use_deform for b in rig.data.bones),"animations":DURATIONS,"attack_contact":.38,"run_reference_speed":2.4,"forward":"Godot -Z","reference":str(ref.relative_to(ROOT)),"reference_sha256":hashlib.sha256(ref.read_bytes()).hexdigest(),"glb_sha256":hashlib.sha256((OUT/(config["id"]+".glb")).read_bytes()).hexdigest()}
    assert triangles<=15000,(config["id"],triangles)
    assert len(mesh.data.materials)<=6
    (SOURCE/(config["id"]+".json")).write_text(json.dumps(record,indent=2)+"\n")
    print("DEFENSE_DOG_BUILT",json.dumps(record),flush=True)
    return record


def render_lineup():
    """A single studio render containing all ten actual delivered skinned meshes."""
    bpy.ops.object.select_all(action="SELECT");bpy.ops.object.delete(use_global=False)
    scene=bpy.context.scene;scene.render.engine="CYCLES";scene.cycles.samples=40
    scene.world.color=(.15,.19,.25);scene.view_settings.view_transform="AgX"
    scene.render.film_transparent=False;scene.render.image_settings.file_format="PNG"
    ground=Vector((7,5,0)).normalized();right=Vector((-ground.y,ground.x,0))
    rigs=[]
    for index,config in enumerate(DOGS):
        with bpy.data.libraries.load(str(SOURCE/(config["id"]+".blend")),link=False) as (available,wanted):
            wanted.objects=[name for name in available.objects if name=="DogRig" or name==config["name"]+"_Skinned"]
        for obj in wanted.objects:scene.collection.objects.link(obj)
        rig=next(obj for obj in wanted.objects if obj.type=="ARMATURE")
        rig.location=right*((index%5-2)*4.0)+ground*(3.2 if index>=5 else -3.2)
        rigs.append((config,rig))
    scene.frame_set(21)
    floor_mat=bpy.data.materials.new("Lineup slate");floor_mat.use_nodes=True
    floor_mat.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value=(.055,.075,.095,1)
    floor_mat.node_tree.nodes.get("Principled BSDF").inputs["Roughness"].default_value=.86
    bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.04));bpy.context.object.data.materials.append(floor_mat)
    bpy.ops.object.camera_add(location=ground*24+Vector((0,0,14)))
    camera=bpy.context.object;camera.name="Ten canine allies · lineup camera";camera.data.type="ORTHO";camera.data.ortho_scale=22.4
    camera.rotation_euler=(Vector((0,0,.55))-camera.location).to_track_quat("-Z","Y").to_euler();scene.camera=camera
    label_mat=bpy.data.materials.new("Warm ivory labels");label_mat.use_nodes=True
    label_mat.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value=(.85,.79,.63,1)
    label_mat.node_tree.nodes.get("Principled BSDF").inputs["Emission Color"].default_value=(.85,.79,.63,1)
    label_mat.node_tree.nodes.get("Principled BSDF").inputs["Emission Strength"].default_value=.25
    for config,rig in rigs:
        bpy.ops.object.text_add(location=rig.location+ground*1.40+Vector((0,0,.10)))
        label=bpy.context.object;label.name=config["name"]+" lineup label";label.data.body=config["name"].upper();label.data.align_x="CENTER";label.data.size=.32;label.data.extrude=.003
        label.rotation_euler=camera.rotation_euler;label.data.materials.append(label_mat)
    for name,location,power,size,color in [
        ("Broad warm key",(3,-8,14),4300,14,(1,.86,.73)),
        ("Blue sky fill",(-8,3,11),3300,12,(.72,.83,1)),
        ("Back rim",(2,10,12),4700,12,(1,.9,.74))]:
        bpy.ops.object.light_add(type="AREA",location=location);light=bpy.context.object;light.name=name;light.data.energy=power;light.data.size=size;light.data.color=color
        light.rotation_euler=(Vector((0,0,1))-light.location).to_track_quat("-Z","Y").to_euler()
    scene.render.resolution_x=2200;scene.render.resolution_y=850;scene.render.resolution_percentage=100
    scene.render.filepath=str(EVIDENCE/"ten-dog-lineup.png")
    bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/"Ten_Dog_Lineup.blend"),compress=True)
    bpy.ops.render.render(write_still=True)
    print("DEFENSE_DOG_LINEUP",scene.render.filepath,flush=True)


def render_existing_portrait(config):
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE/(config["id"]+".blend")))
    scene=bpy.context.scene;camera=scene.camera
    bpy.data.objects["STUDIO floor · excluded from exports"].hide_render=True
    scene.render.film_transparent=True
    aim=Vector(config["head"])+Vector((-.10,0,.04 if config["breed"] not in ("chin","mastiff") else -.07))
    camera.location=R90@(aim+Vector((3.3,-4.2,1.50)))
    camera.rotation_euler=(R90@aim-camera.location).to_track_quat("-Z","Y").to_euler()
    camera.data.ortho_scale=max(1.55,config["hs"][2]*3.9+config["ear"]*.75)
    scene.render.resolution_x=512;scene.render.resolution_y=512
    scene.render.filepath=str(PORTRAITS/(config["id"]+".png"))
    bpy.ops.render.render(write_still=True)


if ARGS.lineup_only:
    render_lineup()
    sys.exit(0)

if ARGS.portraits_only:
    for config in DOGS:
        if ARGS.only is None or config["id"]==ARGS.only:render_existing_portrait(config)
    sys.exit(0)

selected=[r for r in DOGS if r["id"]==ARGS.only] if ARGS.only else DOGS
if ARGS.resume:selected=[r for r in selected if not (SOURCE/(r["id"]+".json")).exists()]
if ARGS.resume and not selected:
    print("All requested dog outputs have already been built.")
    sys.exit(0)
if not selected:raise RuntimeError("Unknown dog id")
records=[]
for config in selected:records.append(build(config))
all_records=[json.loads(path.read_text()) for path in sorted(SOURCE.glob("*.json")) if path.name!="manifest.json"]
(SOURCE/"manifest.json").write_text(json.dumps({"schema_version":1,"reference_branch":"feat/ninja-dog-models","reference_commit":"f511c48","blender_version":bpy.app.version_string,"scope":"Ten reference-led original skinned game rebuilds; upstream sources untouched","assets":all_records},indent=2)+"\n")
(SOURCE/"PROVENANCE.md").write_text("# Castle ally dog models\n\nThese models are new Blender game-ready rebuilds of the ten approved dog identities on `feat/ninja-dog-models` at `f511c48`. Their original PNG references and dense static sculptures remain preserved under `asset_packs/ninja_dogs`. All references were visually reviewed before the rebuild.\n\nEach dog has newly authored unified canine anatomy, vertex-painted breed markings, distinct ears/tail/equipment, an editable armature with planted-foot IK, and authored idle/run/bite/hurt/death clips. Mesh surfaces are merged by material; no dense static sculpture is used at runtime. Portraits are transparent Blender renders of the delivered dog meshes.\n\nThe animation contact for `attack` is 0.38 seconds into a 1-second clip. The run reference speed is 2.4 m/s; the runtime should advance the run animation proportionally to actual horizontal speed. Idle/run use Blender `_loop` naming hints; normal Godot imports expose `idle` and `run`.\n\nRebuild with `tools/build_defense_dogs.py`; per-dog JSON and `manifest.json` record geometry/rig budgets, clip timings, reference hashes and output hashes. Fine illustrated fur and embroidery are interpreted as deliberate, inexpensive stylized forms.\n")
