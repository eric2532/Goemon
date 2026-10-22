"""Reopen every source, render turnarounds, import each GLB and compare counts/bounds."""
import bpy, sys, json, math, hashlib
from pathlib import Path
from mathutils import Vector
R=Path(__file__).resolve().parents[1]
names=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else [p.stem for p in (R/'blend').glob('*.blend')]
def stats(obs):
    deps=bpy.context.evaluated_depsgraph_get();total=0;vertices=0;points=[];bad=[]
    for o in obs:
        if o.type not in ('MESH','CURVE'):continue
        ev=o.evaluated_get(deps);me=ev.to_mesh();me.calc_loop_triangles();total+=len(me.loop_triangles);vertices+=len(me.vertices)
        for v in me.vertices:
            p=ev.matrix_world@v.co
            if not all(math.isfinite(x) for x in p):bad.append(o.name)
            points.append(p)
        ev.to_mesh_clear()
    lo=[min(p[j] for p in points) for j in range(3)];hi=[max(p[j] for p in points) for j in range(3)]
    return dict(objects=len(obs),triangles=total,vertices=vertices,bounds_min=lo,bounds_max=hi,nonfinite_objects=bad)
def camera(view):
    ob=bpy.context.scene.camera
    ob.location={'front':(0,9,2.4),'side':(9,0,2.4),'back':(0,-9,2.4),'import':(3.1,8,2.95)}[view]
    ob.rotation_euler=(Vector((0,0,1.47))-ob.location).to_track_quat('-Z','Y').to_euler()
    bpy.context.view_layer.update()
    inv=ob.matrix_world.inverted();points=[]
    for o in bpy.data.objects:
        if o.type in ('MESH','CURVE') and not 'Ground' in o.name:
            points += [inv@(o.matrix_world@Vector(v)) for v in o.bound_box]
    lo=[min(p[j] for p in points) for j in (0,1)];hi=[max(p[j] for p in points) for j in (0,1)]
    shift=ob.matrix_world.to_quaternion()@Vector(((lo[0]+hi[0])/2,(lo[1]+hi[1])/2,0));ob.location+=shift
    sc=bpy.context.scene;aspect=sc.render.resolution_x/sc.render.resolution_y
    ob.data.ortho_scale=max((hi[1]-lo[1])*1.12,(hi[0]-lo[0])/aspect*1.12)
def render(name,view):
    sc=bpy.context.scene;sc.cycles.samples=24;sc.render.resolution_x=480;sc.render.resolution_y=560;camera(view);sc.render.filepath=str(R/'previews'/f'{name}_{view}.png');bpy.ops.render.render(write_still=True)
for name in names:
    print('VALIDATE_START',name,flush=True)
    bpy.ops.wm.open_mainfile(filepath=str(R/'blend'/f'{name}.blend'))
    col=next(c for c in bpy.data.collections if 'editable character' in c.name);obs=list(col.objects)
    source=stats(obs);assert not source['nonfinite_objects']
    assert not [o for o in obs if o.type=='ARMATURE']
    assert bpy.context.scene.unit_settings.scale_length==1
    packed=[im.name for im in bpy.data.images if im.packed_file];assert len(packed)>=2,(name,packed)
    for material in bpy.data.materials:
        if material.use_nodes:
            for node in material.node_tree.nodes:
                if node.type=='TEX_IMAGE' and node.image:assert node.image.packed_file,(name,node.image.name)
    sc=bpy.context.scene;sc.render.resolution_x=800;sc.render.resolution_y=900;sc.cycles.samples=48;camera('import');sc.render.filepath=str(R/'previews'/f'{name}_three_quarter.png');bpy.ops.render.render(write_still=True)
    for view in ('front','side','back'):render(name,view)
    for o in obs:bpy.data.objects.remove(o,do_unlink=True)
    old=set(bpy.data.objects);bpy.ops.import_scene.gltf(filepath=str(R/'glb'/f'{name}.glb'));new=list(set(bpy.data.objects)-old)
    imported=stats(new);assert not imported['nonfinite_objects']
    # Curves and control cages must survive as actual exported triangles.
    assert imported['triangles']==source['triangles'],(name,source['triangles'],imported['triangles'])
    err=max(abs(a-b) for key in ('bounds_min','bounds_max') for a,b in zip(source[key],imported[key]));assert err<.0001,(name,err)
    assert imported['bounds_min'][2]>-.015,(name,imported['bounds_min'])
    render(name,'import')
    report=dict(character=name,source_sha256=hashlib.sha256((R/'blend'/f'{name}.blend').read_bytes()).hexdigest(),glb_sha256=hashlib.sha256((R/'glb'/f'{name}.glb').read_bytes()).hexdigest(),status='PASS',source=source,glb_reimport=imported,bounds_max_error=err,packed_images=packed,static_unrigged=True,views=['three_quarter','front','side','back','import'])
    (R/'validation'/f'{name}.json').write_text(json.dumps(report,indent=2))
    print('VALIDATE_PASS',name,source['triangles'],flush=True)
