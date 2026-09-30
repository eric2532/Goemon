"""Original Azure Ember asset authoring. Run with local Blender --background --python.
Coordinates in helpers are Godot metres (X right, Y up, -Z forward).
This generator is an initial authoring/rebuild tool; normal edits use saved .blend + export_blender.py.
"""
import bpy, math, random, json
from mathutils import Vector
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
random.seed(91)
MATS={}
PARTS={}
DETAIL=False
BONES={'Root':(0,0,0),'Head':(0,1.98,0),'Arm_L':(-.49,1.58,0),'Arm_R':(.49,1.58,0),'Leg_L':(-.25,.91,0),'Leg_R':(.25,.91,0),'Sash':(.2,1.04,.47)}
def cv(p): return Vector((p[0],-p[2],p[1]))
def srgb(v): return v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4
def mat(h,metal=0,glow=0):
    key=(h,metal,glow)
    if key in MATS: return MATS[key]
    m=bpy.data.materials.new('Palette_'+h);m.use_nodes=True
    rgba=tuple(srgb(int(h[i:i+2],16)/255) for i in (0,2,4))+(1,)
    m.diffuse_color=rgba;p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=rgba;p.inputs['Roughness'].default_value=.66;p.inputs['Metallic'].default_value=metal
    p.inputs['Emission Color'].default_value=rgba;p.inputs['Emission Strength'].default_value=glow
    m['metal']=metal;m['glow']=glow;MATS[key]=m
    return m
def finish(o,name,m,bone=None):
    o.name=name
    o.data.materials.append(m)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bone:
        g=o.vertex_groups.new(name=bone);g.add(list(range(len(o.data.vertices))),1,'REPLACE')
    return o
def ell(name,p,size,m,bone=None,seg=20,rings=12):
    if DETAIL:seg=min(seg,16);rings=min(rings,8)
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg,ring_count=rings,radius=.5,location=cv(p))
    o=bpy.context.object;o.scale=(size[0],size[2],size[1])
    finish(o,name,m,bone)
    for f in o.data.polygons:f.use_smooth=True
    return o
def box(name,p,size,m,bone=None,bevel=.035):
    bpy.ops.mesh.primitive_cube_add(size=1,location=cv(p));o=bpy.context.object;o.scale=(size[0],size[2],size[1])
    finish(o,name,m,bone)
    if bevel:
        mod=o.modifiers.new('Soft game edges','BEVEL');mod.width=bevel;mod.segments=2
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return o
def mesh(name,verts,faces,m,bone=None):
    data=bpy.data.meshes.new(name);data.from_pydata([cv(v) for v in verts],[],faces);data.update()
    o=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(o)
    bpy.context.view_layer.objects.active=o;o.select_set(True)
    return finish(o,name,m,bone)
def beam(name,a,b,r,m,bone=None,r2=None,vertices=12):
    va,vb=cv(a),cv(b);bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=r,radius2=r if r2 is None else r2,depth=(vb-va).length,location=(va+vb)*.5)
    o=bpy.context.object;o.rotation_mode='QUATERNION';o.rotation_quaternion=(vb-va).to_track_quat('Z','Y')
    finish(o,name,m,bone);bpy.ops.object.transform_apply(location=False,rotation=True,scale=False)
    return o
def path(name,pts,r,m,bone=None):
    out=[]
    for a,b in zip(pts,pts[1:]):out.append(beam(name,a,b,r,m,bone,vertices=8))
    return out
def spike(name,base,tip,width,depth,m,bone='Head'):
    # Broad five-sided faceted anime hair, deliberately not conical needles.
    x,y,z=base
    verts=[(x-width,y,z),(x,y+width*.40,z-depth),(x+width,y,z),(x+width*.55,y-width*.50,z+depth),(x-width*.55,y-width*.50,z+depth),tip]
    return mesh(name,verts,[(0,1,5),(1,2,5),(2,3,5),(3,4,5),(4,0,5),(4,3,2,1,0)],m,bone)
def ring(name,p,r,thickness,m,bone=None,front=False):
    bpy.ops.mesh.primitive_torus_add(major_segments=32,minor_segments=6,location=cv(p),major_radius=r,minor_radius=thickness)
    o=bpy.context.object
    if front:o.rotation_euler.x=math.pi/2
    finish(o,name,m,bone);bpy.ops.object.transform_apply(location=False,rotation=True,scale=False)
    return o
def start():
    bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
    for data in list(bpy.data.materials):bpy.data.materials.remove(data)
    MATS.clear()
    bpy.context.scene.cursor.location=(0,0,0)
    bpy.context.scene.unit_settings.system='METRIC';bpy.context.scene.unit_settings.scale_length=1
    bpy.context.scene.render.fps=30
def objects():return [o for o in bpy.context.scene.objects if o.type=='MESH']
def join(obs,name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in obs:o.select_set(True)
    bpy.context.view_layer.objects.active=obs[0];bpy.ops.object.join()
    o=bpy.context.object;o.name=name
    bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    return o
def palette(o):
    # Collapse the entire colored model into at most three PBR draw surfaces.
    attr=o.data.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='CORNER')
    categories={}
    for poly in o.data.polygons:
        old=o.data.materials[poly.material_index]
        cat='Metal' if old.get('metal',0)>.3 else ('Glow' if old.get('glow',0)>.2 else 'Matte')
        categories.setdefault(cat,len(categories))
        for idx in poly.loop_indices:attr.data[idx].color=old.diffuse_color
        poly.material_index=categories[cat]
    indices=[p.material_index for p in o.data.polygons]
    o.data.materials.clear()
    for cat in categories:
        name='Game_'+cat
        m=bpy.data.materials.get(name)
        if not m:
            m=bpy.data.materials.new(name);m.use_nodes=True
            bs=m.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(1,1,1,1)
            bs.inputs['Metallic'].default_value=.6 if cat=='Metal' else 0
            bs.inputs['Roughness'].default_value=.42 if cat=='Metal' else .72
            color=m.node_tree.nodes.new('ShaderNodeVertexColor');color.layer_name='Color'
            m.node_tree.links.new(color.outputs['Color'],bs.inputs['Base Color'])
            if cat=='Glow':
                m.node_tree.links.new(color.outputs['Color'],bs.inputs['Emission Color'])
                bs.inputs['Emission Strength'].default_value=.3
        o.data.materials.append(m)
    for poly,idx in zip(o.data.polygons,indices):poly.material_index=idx
    bpy.ops.object.select_all(action='DESELECT')
    bpy.context.view_layer.objects.active=o;o.select_set(True)
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.normals_make_consistent(inside=False) if hasattr(bpy.ops.mesh,'normals_make_consistent') else None
    bpy.ops.uv.smart_project(angle_limit=1.15192,island_margin=.015)
    bpy.ops.object.mode_set(mode='OBJECT')
def rig_model(obs):
    arm=bpy.data.armatures.new('Kai_Articulation');rig=bpy.data.objects.new('Rig',arm);bpy.context.collection.objects.link(rig)
    bpy.context.view_layer.objects.active=rig;rig.select_set(True);bpy.ops.object.mode_set(mode='EDIT')
    for name,p in BONES.items():
        b=arm.edit_bones.new(name);b.head=cv(p);b.tail=b.head+Vector((0,0,.2))
        if name!='Root':b.parent=arm.edit_bones['Root']
    bpy.ops.object.mode_set(mode='OBJECT')
    rig.show_in_front=True
    for o in obs:
        o.parent=rig;mod=o.modifiers.new('Game skeleton','ARMATURE');mod.object=rig
    # Real editable/exported skeletal actions, not timing triggers for hitboxes.
    clips={'Idle':60,'Run':24,'Sprint':20,'Attack_Left':12,'Attack_Right':12,'Attack_Finish':16,'Heavy':24,'Charge_Spin':24,'Throw':12,'Jump':18,'Front_Flip':16,'Hit':12,'Death':30}
    for name,end in clips.items():
        rig.animation_data_create();action=bpy.data.actions.new(name);rig.animation_data.action=action
        for f in range(1,end+1,2):
            t=(f-1)/(end-1)
            for b in rig.pose.bones:
                b.rotation_mode='XYZ';b.rotation_euler=(0,0,0);b.location=(0,0,0);b.scale=(1,1,1)
            root=rig.pose.bones['Root']
            if name=='Idle':root.location.z=math.sin(t*math.tau)*.018
            elif name in ('Run','Sprint'):
                for i,side in enumerate(('L','R')):
                    a=math.sin(t*math.tau+i*math.pi)
                    rig.pose.bones['Leg_'+side].rotation_euler.x=a*.8
                    rig.pose.bones['Arm_'+side].rotation_euler.x=-a*.65
                root.rotation_euler.x=.20 if name=='Sprint' else .04
            elif name.startswith('Attack'):
                sign=-1 if name=='Attack_Right' else 1
                root.rotation_euler.z=(-.7+1.5*math.sin(t*math.pi))*sign
                rig.pose.bones['Arm_R'].rotation_euler.x=1.35*math.sin(t*math.pi)
                rig.pose.bones['Arm_R'].rotation_euler.z=(-1+2*t)*sign
            elif name=='Charge_Spin':root.rotation_euler.z=t*math.tau
            elif name in ('Throw','Heavy'):rig.pose.bones['Arm_R'].rotation_euler.x=math.sin(t*math.pi)*2
            elif name=='Jump':
                rig.pose.bones['Leg_L'].rotation_euler.x=.6;rig.pose.bones['Leg_R'].rotation_euler.x=-.4
            elif name=='Front_Flip':root.rotation_euler.x=t*math.tau
            elif name=='Hit':root.rotation_euler.x=-math.sin(t*math.pi)*.28
            elif name=='Death':root.rotation_euler.x=-t*1.5;root.location.z=-t*.3
            for b in rig.pose.bones:
                b.keyframe_insert('rotation_euler',frame=f,group=b.name)
                b.keyframe_insert('location',frame=f,group=b.name)
        track=rig.animation_data.nla_tracks.new();track.name=name;track.strips.new(name,1,action);track.mute=True
        action.use_fake_user=True
    rig.animation_data.action=None
    for b in rig.pose.bones:b.rotation_euler=(0,0,0);b.location=(0,0,0)
    return rig
def save(category,name):
    blend=ROOT/'assets/blender'/category/(name+'.blend');glb=ROOT/'assets/models'/category/(name+'.glb')
    bpy.context.scene['asset_id']=category+'/'+name
    bpy.context.scene['godot_forward']='-Z';bpy.context.scene['metres_per_unit']=1.0
    bpy.context.scene['export_path']=str(glb)
    bpy.context.scene['pipeline']='Azure Ember / Blender source → GLB / vertex palette, applied scale'
    bpy.context.scene.frame_set(1)
    hidden=[]
    for o in objects():
        if o.name=='Hair_Gold':o.hide_set(True);hidden.append(o)
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':
                area.spaces.active.shading.color_type='VERTEX'
                area.spaces.active.region_3d.view_distance=6
                area.spaces.active.region_3d.view_location=cv((0,1.6,0))
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    for o in hidden:o.hide_set(False)
    for o in bpy.context.scene.objects:
        if o.type=='ARMATURE':
            for track in o.animation_data.nla_tracks:track.mute=False
    bpy.ops.export_scene.gltf(filepath=str(glb),export_format='GLB',export_yup=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_nla_strips=True,export_skins=True,export_apply=False)
    meshes=objects();tri=sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes)
    stats.append({'asset':category+'/'+name,'triangles':tri,'meshes':len(meshes),'surfaces':sum(len(o.data.materials) for o in meshes),'bytes':glb.stat().st_size})
    print('ASSET_EXPORTED',name,tri)
def character(ninja=False,boss=False,variant=0):
    global DETAIL
    DETAIL=ninja
    start()
    skin=mat('ffd093');blue=mat('243bd5');dark=mat('121a48');red=mat('ee3826');yellow=mat('ffd231');cream=mat('fff0c8');white=mat('fff9e6');metal=mat('a6b8c8',.65)
    if ninja:
        yellow=mat(['713759','218c79','cb668e','aa432c'][variant] if boss else '244552')
        red=mat('bd4141' if boss else '354776');blue=mat(['331e48','214968','4b3068','66252e'][variant] if boss else '172637')
    ell('Vest back',(0,1.35,.22),(.77,.72,.21),yellow,'Root')
    # Rounded, tailored torso rather than rectangular floating panels.
    ell('Undershirt',(0,1.31,0),(.76,.81,.51),cream,'Root')
    for side in [-1,1]:
        ell('Vest panel',(side*.27,1.35,-.025),(.28,.77,.58),yellow,'Root')
        path('Crimson piping',[(side*.20,1.71,-.25),(side*.16,1.42,-.32),(side*.11,1.10,-.30)],.043,red,'Root')
    beam('Waist sash',(0,.89,0),(0,1.08,0),.425,yellow,'Root',vertices=20)
    ring('Sash medallion',(0,.985,-.431),.115,.034,mat('ffdd66',.7),'Root',True)
    ell('Buckle',(0,.985,-.443),(.18,.18,.035),mat('d79525',.6),'Root')
    for side in [-1,1]:
        spike('Sash bow',(side*.085,.97,-.465),(side*.27,.88,-.49),.075,.025,yellow,'Root')
    # Wider cheek/jaw plane, flatter facial presentation close to the supplied design.
    ell('Face',(0,1.99,-.015),(1.11,1.03,.88),skin,'Head',24,16)
    ell('Jaw',(0,1.74,-.075),(.86,.45,.75),skin,'Head',20,12)
    ell('Dark nape',(0,2.04,.24),(1.07,.71,.60),dark,'Head')
    for side in [-1,1]:
        ell('Ear',(side*.535,1.94,.005),(.18,.26,.18),skin,'Head')
        ell('Eye outline',(side*.232,2.035,-.411),(.358,.422,.086),mat('a23536'),'Head')
        ell('Eye white',(side*.232,2.049,-.440),(.303,.35,.045),white,'Head')
        ell('Blue iris',(side*.217,2.036,-.468),(.193,.274,.031),mat('2851f1'),'Head')
        ell('Pupil',(side*.208,2.037,-.488),(.090,.190,.020),dark,'Head')
        ell('Eye glint',(side*.208-.035,2.11,-.501),(.061,.077,.012),white,'Head',12,8)
        # Expressive arched black brows and rosy cheeks.
        path('Bold eyebrow',[(side*.075,2.29,-.408),(side*.22,2.345,-.412),(side*.37,2.29,-.377)],.047,dark,'Head')
        if not ninja:ell('Cheek mark',(side*.35,1.832,-.385),(.18,.072,.031),mat('e7524d'),'Head')
        spike('Sideburn',(side*.48,2.19,.015),(side*.48,1.72,.045),.18,.23,dark,'Head')
    ell('Button nose',(0,1.91,-.459),(.10,.10,.09),skin,'Head',12,8)
    if not ninja:path('Confident smile',[(-.25,1.82,-.421),(-.15,1.78,-.463),(0,1.79,-.483),(.14,1.82,-.461),(.25,1.85,-.420)],.010,mat('653732'),'Head')
    for side,label in [(-1,'L'),(1,'R')]:
        bone='Arm_'+label
        ell('Upper arm',(side*.51,1.35,0),(.29,.49,.30),skin,bone)
        beam('Bracer',(side*.51,1.07,0),(side*.51,1.31,0),.18,metal,bone,vertices=12)
        for y in [1.075,1.295]:beam('Red cuff',(side*.51,y-.025,0),(side*.51,y+.025,0),.188,red,bone)
        box('Bracer ridge',(side*.51,1.19,-.166),(.15,.19,.03),white,bone,.018)
        ell('Fist',(side*.51,.948,-.025),(.34,.30,.32),skin,bone)
        ell('Thumb',(side*.38,.97,-.125),(.13,.18,.14),skin,bone)
        bone='Leg_'+label
        # Tapered baggy trouser legs, not separate stacked balls.
        verts=[];faces=[]
        for y,rx,rz in [(.93,.235,.225),(.77,.29,.255),(.50,.27,.235),(.30,.17,.15)]:
            for j in range(12):
                a=j*math.tau/12;verts.append((side*.25+math.cos(a)*rx,y,math.sin(a)*rz))
        for r in range(3):
            for j in range(12):faces.append((r*12+j,r*12+(j+1)%12,(r+1)*12+(j+1)%12,(r+1)*12+j))
        faces.extend([tuple(reversed(range(12))),tuple(range(36,48))])
        mesh('Baggy pants',verts,faces,red,bone)
        path('Pants fold',[(side*.36,.82,-.224),(side*.39,.65,-.233),(side*.34,.39,-.17)],.014,mat('c52b24' if not ninja else '273857'),bone)
        beam('Ankle wrap',(side*.25,.17,0),(side*.25,.34,0),.16,red,bone)
        box('Blue sole',(side*.25,.08,-.15),(.41,.12,.67),dark,bone,.06)
        # Individually separated big-toe and outer toe volumes with blue straps.
        ell('Tabi outer',(side*.25+side*.064,.18,-.15),(.29,.21,.60),white,bone)
        ell('Tabi big toe',(side*.25-side*.135,.17,-.30),(.13,.19,.31),white,bone)
        path('Toe strap',[(side*.25-.18,.14,-.35),(side*.25,.255,-.32),(side*.25+.17,.14,-.35)],.023,blue,bone)
        path('Tabi blue strap',[(side*.25-.18,.16,-.16),(side*.25,.30,-.12),(side*.25+.18,.16,-.16)],.023,blue,bone)
    box('Sash tail',(.2,1.04,.65),(.19,.055,.44),yellow,'Sash',.025)
    if ninja:
        ell('Ninja mask',(0,1.82,-.26),(.94,.44,.53),blue,'Head')
        box('Head band',(0,2.27,-.412),(.97,.135,.07),red,'Head',.025)
        box('Band plate',(0,2.27,-.46),(.28,.13,.04),metal,'Head',.018)
        if boss:
            for side in [-1,1]:spike('Guardian crest',(side*.44,2.47,.02),(side*.76,3.04,.02),.17,.17,mat('ffd478',.6))
    skin_mesh=join(objects(),'Skin');palette(skin_mesh)
    meshes=[skin_mesh]
    for golden in ([False] if ninja else [False,True]):
        before=set(objects())
        color=mat('f9c92a',.1,.10) if golden else blue
        shade=mat('c98920',.1) if golden else mat('162a92')
        ell('Hair cap',(0,2.27,.09),(1.16,.78,.97),color,'Head',16,10)
        count=7 if ninja else 11
        for i in range(count):
            a=(i/(count-1))*math.pi*1.40-math.pi*.20
            x=math.cos(a);y=math.sin(a)
            base=(x*.31,2.28+max(-.05,y)*.18,.08)
            tip=(x*(.68 if ninja else 1.02),2.32+max(-.18,y)*( .72 if ninja else (1.16 if golden else 1.03)),.13+.18*math.cos(i*2.7))
            if golden:tip=(tip[0]*.83,tip[1]+.15,.13+.18*math.cos(i*2.7))
            spike('Crown spike',base,tip,.23 if ninja else .29,.23,color if i%3 else shade)
        if not ninja:
            for i in range(5):
                a=(i/4)*math.pi
                base=(math.cos(a)*.31,2.30+math.sin(a)*.20,.34)
                tip=(math.cos(a)*.76,2.45+math.sin(a)*(.81 if golden else .55),.76+math.sin(a)*.22)
                spike('Rear swept spike',base,tip,.27,.25,color if i%2 else shade)
        for side in [-1,1]:
            spike('Framing bang',(side*.22,2.48,-.27),(side*.44,2.19,-.51),.25,.13,color)
        spike('Center fringe',(0,2.50,-.33),(.12,2.25,-.51),.27,.14,color)
        hair=join(list(set(objects())-before),'Hair_Gold' if golden else 'Hair_Normal');palette(hair);meshes.append(hair)
    rig_model(meshes)
    save('enemies' if ninja else 'characters',('guardian_'+str(variant) if boss else 'ninja') if ninja else 'kai')
def pipe():
    global DETAIL
    DETAIL=False
    start();gold=mat('eebe42',.7);rim=mat('ffe38b',.65);dark=mat('603f28')
    beam('Tan handle',(0,0,0),(0,0,-.83),.065,mat('d4a262'),vertices=16)
    beam('Gold collar',(0,0,-.68),(0,0,-.90),.088,gold,vertices=16)
    # Revolved open bowl with inner wall and dark inset floor.
    verts=[];faces=[];profile=[(-.12,.18),(-.06,.23),(.25,.235),(.30,.25),(.32,.21),(.27,.17),(.03,.16)]
    for y,r in profile:
        for i in range(32):
            a=i*math.tau/32;verts.append((math.cos(a)*r,y,-.98+math.sin(a)*r))
    for j in range(len(profile)-1):
        for i in range(32):faces.append((j*32+i,j*32+(i+1)%32,(j+1)*32+(i+1)%32,(j+1)*32+i))
    mesh('Open golden bowl',verts,faces,gold)
    beam('Dark bowl floor',(0,.02,-.98),(0,.026,-.98),.163,dark,vertices=32)
    ring('Lip',(0,.30,-.98),.226,.023,rim)
    ring('Lower ring',(0,-.055,-.98),.218,.014,rim)
    palette(join(objects(),'Golden_Pipe'));save('weapons','golden_pipe')
def coin():
    # Keep the reference koban and its editable source as the authoritative workflow.
    import runpy
    runpy.run_path(str(ROOT/'tools/build_koban.py'))
    stats.extend(e for e in json.loads((ROOT/'assets/models/manifest.json').read_text()) if e['asset']=='weapons/koban')
def tree(kind):
    start();wood=mat('77503c');cherry=kind=='cherry_tree';palm=kind=='palm'
    path('Bent trunk',[(0,0,0),(.12,2,0),(.22,4,.12),(.30,6,.20)],.25 if palm else .36,wood)
    for side in [-1,1]:beam('Root flare',(side*.6,.04,.25),(0,.9,0),.1,wood,r2=.23)
    if not palm:
        for i in range(5):
            a=i*2.4;end=(math.cos(a)*1.6,5.4+i*.19,math.sin(a)*1.5)
            beam('Branch',(.2,3.5,.1),end,.19,wood,r2=.065)
    trunk=join(objects(),'Trunk');palette(trunk)
    before=set(objects())
    if palm:
        for i in range(9):
            a=i*math.tau/9;verts=[];faces=[]
            for j in range(6):
                t=j/5;dist=t*3.45;y=6+math.sin(t*math.pi)*.62-t*.9
                w=math.sin(t*math.pi)*.46+.025
                for side in [-1,0,1]:
                    verts.append((.30+math.cos(a)*dist+math.sin(a)*w*side,y+(.10 if side==0 else 0),.20+math.sin(a)*dist-math.cos(a)*w*side))
            for j in range(5):
                for k in range(2):faces.append((j*3+k,j*3+k+1,(j+1)*3+k+1,(j+1)*3+k))
            o=mesh('Palm frond',verts,faces,mat('4d9d51' if i%2 else '277247'))
            mod=o.modifiers.new('Leaf thickness','SOLIDIFY');mod.thickness=.025
            bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
    else:
        for i in range(5):
            a=i*2.4;center=Vector((math.cos(a)*1.35,5.6+i*.22,math.sin(a)*1.3))
            for j in range(4):
                angle=j*2.4+i
                p=center+Vector((math.cos(angle)*.70,math.sin(j*1.7)*.25,math.sin(angle)*.65))
                bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=cv(p));o=bpy.context.object
                o.scale=(1.65,1.4,.85)
                finish(o,'Blossom cluster' if cherry else 'Leaf crown',mat((['ef8eb2','f7b0c5','de719f'][j%3]) if cherry else (['398452','62a457','498f52'][j%3])))
    canopy=join(list(set(objects())-before),'Canopy');palette(canopy)
    bpy.context.scene.cursor.location=cv((0,5.8,0))
    bpy.context.view_layer.objects.active=canopy
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    save('environments',kind)
def rock():
    start()
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1)
    o=bpy.context.object;o.name='Moss_Rock'
    for v in o.data.vertices:
        v.co*=1+random.uniform(-.12,.12);v.co.z=max(-.35,v.co.z)*.7
    o.data.update()
    o.data.materials.append(mat('839386'));o.data.materials.append(mat('648653'))
    for f in o.data.polygons:f.material_index=1 if f.center.z>.2 else 0
    palette(o);save('environments','moss_rock')
def lantern():
    start();wood=mat('853f2b');paper=mat('ffd597',0,.35)
    ell('Pleated paper',(0,0,0),(.57,.68,.57),paper,None,24,12)
    for j in range(9):ring('Paper rib',(0,-.27+j*.067,0),.275*math.sqrt(max(.1,1-((j-4)/5)**2)),.008,mat('d2a264'))
    for y in [-.34,.34]:beam('Cap',(0,y-.04,0),(0,y+.04,0),.30,wood,vertices=16)
    palette(join(objects(),'Lantern'));save('props','paper_lantern')
def torii():
    start();red=mat('cc4530');dark=mat('233d49');gold=mat('eabb59',.5)
    for side in [-1,1]:
        beam('Pillar',(side*2.88,0,0),(side*2.88,5.4,0),.34,red,vertices=16)
        beam('Stone foot',(side*2.88,0,0),(side*2.88,.6,0),.44,dark,vertices=16)
        ring('Foot collar',(side*2.88,.65,0),.355,.025,gold)
    box('Crossbeam',(0,4.4,0),(7.6,.32,.44),red)
    path('Curved crown',[(-4.9,5.62,0),(-3.8,5.37,0),(0,5.26,0),(3.8,5.37,0),(4.9,5.62,0)],.25,dark)
    box('Dedication',(0,4.80,-.34),(.65,1,.16),gold)
    box('Plaque inset',(0,4.80,-.43),(.42,.68,.025),dark)
    palette(join(objects(),'Torii'));save('architecture','torii')
def roof():
    start();tile=mat('20545e');edge=mat('dbaa58',.4);rib=mat('397881')
    # A 10x10m roof whose normalized size adapts to all established temple tiers.
    N=32;verts=[];faces=[];rings=[]
    for factor,h in [(1,.0),(.78,.32),(.52,1.03),(.22,2.15),(.025,2.8)]:
        ringpoints=[]
        for i in range(N):
            a=i*math.tau/N;x=math.cos(a);z=math.sin(a);den=max(abs(x),abs(z));x/=den;z/=den
            up=.48*abs(x*z) if factor==1 else 0
            ringpoints.append((x*5*factor,h+up,z*5*factor))
        rings.append(ringpoints);verts.extend(ringpoints)
    for r in range(4):
        for i in range(N):faces.append((r*N+i,r*N+(i+1)%N,(r+1)*N+(i+1)%N,(r+1)*N+i))
    o=mesh('Curved tiled roof',verts,faces,tile)
    mod=o.modifiers.new('Roof thickness','SOLIDIFY');mod.thickness=.10
    bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
    path('Gilded eaves',rings[0]+[rings[0][0]],.08,edge)
    for i in range(N):path('Roof tile seam',[r[i] for r in rings],.035,rib)
    beam('Ridge',(-1.6,2.82,0),(1.6,2.82,0),.14,edge)
    palette(join(objects(),'Roof'));save('architecture','temple_roof')
import sys
stats=[]
if '--rock-only' in sys.argv:
    stats=json.loads((ROOT/'assets/models/manifest.json').read_text())
    stats=[item for item in stats if item['asset']!='environments/moss_rock']
    rock()
elif '--coin-only' in sys.argv:
    stats=json.loads((ROOT/'assets/models/manifest.json').read_text())
    stats=[item for item in stats if item['asset']!='weapons/koban']
    coin()
else:
    # The supplied original reference is now authoritative: never overwrite it
    # with the older procedural interpretation during a batch environment rebuild.
    if (ROOT/'assets/references/goemon_original/Goe/goe.obj').exists():
        stats.extend(e for e in json.loads((ROOT/'assets/models/manifest.json').read_text()) if e['asset']=='characters/kai')
    else:
        character()
    character(True)
    for variant in range(4):character(True,True,variant)
    # Supplied weapon is authoritative; environment rebuilds must preserve it.
    if (ROOT/'assets/textures/weapons/goemon_pipe/goemon_m_weapon_001_col.png').exists():
        stats.extend(e for e in json.loads((ROOT/'assets/models/manifest.json').read_text()) if e['asset']=='weapons/golden_pipe')
    else:
        pipe()
    coin()
    for kind in ['cherry_tree','green_tree','palm']:tree(kind)
    rock();lantern();torii();roof()
(ROOT/'assets/models/manifest.json').write_text(json.dumps(stats,indent=2))
print('BLENDER_ASSET_BUILD_COMPLETE',len(stats))
