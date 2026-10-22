"""Refit only the editable Samurai scabbard to the enlarged katana."""
from pathlib import Path
import bpy, bmesh, math, json, hashlib, shutil
from mathutils import Vector

OUT = Path(__file__).resolve().parent
TARGET = OUT / 'Samurai_Weapon_Workbench.blend'

def refit():
    blade = bpy.data.objects['Katana_Blade — enlarged maroon steel']
    design = bpy.data.objects['Katana_Design — grip origin + original blade axis']
    root = next(o for o in bpy.data.objects if o.name.startswith('Sheath_ORIGINAL_SIZE') or o.name.startswith('Sheath_MATCHED_SIZE'))
    shell = next(o for o in root.children if o.name.startswith('Sheath_Shell'))
    mouth = next(o for o in root.children if o.name.startswith('Sheath_Mouth'))
    # Work in the blade's canonical +Z frame, then preserve the old sheath's
    # native frame, placement, materials and linked detail-scene copies.
    sections = {}
    for v in blade.data.vertices:
        sections.setdefault(round(v.co.z, 6), []).append(v.co.copy())
    samples = sorted(sections.items())
    def envelope(z):
        if z <= samples[0][0]: points = samples[0][1]
        elif z >= samples[-1][0]: points = samples[-1][1]
        else:
            for (za, a), (zb, b) in zip(samples, samples[1:]):
                if za <= z <= zb:
                    t = (z-za)/(zb-za)
                    # Interpolate the four bounds, including the single tip.
                    return tuple((1-t)*fun(p[j] for p in a)+t*fun(p[j] for p in b)
                                 for j,fun in [(0,min),(0,max),(1,min),(1,max)])
        return (min(p.x for p in points), max(p.x for p in points), min(p.y for p in points), max(p.y for p in points))
    start = .25
    tip = max(v.co.z for v in blade.data.vertices)
    end = tip + .04
    zs = sorted(set([start, .315, .34, tip, end] + [z for z,_ in samples if z > .34]))
    profiles = []
    for z in zs:
        lo,hi,back,front = envelope(z)
        if z <= .315:
            lo,hi,back,front = min(lo,-.073),max(hi,.073),min(back,-.027),max(front,.027)
        # A flat rounded sleeve follows the blade's curve and tapers at its tip.
        cx,cy = (lo+hi)/2,(back+front)/2
        rx,ry = (hi-lo)/2+.012,(front-back)/2+.012
        if z == end: rx,ry = .009,.009
        radius = min(.008,rx*.45,ry*.45)
        profiles.append((z,cx,cy,rx,ry,radius))
    native = design.matrix_local.to_3x3()
    def ring(profile,expand=0):
        z,cx,cy,rx,ry,r = profile
        rx+=expand;ry+=expand
        result=[]
        for sx,sy,angle in [(1,1,0),(-1,1,90),(-1,-1,180),(1,-1,270)]:
            center=Vector((cx+sx*(rx-r),cy+sy*(ry-r),z))
            for offset in [0,45,90]:
                a=math.radians(angle+offset)
                result.append(native @ (center+Vector((r*math.cos(a),r*math.sin(a),0))))
        return result
    def replace(ob, rings, closed_tip):
        verts=[p for profile in rings for p in ring(profile)]
        faces=[];n=12
        for i in range(len(rings)-1):
            for j in range(n):faces.append((i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j))
        if closed_tip:faces.append(tuple((len(rings)-1)*n+j for j in range(n)))
        ob.data.clear_geometry();ob.data.from_pydata(verts,[],faces);ob.data.update()
        bm=bmesh.new();bm.from_mesh(ob.data);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(ob.data);bm.free()
        solid=next(m for m in ob.modifiers if m.type=='SOLIDIFY')
        solid.thickness=.004;solid.offset=1
    replace(shell,profiles,True)
    lip0=profiles[0]
    lip1=(start+.045,)+profiles[0][1:]
    lip=[(p[0],p[1],p[2],p[3]+.006,p[4]+.006,p[5]) for p in [lip0,lip1]]
    replace(mouth,lip,False)
    root.name='Sheath_MATCHED_SIZE — fitted to enlarged katana'
    shell.name='Sheath_Shell — fitted katana profile'
    mouth.name='Sheath_Mouth — fitted dark lip'
    if 'frozen_source_tip_extent' in root:del root['frozen_source_tip_extent']
    root['matched_blade_tip']=tip
    root['internal_tip_clearance']=.04
    root['fitting_profiles']=json.dumps(profiles)
    detail=bpy.data.scenes.get('02 — Katana and unchanged sheath') or bpy.data.scenes.get('02 — Katana and fitted scabbard')
    detail.name='02 — Katana and fitted scabbard'
    detail_root=bpy.data.objects.get('Sheath detail — original size') or bpy.data.objects.get('Sheath detail — fitted scabbard')
    detail_root.name='Sheath detail — fitted scabbard'
    for c in bpy.data.collections:
        if c.name=='Sheath — frozen original size':c.name='Sheath — fitted to enlarged katana'
    bpy.data.scenes['01 — Samurai with maroon katana']['draft_scope']='BLENDER ONLY — maroon katana and matching fitted scabbard. Game files and build are unchanged.'
    return {'blade_tip':tip,'scabbard_mouth':start,'scabbard_tip':end,'tip_clearance':.04,'fitting_profiles':profiles}

if __name__=='__main__':
    backup=OUT.parents[1]/'build/Other Files/Samurai weapon workbench/Before scabbard refit.blend'
    backup.parent.mkdir(parents=True,exist_ok=True)
    if not backup.exists():shutil.copy2(TARGET,backup)
    bpy.ops.wm.open_mainfile(filepath=str(TARGET))
    bpy.context.preferences.filepaths.save_version=0
    def untouched():
        result={}
        for ob in bpy.data.objects:
            if ob.type=='MESH' and 'Sheath' not in ob.name:
                values=([list(v.co) for v in ob.data.vertices],[list(p.vertices) for p in ob.data.polygons],[list(r) for r in ob.matrix_world])
                result[ob.name]=hashlib.sha256(json.dumps(values).encode()).hexdigest()
        return result
    before=untouched()
    report=refit()
    bpy.context.view_layer.update()
    assert before==untouched(),'Unexpected change outside the sheath'
    guide=(OUT/'START_HERE.txt').read_text()
    text=bpy.data.texts['START HERE — Samurai katana draft'];text.clear();text.write(guide)
    bpy.context.window.scene=bpy.data.scenes['01 — Samurai with maroon katana']
    bpy.ops.wm.save_as_mainfile(filepath=str(TARGET))
    report['all_non_sheath_meshes_and_transforms_unchanged']=True
    (OUT/'scabbard-fit.json').write_text(json.dumps(report,indent=2))
    for name,filename in [('01 — Samurai with maroon katana','samurai-preview.png'),('02 — Katana and fitted scabbard','katana-detail.png')]:
        sc=bpy.data.scenes[name];sc.render.filepath=str(OUT/filename);bpy.ops.render.render(write_still=True,scene=sc.name)
    print('SCABBARD_REFIT_COMPLETE',flush=True)
