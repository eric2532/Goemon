"""Fitted Ranger hat over the approved v2.35 painted anatomy and hair.

Blender -b --python tools/equip_ranger_hat.py
--baseline DIR applies to DIR/assets/blender/rogue/ranger.blend; the default
rebuilds through the native sculptor. style_rogue_roster.py dispatches here too.
Only the three old hood objects are replaced. The face, hair, gear and pivots
are never reshaped; palette UV0 and standard batched export remain native.
"""
import bpy, json, math, sys
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from sculpt_rogue_pilot import make_mesh, hair_clump, world_points, validate_changed, export_batched, validate_export_face_uv

REMOVED = ('Hood back', 'Hood gold woven opening', 'Hood gold woven opening.001')


def snapshot(obj):
    data = dict(type=obj.type, parent=obj.parent.name if obj.parent else None,
                transform=[list(row) for row in obj.matrix_world])
    if obj.type == 'MESH':
        data.update(vertices=[list(p) for p in world_points(obj)],
                    faces=[list(p.vertices) for p in obj.data.polygons],
                    uv=[[list(p.uv) for p in layer.data] for layer in obj.data.uv_layers],
                    materials=[m.name for m in obj.data.materials])
    return data


def lower_edge(a):
    c = math.cos(a)
    return 1.835 + .170 * max(c, 0)**1.4 - .335 * max(-c, 0)**.75


def ring(a, t):
    """Cap encloses the complete upper scalp and nape, plus the fringe roots."""
    c, s = math.cos(a), math.sin(a)
    radius = math.sqrt(max(0, 1-t*t))
    z = lower_edge(a) + (2.255-lower_edge(a))*t
    rear_depth = .245 + .180*math.sin(t*math.pi/2)
    width = .383 + .055*max(-c,0)**.25
    return Vector((width*s*radius - .030*t,
                   (-.385*c if c >= 0 else -rear_depth*c)*radius + .050*t, z))


def brim_ring(a, rise=0):
    c=math.cos(a)
    z=1.935 + .070*max(c,0) - .070*max(-c,0) + rise
    t=(z-lower_edge(a))/(2.255-lower_edge(a))
    return ring(a,t)


def apply_hat():
    head = bpy.data.objects['Head']; coll = head.users_collection[0]
    before = {o.name: snapshot(o) for o in coll.objects if o.type in ['MESH', 'EMPTY']}
    hood = bpy.data.objects['Hood back']
    mat = hood.data.materials[0]
    green = tuple(hood.data.uv_layers.active.data[0].uv)
    gold = tuple(bpy.data.objects['Hood gold woven opening'].data.uv_layers.active.data[0].uv)
    hair = bpy.data.objects['Roster ranger temple 1']
    brown = tuple(hair.data.uv_layers.active.data[0].uv)
    for name in REMOVED: bpy.data.objects.remove(bpy.data.objects[name], do_unlink=True)
    n = 64; verts = []; faces = []
    rows = [0, .18, .38, .58, .76, .90, .97]
    for t in rows:
        verts.extend(ring(j*math.tau/n, t) for j in range(n))
    for k in range(len(rows)-1):
        for j in range(n):
            a=k*n+j; b=k*n+(j+1)%n; faces.append((a,b,b+n,a+n))
    bottom=len(verts); verts.append((0,.055,1.905))
    top=len(verts); verts.append((-.03,.05,2.255))
    for j in range(n):
        faces.extend([(bottom,(j+1)%n,j),((len(rows)-1)*n+j,(len(rows)-1)*n+(j+1)%n,top)])
    make_mesh('Ranger hat full crown and nape',verts,faces,mat,head,coll,green)
    # A thick continuous brim, with an upturned side and rear edge. The front
    # lip sits above the brows and preserves both painted eyes and hair tips.
    verts=[]; faces=[]
    for layer in [-1,1]:
        for outer in [False,True]:
            for j in range(n):
                a=j*math.tau/n; c=math.cos(a); s=math.sin(a)
                p=brim_ring(a)
                if outer:
                    p.x += .077*s
                    p.y += (-.095*c if c>=0 else -.073*c)
                    p.z += .025 + .045*abs(s)**3 + .050*max(-c,0)
                p.z += layer*.010; verts.append(p)
    for j in range(n):
        k=(j+1)%n
        faces.extend([(j,k,n+k,n+j),(2*n+j,3*n+j,3*n+k,2*n+k),
                      (j,2*n+j,2*n+k,k),(n+j,n+k,3*n+k,3*n+j)])
    make_mesh('Ranger hat swept brim',verts,faces,mat,head,coll,green)
    # Narrow chestnut band coordinates with the retained solid hair and gear.
    verts=[]; faces=[]
    for inner in [False,True]:
        for rise in [.015,.065]:
            for j in range(n):
                p=brim_ring(j*math.tau/n,rise); p.x*=1.018 if not inner else 1.005
                p.y*=1.018 if not inner else 1.005; verts.append(p)
    for j in range(n):
        k=(j+1)%n
        faces.extend([(j,k,n+k,n+j),(2*n+j,3*n+j,3*n+k,2*n+k),
                      (j,2*n+j,2*n+k,k),(n+j,n+k,3*n+k,3*n+j)])
    make_mesh('Ranger hat chestnut band',verts,faces,mat,head,coll,brown)
    # One broad stylized feather: a clean Ranger accent without fine strands.
    feather=hair_clump('Ranger hat gold feather',
        [(-.375,.06,1.99),(-.398,.135,2.13),(-.414,.215,2.31),(-.395,.295,2.45)],
        [.020,.058,.037],[.017,.025,.021],mat,gold,head,coll)
    for p in feather.data.polygons: p.use_smooth=False
    bpy.context.view_layer.update()
    changed=[o for o in coll.objects if o.name.startswith('Ranger hat ')]
    checks=validate_changed(changed)
    retained=[o for o in coll.objects if o.name in before]
    assert all(snapshot(o)==before[o.name] for o in retained), 'Unrequested Ranger change'
    path=ROOT/'assets/blender/rogue/ranger.blend'
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(path),compress=True)
    triangles,batches=export_batched('ranger',coll)
    uv=validate_export_face_uv('ranger')
    report_path=ROOT/'assets/rogue/styled/ranger-build.json'
    report=json.loads(report_path.read_text())
    report.update(triangles=triangles,mesh_batches=batches,
        ranger_hat_generator='tools/equip_ranger_hat.py',ranger_hat_revision='full-scalp-coverage',
        ranger_hat_design='Fitted forest-green crown with full rear nape panel, swept brim, chestnut band and one solid gold feather',
        ranger_hat_removed=list(REMOVED),ranger_hat_mesh_checks=checks,
        ranger_hat_unchanged_components=len(retained),ranger_hat_face_geometry_and_uv_invariance=True,
        ranger_hat_hair_invariance=True,ranger_hat_body_and_weapon_geometry_invariance=True,
        ranger_hat_pivot_invariance=True,painted_atlas_changed=False,export_face_uv_check=uv)
    report_path.write_text(json.dumps(report,indent=2)+'\n')
    print('RANGER_HAT_COMPLETE',triangles,batches,flush=True)


def build(baseline=None):
    if baseline: path=Path(baseline)/'assets/blender/rogue/ranger.blend'
    else:
        from sculpt_rogue_roster import build as build_roster
        build_roster('ranger'); path=ROOT/'assets/blender/rogue/ranger.blend'
    bpy.ops.wm.open_mainfile(filepath=str(path)); bpy.context.view_layer.update(); apply_hat()


if __name__=='__main__':
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
    build(args[args.index('--baseline')+1] if '--baseline' in args else None)
