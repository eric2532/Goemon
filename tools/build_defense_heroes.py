"""Adapt the approved static hero concepts to the existing Goemon rig.

Blender --background --threads 4 --python tools/build_defense_heroes.py -- --only sen
Blender --background --threads 4 --python tools/build_defense_heroes.py -- --all --replace

Existing authored meshes are simplified and rebound, never redesigned. The
source pack and kai.blend remain untouched. Actual gameplay PipeCombo overlays
remain in Godot; these GLBs contain the exact copied Goemon locomotion actions.
"""
import argparse
import bpy
import hashlib
import json
import math
import re
import sys
from pathlib import Path
from mathutils import Vector,Matrix

ROOT=Path(__file__).resolve().parents[1]
PACK=ROOT/'asset_packs/hero_concepts'
SOURCES=ROOT/'assets/blender/defense_heroes'
MODELS=ROOT/'assets/models/defense_heroes'
PORTRAITS=ROOT/'assets/ui/defense_heroes'
EVIDENCE=ROOT/'tests/defense-heroes/art'
for path in [SOURCES,MODELS,PORTRAITS,EVIDENCE]:path.mkdir(parents=True,exist_ok=True)
parser=argparse.ArgumentParser();parser.add_argument('--only');parser.add_argument('--all',action='store_true');parser.add_argument('--replace',action='store_true');parser.add_argument('--skip-render',action='store_true');parser.add_argument('--resume',action='store_true');parser.add_argument('--portraits-only',action='store_true')
ARGS=parser.parse_args(sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [])
IDS=['sen','raku','izumi','gaku','shiro','banji','touma','roan','nagi','kuren']
TITLES=['Sky Ronin','Ember Brawler','Frost Scout','Iron Pilgrim','Moon Duelist','Clockwork Runner','Reed Wanderer','Mountain Striker','Tide Courier','Festival Guard']
SLIM={'izumi','shiro','touma','nagi'}
UPSTREAM='1064214f1f6497a854edd42f11060c40a0bb3ae6'


def smooth(a,b,x):
    f=max(0,min(1,(x-a)/(b-a)));return f*f*(3-2*f)


def lerp_levels(z,levels):
    if z<=levels[0][0]:return z+levels[0][1]-levels[0][0]
    for (a,x),(b,y) in zip(levels,levels[1:]):
        if z<=b:return x+(y-x)*(z-a)/(b-a)
    return z+levels[-1][1]-levels[-1][0]


def original_body_point(p,hero):
    x,y,z=p
    return Vector((x*(1.025 if hero in SLIM else 1.12)*(1+.12*max(0,min(1,(1.2-z)/.8))),y*1.04,z*.85))


def arm_source(hero,sign):
    shoulder=(sign*.46,0,1.67)
    elbow=(sign*.64,.015,1.37)
    wrist=(sign*.69,.065,1.145)
    hand=(sign*.713,.075,.985)
    if sign>0 and hero in {'gaku','touma'}:
        elbow=(.62,.015,1.43);wrist=(.85,.062,1.54);hand=(.91,.075,1.55)
    if sign>0 and hero=='nagi':
        elbow=(.62,.04,1.43);wrist=(.46,.25,1.635);hand=(.43,.28,1.69)
    return [original_body_point(p,hero) for p in [shoulder,elbow,wrist,hand]]


def projection(p,a,b):
    d=b-a;t=(p-a).dot(d)/d.length_squared
    return t,(p-(a+d*max(0,min(1,t)))).length


def arm_map(p,hero,sign,forced_segment=None,cloth_rest=False):
    source=arm_source('sen' if cloth_rest and hero not in SLIM else ('shiro' if cloth_rest else hero),sign)
    targets=[Vector((sign*.406665,0,1.304718)),Vector((sign*.80,0,1.304718)),Vector((sign*1.09,0,1.304718))]
    segment=min(range(2),key=lambda i:projection(p,source[i],source[i+1])[1]) if forced_segment is None else forced_segment
    a,b=source[segment:segment+2];c,d=targets[segment:segment+2]
    axis=(b-a).normalized();along=(p-a).dot(axis);radial=p-a-axis*along
    rotation=axis.rotation_difference((d-c).normalized())
    return c+(d-c)*(along/(b-a).length)+rotation@radial*.86


def classify(name,center):
    text=name.lower()
    if any(word in text for word in ['palm_','curled_finger','thumb_','finger_crease']):return 'hand'
    if 'sleeve' in text or 'armhole_binding' in text:return 'upper_cloth'
    if any(word in text for word in ['arm_anatomy','kimono_sleeve','sleeve_inner','forearm_','bracer_','armhole_binding','brass_wrist']):return 'arm'
    if any(word in text for word in ['sandal','tabi','toe_','foot_','ankle_rope']):return 'foot'
    if any(word in text for word in ['trouser','hakama_pleat','calf_','shin_wrap']):return 'leg'
    if text.startswith('ear_') or any(word in text for word in ['hair','face_','eye_','iris','pupil','brow','nose','nostril','mouth','lower_lip','headband','freckle','forelock','pony','bun_','topknot','hairpin']):return 'head'
    if center.z>1.76 and 'neck' not in text:return 'head'
    return 'body'


def game_materials():
    result={}
    for name,metal,rough in [('organic',0,.76),('cloth',0,.85),('metal',.65,.38),('eyes',0,.25)]:
        m=bpy.data.materials.new('Game '+name);m.use_nodes=True
        p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(1,1,1,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
        vc=m.node_tree.nodes.new('ShaderNodeVertexColor');vc.layer_name='ConceptColor';m.node_tree.links.new(vc.outputs['Color'],p.inputs['Base Color']);result[name]=m
    return result


def material_info(material):
    name=material.name.lower();kind='cloth'
    if any(word in name for word in ['skin','hair','lip','dark','cream','white']):kind='organic'
    if any(word in name for word in ['gold','metal','brass']):kind='metal'
    if any(word in name for word in ['iris','pupil','eye white','catchlight','glint']):kind='eyes'
    color=tuple(material.diffuse_color)
    if material.use_nodes:
        p=material.node_tree.nodes.get('Principled BSDF')
        if p:color=tuple(p.inputs['Base Color'].default_value)
    return kind,color


def simplify_source(hero):
    bpy.ops.wm.open_mainfile(filepath=str(PACK/'blend'/(hero+'.blend')))
    collection=next(c for c in bpy.data.collections if 'editable character' in c.name)
    original=list(collection.objects);kept=[];removed=[]
    for obj in original:
        if obj.type not in {'MESH','CURVE'}:continue
        name=obj.name.split('__')[-1];low=name.lower()
        if 'staff' in low or 'tonfa' in low:
            removed.append(name);continue
        if obj.type=='CURVE':
            if obj.data.bevel_depth<.0055 and not any(w in low for w in ['mouth','lip','lid','brow','moon']):
                removed.append(name);continue
            obj.data.resolution_u=1;obj.data.bevel_resolution=0
        for modifier in obj.modifiers:
            if modifier.type=='SUBSURF':modifier.levels=1 if 'face_sculpt' in low else 0;modifier.render_levels=modifier.levels
        kept.append(obj)
    bpy.context.view_layer.update();graph=bpy.context.evaluated_depsgraph_get();parts=[]
    materials=game_materials();slots=list(materials)
    for obj in kept:
        mesh=bpy.data.meshes.new_from_object(obj.evaluated_get(graph));new=bpy.data.objects.new(obj.name.split('__')[-1],mesh);bpy.context.scene.collection.objects.link(new)
        world=obj.matrix_world.copy()
        for vertex in mesh.vertices:vertex.co=world@vertex.co
        center=sum((v.co for v in mesh.vertices),Vector())/max(1,len(mesh.vertices))
        region=classify(new.name,center);sign=-1 if center.x<0 else 1
        if 'arm_anatomy' in new.name.lower():
            # The authored six-ring arm cage has explicit upper/lower sections.
            # Preserve that semantic parameter through decimation: a folded
            # carry wrist can be closer to shoulder vertices than their own arm.
            assert len(mesh.vertices)%6==0,(new.name,len(mesh.vertices))
            section=mesh.attributes.new(name='SourceArmSection',type='FLOAT',domain='POINT')
            ring_size=len(mesh.vertices)//6
            for vertex,value in zip(mesh.vertices,section.data):value.value=vertex.index//ring_size
        infos=[material_info(m) for m in mesh.materials] or [('organic',(1,1,1,1))]
        colors=mesh.color_attributes.new(name='ConceptColor',type='FLOAT_COLOR',domain='CORNER')
        material_indices=[]
        for polygon in mesh.polygons:
            kind,color=infos[min(polygon.material_index,len(infos)-1)]
            for index in polygon.loop_indices:colors.data[index].color=color
            material_indices.append(slots.index(kind));polygon.use_smooth=True
        mesh.materials.clear()
        for name in slots:mesh.materials.append(materials[name])
        for polygon,index in zip(mesh.polygons,material_indices):polygon.material_index=index
        parts.append((new,region,sign,obj.type=='CURVE'))
    # Original source collection and studio are retained in the upstream pack.
    for obj in list(bpy.context.scene.objects):
        if obj not in [p[0] for p in parts]:bpy.data.objects.remove(obj,do_unlink=True)
    weighted=[]
    for obj,region,sign,curve in parts:
        triangles=sum(len(p.vertices)-2 for p in obj.data.polygons)
        importance=1.0 if 'Face_sculpt' in obj.name else (.48 if region=='head' else .65)
        if curve:importance*=.55
        weighted.append((obj,region,sign,triangles,importance))
    total=sum(t*w for _,_,_,t,w in weighted);factor=min(1,20500/total)
    for obj,region,sign,triangles,importance in weighted:
        ratio=max(min(1,30/max(1,triangles)),min(1,factor*importance))
        if ratio<.99 and triangles>36:
            bpy.context.view_layer.objects.active=obj;mod=obj.modifiers.new('Preserve source silhouette · game reduction','DECIMATE');mod.ratio=ratio;bpy.ops.object.modifier_apply(modifier=mod.name)
    return [(o,r,s) for o,r,s,t,w in weighted],removed


def bind_parts(parts,hero,rig):
    levels=[(0,0),(.16,.185),(.459,.49),(.86,.96583),(1.12,1.095),(1.44,1.304718),(1.56,1.449),(1.72,1.54)]
    for obj,region,sign in parts:
        groups={b.name:obj.vertex_groups.new(name=b.name) for b in rig.data.bones}
        side='L' if sign<0 else 'R'
        for vertex in obj.data.vertices:
            source=vertex.co.copy();x,y,z=source;weights={}
            if region=='head':
                p=Vector((x*.90,y*.90,z-.02));weights={'Head':1}
            elif region=='hand':
                center=arm_source(hero,sign)[3];rotation=Vector((0,0,-1)).rotation_difference(Vector((sign,0,0)))
                p=Vector((sign*1.335,.015,1.285))+rotation@(source-center)*.90;weights={'Hand_'+side:1}
            elif region=='arm':
                section=obj.data.attributes.get('SourceArmSection')
                folded=sign>0 and hero in {'gaku','touma','nagi'}
                forced=(0 if section.data[vertex.index].value<2.5 else 1) if section and folded else (1 if any(word in obj.name.lower() for word in ['forearm_','bracer_','brass_wrist']) else None)
                p=arm_map(source,hero,sign,forced);a=abs(p.x)
                shoulder=smooth(.37,.52,a);elbow=smooth(.74,.86,a);wrist=smooth(1.045,1.15,a)
                weights={'Clavicle_'+side:1-shoulder,'Arm_'+side:shoulder*(1-elbow),'Forearm_'+side:elbow*(1-wrist),'Hand_'+side:wrist}
            elif region=='upper_cloth':
                p=arm_map(source,hero,sign,0,True)
                shoulder=smooth(.37,.52,abs(p.x));weights={'Clavicle_'+side:1-shoulder,'Arm_'+side:shoulder}
            elif region=='foot':
                old_center=original_body_point((sign*.30,0,.15),hero).x
                p=Vector((sign*.315+(x-old_center)*.88,y*.93,max(0,z-.017)));weights={'Foot_'+side:1}
            else:
                p=Vector((x*.85,y*.90,lerp_levels(z,levels)))
                if region=='leg':
                    knee=smooth(.39,.60,p.z);hip=smooth(.80,1.06,p.z)
                    weights={'Shin_'+side:1-knee,'Leg_'+side:knee*(1-hip),'Pelvis':knee*hip}
                else:
                    if p.z<.93:weights={'Pelvis':1}
                    else:
                        anchors=[('Pelvis',.97),('Spine',1.09),('SpineMid',1.23),('Chest',1.38),('Neck',1.51)]
                        weights={anchors[-1][0]:1}
                        for (a,lo),(b,hi) in zip(anchors,anchors[1:]):
                            if p.z<=hi:
                                f=smooth(lo,hi,p.z);weights={a:1-f,b:f};break
            vertex.co=p
            total=sum(weights.values())
            for bone,weight in weights.items():
                if weight>0:groups[bone].add([vertex.index],weight/total,'REPLACE')
    bpy.ops.object.select_all(action='DESELECT')
    for obj,_,_ in parts:obj.select_set(True)
    bpy.context.view_layer.objects.active=parts[0][0];bpy.ops.object.join();mesh=bpy.context.object;mesh.name='Body';mesh.parent=rig;mesh.matrix_parent_inverse=Matrix.Identity(4)
    modifier=mesh.modifiers.new('Exact Goemon skeleton binding','ARMATURE');modifier.object=rig
    return mesh


def load_rig():
    with bpy.data.libraries.load(str(ROOT/'assets/blender/characters/kai.blend'),link=False) as (available,wanted):
        wanted.objects=[name for name in available.objects if name in {'HeroRig','Armature','KaiRig'}]
        if not wanted.objects:
            wanted.objects=list(available.objects)
    imported=[obj for obj in wanted.objects if obj is not None]
    rig=next(obj for obj in imported if obj.type=='ARMATURE')
    bpy.context.scene.collection.objects.link(rig)
    for obj in imported:
        if obj!=rig:bpy.data.objects.remove(obj,do_unlink=True)
    rig.name='GoemonRig';rig.location=(0,0,0);rig.rotation_euler=(0,0,0);rig.scale=(1,1,1)
    rig.animation_data.action=None
    for track in rig.animation_data.nla_tracks:track.mute=True
    for pose in rig.pose.bones:pose.matrix_basis=Matrix.Identity(4)
    return rig


def studio(hero,rig):
    scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=True
    scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA';scene.render.film_transparent=True
    world=bpy.data.worlds.new('Ally portrait studio');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.42,.49,.60,1);world.node_tree.nodes['Background'].inputs[1].default_value=.35;scene.world=world
    for loc,power,size,color in [((3,5,6),650,5,(1,.86,.74)),((-4,2,4),400,4,(.72,.83,1)),((1,-4,5),700,4,(1,.9,.77))]:
        bpy.ops.object.light_add(type='AREA',location=loc);light=bpy.context.object;light.data.energy=power;light.data.size=size;light.data.color=color;light.rotation_euler=(Vector((0,0,1.6))-light.location).to_track_quat('-Z','Y').to_euler()
    bpy.ops.object.camera_add(location=(3.4,8,3.0));camera=bpy.context.object;scene.camera=camera;camera.data.type='ORTHO';camera.data.ortho_scale=3.45
    camera.rotation_euler=(Vector((0,0,1.35))-camera.location).to_track_quat('-Z','Y').to_euler()
    idle=next(t.strips[0].action for t in rig.animation_data.nla_tracks if t.name=='Idle');rig.animation_data.action=idle;scene.frame_set(18)
    scene.render.resolution_x=900;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
    scene.render.filepath=str(EVIDENCE/(hero+'-full.png'))
    return camera


def render_portrait(hero,mesh,camera):
    scene=bpy.context.scene
    camera.location=(2.7,6.5,2.80);aim=Vector((0,0,2.0));camera.rotation_euler=(aim-camera.location).to_track_quat('-Z','Y').to_euler()
    bpy.context.view_layer.update()
    evaluated=mesh.evaluated_get(bpy.context.evaluated_depsgraph_get())
    head_group=mesh.vertex_groups['Head'].index
    inverse=camera.matrix_world.inverted()
    points=[inverse@(mesh.matrix_world@evaluated.data.vertices[v.index].co) for v in mesh.data.vertices if any(g.group==head_group and g.weight>.9 for g in v.groups)]
    xmin=min(p.x for p in points);xmax=max(p.x for p in points);ymin=min(p.y for p in points);ymax=max(p.y for p in points)
    camera.data.ortho_scale=max(1.60,(xmax-xmin)/.80,(ymax-ymin)/.76)
    # Frame the delivered deformed head, with measured 8% top safety margin.
    camera.location+=camera.rotation_euler.to_quaternion()@Vector(((xmin+xmax)*.5,ymax-camera.data.ortho_scale*.42,0))
    scene.render.resolution_x=512;scene.render.resolution_y=512;scene.render.filepath=str(PORTRAITS/(hero+'.png'))
    bpy.ops.render.render(write_still=True)


def build(hero):
    source=SOURCES/(hero+'.blend')
    if source.exists() and not ARGS.replace:raise RuntimeError('Use --replace for an intentional rebuild: '+str(source))
    parts,removed=simplify_source(hero);rig=load_rig();mesh=bind_parts(parts,hero,rig)
    scene=bpy.context.scene;scene.render.fps=60;scene.frame_start=0;scene.frame_end=60
    triangles=sum(len(p.vertices)-2 for p in mesh.data.polygons)
    assert triangles<28000,(hero,triangles)
    clips=[track.name for track in rig.animation_data.nla_tracks]
    for track in rig.animation_data.nla_tracks:track.mute=False
    scene.frame_set(0);bpy.ops.object.select_all(action='DESELECT');rig.select_set(True);mesh.select_set(True);bpy.context.view_layer.objects.active=rig
    bpy.ops.export_scene.gltf(filepath=str(MODELS/(hero+'.glb')),export_format='GLB',use_selection=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_force_sampling=True,export_frame_range=False,export_frame_step=1,export_skins=True,export_def_bones=True,export_cameras=False,export_lights=False)
    for track in rig.animation_data.nla_tracks:track.mute=True
    camera=studio(hero,rig)
    scene['Source']='Existing approved concept at '+UPSTREAM;scene['Rig']='Exact copied Goemon kai.blend rest and actions; runtime uses existing HeroLocomotion/PipeCombo';scene['Source optimization omissions']=json.dumps(removed)
    bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True)
    if not ARGS.skip_render:
        if hero=='sen':bpy.ops.render.render(write_still=True)
        render_portrait(hero,mesh,camera)
    record={'id':hero,'name':hero.title(),'role':TITLES[IDS.index(hero)],'source':str(source.relative_to(ROOT)),'model':str((MODELS/(hero+'.glb')).relative_to(ROOT)),'portrait':str((PORTRAITS/(hero+'.png')).relative_to(ROOT)),'triangles':triangles,'meshes':1,'material_surfaces':len(set(p.material_index for p in mesh.data.polygons)),'bones':len(rig.data.bones),'animations':clips,'upstream_commit':UPSTREAM,'upstream_source_sha256':hashlib.sha256((PACK/'blend'/(hero+'.blend')).read_bytes()).hexdigest(),'model_sha256':hashlib.sha256((MODELS/(hero+'.glb')).read_bytes()).hexdigest(),'removed_static_held_equipment':[name for name in removed if 'staff' in name.lower() or 'tonfa' in name.lower()],'omitted_micro_details':[name for name in removed if 'staff' not in name.lower() and 'tonfa' not in name.lower()],'rig_source':'assets/blender/characters/kai.blend','runtime_attack':'Existing HeroLocomotion + PipeCombo procedural overlay; no replacement attack'}
    (SOURCES/(hero+'.json')).write_text(json.dumps(record,indent=2)+'\n');print('DEFENSE_HERO_READY',hero,triangles,'triangles',len(rig.data.bones),'bones',len(clips),'Goemon clips',flush=True)


selected=[ARGS.only] if ARGS.only else IDS
if ARGS.portraits_only:
    for hero in selected:
        bpy.ops.wm.open_mainfile(filepath=str(SOURCES/(hero+'.blend')))
        render_portrait(hero,bpy.data.objects['Body'],bpy.context.scene.camera)
    sys.exit(0)
if ARGS.resume:selected=[hero for hero in selected if not (SOURCES/(hero+'.json')).exists()]
for hero in selected:
    if hero not in IDS:raise ValueError(hero)
    build(hero)
records=[json.loads((SOURCES/(hero+'.json')).read_text()) for hero in IDS if (SOURCES/(hero+'.json')).exists()]
(SOURCES/'manifest.json').write_text(json.dumps({'upstream_commit':UPSTREAM,'assets':records},indent=2)+'\n')
(SOURCES/'PROVENANCE.md').write_text('# Castle humanoid allies\n\nThese are optimized, rigged adaptations of the existing authored meshes from `feat/hero-concept-models` at `'+UPSTREAM+'`. Originals remain unchanged under `asset_packs/hero_concepts`. No character was redesigned or replaced with a new generated model. Subdivision and microscopic detail were reduced; original material colors were consolidated into up to four vertex-color material surfaces.\n\nEach adapted source contains the actual Goemon armature/rest and its copied animation actions from `assets/blender/characters/kai.blend`. The game reuses `HeroLocomotion` and `PipeCombo` for live attack poses and weapon contacts. Static held staff/tonfa geometry is omitted from the runtime copies; identity clothing, hair and carried accessories remain. The game attaches the existing golden pipe to the animated right hand.\n\nPortraits are Blender renders of the delivered optimized and rigged geometry. Rebuild using `tools/build_defense_heroes.py`; all original sources remain separately editable and preserved.\n')
