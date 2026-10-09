"""Two-character, editable anime anatomy/hair pilot for Fire Siege MVP.

Blender -b --python tools/sculpt_rogue_pilot.py -- magic-swordsman explorer
Optional --baseline DIR opens DIR/assets/blender/rogue/HERO.blend for iteration.
The default rebuilds the tracked original through style_rogue_roster, so no
ignored review/build artifacts are needed to reproduce the shipped models.
"""
import bpy, bmesh, math, json, sys, importlib.util, struct
from pathlib import Path
from mathutils import Vector, Matrix

ROOT = Path(__file__).resolve().parents[1]
PILOTS = ('magic-swordsman', 'explorer')
OUT = ROOT / 'assets/rogue/styled'


def world_points(obj):
    return [obj.matrix_world @ v.co for v in obj.data.vertices]


def finish_mesh(mesh):
    mesh.validate(verbose=False)
    bm = bmesh.new(); bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(mesh); bm.free(); mesh.update()
    for f in mesh.polygons: f.use_smooth = True


def make_mesh(name, verts, faces, material, parent, collection, uv=None):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces); finish_mesh(mesh)
    obj = bpy.data.objects.new(name, mesh); collection.objects.link(obj)
    obj.parent = parent; obj.matrix_parent_inverse = parent.matrix_world.inverted()
    mesh.materials.append(material)
    layer = mesh.uv_layers.new(name='Painted palette')
    if uv:
        for item in layer.data: item.uv = uv
    obj['pilot_design'] = 'MVP anime anatomy and large sculpted hair clumps'
    return obj


def interp(z, keys):
    for (za,va),(zb,vb) in zip(keys,keys[1:]):
        if z <= zb: return va + (vb-va)*max(0,(z-za)/(zb-za))
    return keys[-1][1]


def replace_skull(skull, hero):
    """Single closed skull with convex facial volume and an integrated nose bridge.

    The face is still the approved editable painting. Its UV landmark heights are
    deliberately fitted to the anatomy rather than inherited from an egg sphere.
    """
    soft = hero == 'explorer'
    bottom = 1.455 if soft else 1.435
    top = 2.065
    # z, half width, front surface, rear surface. No global skull scale is used.
    profile = [
        (bottom,.036,-.145,.015),
        (bottom+.018,.087,-.202,.075),
        (1.505,.142 if soft else .132,-.227,.112),
        (1.550,.198 if soft else .181,-.241,.145),
        (1.595,.239 if soft else .216,-.250,.165),
        (1.650,.269 if soft else .253,-.256,.190),
        (1.695,.285 if soft else .279,-.257,.211),
        (1.750,.297 if soft else .302,-.254,.234),
        (1.795,.304 if soft else .309,-.249,.244),
        (1.850,.306,-.251,.255),
        (1.895,.302,-.253,.257),
        (1.940,.285,-.234,.249),
        (1.985,.257,-.207,.221),
        (2.025,.207,-.164,.179),
        (2.052,.135,-.104,.115),
    ]
    # Add rings around the integrated nose bridge/tip for a clean small profile.
    base = profile[:]
    for z in [1.635,1.672,1.712,1.730,1.775,1.825,1.875]:
        vals=[interp(z,[(r[0],r[i]) for r in base]) for i in [1,2,3]]
        profile.append((z,*vals))
    profile.sort()
    segments = 64
    verts=[]; faces=[]
    for z,w,front,back in profile:
        for j in range(segments):
            a=math.tau*j/segments; s=math.sin(a); c=math.cos(a)
            x=w*s
            if c>=0:
                # Add forward volume by anatomical height, with a soft lateral
                # falloff into the unchanged temples. Eyes and lower face no
                # longer read as a flat surface recessed beneath the hair.
                face_depth = interp(z, [
                    (bottom, .009), (1.505, .027), (1.550, .037),
                    (1.595, .038), (1.650, .041), (1.695, .039),
                    (1.750, .043), (1.795, .045), (1.850, .037),
                    (1.895, .023), (1.940, .009), (1.985, .0),
                    (top, .0),
                ])
                envelope = math.exp(-(x/.248)**4) * c**.35
                y = front * c**.38 - face_depth * envelope
                # Broad connected bridge and rounded triangular tip belong to
                # the skull surface; the larger base avoids a narrow beak.
                # A shallow, gently sloped underside avoids a dark bulb above the mouth.
                nose_falloff = .047 if z < 1.682 else .043
                nose = (.044 if soft else .056)*math.exp(-((z-1.682)/nose_falloff)**2)
                bridge = .028*math.exp(-((z-1.744)/.083)**2)
                y -= nose*math.exp(-(x/.065)**2)
                y -= bridge*math.exp(-(x/.055)**2)
                # Keep a small socket transition rather than hollow eye planes.
                orbital = .0035*math.exp(-((abs(x)-.143)/.078)**2)*math.exp(-((z-1.804)/.039)**2)
                y += orbital
                brow = .009*math.exp(-((abs(x)-.130)/.100)**2)*math.exp(-((z-1.865)/.043)**2)
                y -= brow
                # Connect cheek and muzzle volume gradually into mouth and chin.
                cheek = .017*math.exp(-((abs(x)-.175)/.087)**2)*math.exp(-((z-1.711)/.064)**2)
                mouth = .009*math.exp(-(x/.123)**2)*math.exp(-((z-1.569)/.056)**2)
                y -= cheek + mouth
            else: y=back*((-c)**.90)
            verts.append((x,y,z))
    for k in range(len(profile)-1):
        for j in range(segments):
            a=k*segments+j; b=k*segments+(j+1)%segments
            faces.append((a,b,b+segments,a+segments))
    ib=len(verts);verts.append((0,-.066,bottom-.005))
    it=len(verts);verts.append((0,.010,top))
    for j in range(segments):
        faces.append((ib,(j+1)%segments,j))
        a=(len(profile)-1)*segments+j;b=(len(profile)-1)*segments+(j+1)%segments
        faces.append((a,b,it))
    mesh=bpy.data.meshes.new('Pilot coherent cheek jaw nose skull')
    inv=skull.matrix_world.inverted()
    mesh.from_pydata([inv@Vector(p) for p in verts],[],faces)
    for mat in skull.data.materials: mesh.materials.append(mat)
    finish_mesh(mesh);skull.data=mesh
    # All batches must share UV0: glTF/Godot does not use Blender's active UV.
    uv=mesh.uv_layers.new(name='Painted palette')
    tile=7 if soft else 5; column=tile%3; row=tile//3
    def tile_uv(u,v): return ((column+u)/3,(2-row+v)/3)
    landmarks=[(bottom-.005,.04),(1.555,.235),(1.679,.362),(1.802,.562),
               (1.886,.670),(1.975,.835),(top,1.0)]
    for face in mesh.polygons:
        center=skull.matrix_world@face.center
        front_facing=center.y<-.025
        for li in face.loop_indices:
            p=skull.matrix_world@mesh.vertices[mesh.loops[li].vertex_index].co
            # x=.14 corresponds to the painted eye center; mouth corners sit on jaw.
            u=.5+p.x/.570
            v=interp(p.z,landmarks)
            uv.data[li].uv=tile_uv(max(.012,min(.988,u)),max(.015,min(.985,v))) if front_facing else tile_uv(.025,.975)
    skull['painted_face']=True
    skull['head_shape']='Convex anime face, supported eye/brow plane, forward cheek/mouth/chin and broad integrated nose'
    skull['face_uv_bounds']=[-.285,.285,bottom-.005,top]
    skull['pilot_design']='New user-approved coherent anatomy; existing atlas preserved'
    return skull


def hair_clump(name, points, widths, depths, mat, swatch, head, coll):
    """Closed swept lock with a broad face and crest, not a ribbon or cone."""
    pts=[Vector(p) for p in points];verts=[];faces=[];n=8
    for i,(p,w,d) in enumerate(zip(pts[:-1],widths,depths)):
        tangent=(pts[min(i+1,len(pts)-1)]-pts[max(0,i-1)]).normalized()
        # Width follows the screen-plane normal, depth preserves real side volume.
        forward=Vector((0,-1,0))
        wide=tangent.cross(forward)
        if wide.length<.05: wide=Vector((1,0,0))
        wide.normalize(); thick=wide.cross(tangent).normalized()
        for j in range(n):
            a=math.tau*j/n
            verts.append(p+wide*(math.cos(a)*w)+thick*(math.sin(a)*d))
    rings=len(pts)-1
    for k in range(rings-1):
        for j in range(n):
            a=k*n+j;b=k*n+(j+1)%n
            faces.append((a,b,b+n,a+n))
    faces.append(tuple(reversed(range(n))))
    tip=len(verts);verts.append(pts[-1])
    for j in range(n):faces.append(((rings-1)*n+j,(rings-1)*n+(j+1)%n,tip))
    return make_mesh(name,verts,faces,mat,head,coll,swatch)


def hair_cap(hero, mat, swatch, head, coll):
    # Broad fitted cranium underlayer, high front hairline and lower nape.
    verts=[];faces=[];segments=48
    for t in [0,.22,.48,.70,.86]:
        for j in range(segments):
            a=j*math.tau/segments;c=math.cos(a)
            low=1.94 if c>.48 else (1.80 if c>-.25 else 1.68)
            z=low+(2.15-low)*t
            width=interp(z,[(1.60,.295),(1.80,.339),(1.94,.325),(2.05,.265),(2.12,.153),(2.15,.03)])
            front=interp(z,[(1.60,.280),(1.80,.291),(1.94,.282),(2.05,.208),(2.12,.127),(2.15,.03)])
            back=interp(z,[(1.60,.235),(1.80,.294),(1.94,.289),(2.05,.218),(2.12,.135),(2.15,.03)])
            x=width*math.sin(a)
            y=-front*c**.38 if c>=0 else back*(-c)**.9
            verts.append((x,y,z))
    for k in range(4):
        for j in range(segments):
            a=k*segments+j;b=k*segments+(j+1)%segments
            faces.append((a,b,b+segments,a+segments))
    # Close lower cap into the skull; hidden but manifold.
    bot=len(verts);verts.append((0,0,1.84));top=len(verts);verts.append((0,.02,2.15))
    for j in range(segments):
        faces.append((bot,(j+1)%segments,j))
        faces.append((4*segments+j,4*segments+(j+1)%segments,top))
    return make_mesh('Pilot fitted hair crown',verts,faces,mat,head,coll,swatch)


def rebuild_hair(hero, head, coll):
    crown=bpy.data.objects.get('Silver hair crown' if hero=='magic-swordsman' else 'Auburn hair crown')
    mat=crown.data.materials[0];swatch=tuple(crown.data.uv_layers.active.data[0].uv)
    remove=[]
    for o in list(coll.objects):
        if o.type!='MESH' or o.parent!=head:continue
        name=o.name.lower()
        if any(w in name for w in ['hair','fringe','forelock']) and 'braid' not in name:
            remove.append(o.name);bpy.data.objects.remove(o,do_unlink=True)
    hair_cap(hero,mat,swatch,head,coll)
    def lock(name,p,w,d):return hair_clump('Pilot '+name,p,w,d,mat,swatch,head,coll)
    if hero=='magic-swordsman':
        # Swept diagonal silver fringe, three distinct large overlapping locks.
        lock('silver sweeping fringe',[(.16,-.10,2.125),(.10,-.255,2.08),(-.065,-.313,1.992),(-.208,-.305,1.873)], [.128,.143,.103],[.069,.077,.044])
        lock('silver central accent',[(.26,-.09,2.065),(.215,-.255,2.028),(.115,-.327,1.953),(.025,-.329,1.865)], [.106,.106,.058],[.061,.064,.034])
        lock('silver right fringe',[(.215,-.02,2.11),(.30,-.16,2.04),(.32,-.24,1.96),(.278,-.278,1.822)], [.117,.098,.075],[.066,.062,.044])
        # Strong swept crown silhouette, asymmetrical and deliberately directional.
        for i,(tip,start,mid) in enumerate([
            ((-.34,.02,2.31),(.12,.08,2.07),(-.15,.045,2.23)),
            ((-.405,.12,2.205),(.02,.15,2.07),(-.21,.145,2.16)),
            ((.12,.20,2.36),(.13,.05,2.065),(.16,.14,2.22)),
            ((.375,.17,2.265),(.22,.10,2.03),(.34,.13,2.14)),
            ((-.37,.30,2.08),(-.12,.19,1.95),(-.29,.28,2.02)),
            ((.395,.32,2.03),(.16,.19,1.95),(.31,.27,2.0)),
        ]):lock('silver crown lock %02d'%i,[start,mid,tip],[.105,.08],[.083,.061])
        # Long rear sweep keeps the original swordsman's silver-haired identity.
        for i,a in enumerate([-.85,-.42,0,.42,.85]):
            x=math.sin(a)*.27
            lock('silver nape lock %02d'%i,[(x*.65,.15,2.02),(x,.265,1.82),(x*1.12,.32,1.61),(x*1.18,.285,1.445)], [.105,.105,.07],[.075,.07,.045])
        for side in [-1,1]:
            lock('silver temple '+str(side),[(side*.265,-.06,2.0),(side*.316,-.13,1.88),(side*.302,-.175,1.745),(side*.249,-.215,1.601)], [.09,.078,.047],[.065,.053,.027])
    else:
        # Goggles remain at their original pivot/position, and the braid is preserved.
        lock('auburn swept fringe',[(.19,-.19,2.043),(.06,-.307,2.018),(-.128,-.333,1.966),(-.272,-.270,1.83)], [.112,.124,.088],[.060,.064,.042])
        lock('auburn small forelock',[(.26,-.125,2.046),(.25,-.28,2.013),(.192,-.323,1.966),(.12,-.313,1.937)], [.095,.084,.058],[.057,.052,.029])
        for side in [-1,1]:
            lock('auburn cheek framing '+str(side),[(side*.265,-.095,1.965),(side*.319,-.17,1.843),(side*.317,-.18,1.732),(side*.268,-.205,1.592)], [.086,.072,.043],[.053,.047,.026])
            lock('auburn flipped tip '+str(side),[(side*.285,.00,1.93),(side*.33,.045,1.80),(side*.355,.032,1.704),(side*.418,.015,1.714)], [.086,.075,.042],[.055,.051,.029])
        for i,(x,y,z) in enumerate([(-.23,.12,2.225),(.09,.18,2.26),(.29,.22,2.19)]):
            lock('auburn crown sweep %02d'%i,[(x*.6,.07,2.06),(x*.9,y*.8,z-.065),(x,y,z)], [.095,.064],[.067,.044])
    if hero == 'explorer':
        # Move the complete goggle assembly as one unit above/in front of the fringe.
        old_band = bpy.data.objects.get('Leather goggle headband')
        band_mat = old_band.data.materials[0]
        band_uv = tuple(old_band.data.uv_layers.active.data[0].uv)
        for obj in list(coll.objects):
            if obj.type == 'MESH' and obj.parent == head and 'goggle' in obj.name.lower():
                inv = obj.matrix_world.inverted()
                for vert in obj.data.vertices:
                    vert.co = inv @ (obj.matrix_world @ vert.co + Vector((0, -.080, .070)))
        # The old headband was a rigid front strip; replace it with a real fitted
        # wrap that joins the lifted lenses to the sides/back of the hair volume.
        bpy.data.objects.remove(old_band,do_unlink=True)
        verts=[];faces=[];segments=48
        for j in range(segments):
            a=math.tau*j/segments;c=math.cos(a);s=math.sin(a)
            center=Vector((.30*s,(-.34*c if c>=0 else -.26*c),2.105-.11*(1-c)/2))
            outward=Vector((s,-c,0))
            for radial,zoff in [(0,-.028),(.018,-.028),(.018,.028),(0,.028)]:
                verts.append(center+outward*radial+Vector((0,0,zoff)))
        for j in range(segments):
            for k in range(4):
                a=j*4+k;b=j*4+(k+1)%4
                faces.append((a,b,((j+1)%segments)*4+(k+1)%4,((j+1)%segments)*4+k))
        make_mesh('Pilot fitted expedition strap',verts,faces,band_mat,head,coll,band_uv)
    return remove


def validate_changed(objects):
    checks=[]
    for o in objects:
        bm=bmesh.new();bm.from_mesh(o.data)
        boundary=sum(not e.is_manifold for e in bm.edges)
        degenerates=sum(f.calc_area()<1e-10 for f in bm.faces)
        volume=bm.calc_volume(signed=True)
        checks.append({'name':o.name,'nonmanifold_edges':boundary,'degenerate_faces':degenerates,'signed_volume':volume})
        assert boundary==0 and degenerates==0 and volume>0,checks[-1]
        bm.free()
    return checks


def export_batched(hero, coll):
    originals=list(coll.objects);mapping={}
    for o in originals:
        d=o.copy();d.data=o.data.copy() if o.data else None;coll.objects.link(d);mapping[o]=d
    for o,d in mapping.items():
        d.parent=mapping.get(o.parent);d.matrix_parent_inverse=Matrix.Identity(4)
        d.matrix_basis=o.parent.matrix_world.inverted()@o.matrix_world if o.parent else o.matrix_world.copy()
    bpy.context.view_layer.update();groups={}
    for d in mapping.values():
        if d.type=='MESH':groups.setdefault(d.parent,[]).append(d)
    for parent,objects in groups.items():
        bpy.ops.object.select_all(action='DESELECT')
        for o in objects:o.select_set(True)
        bpy.context.view_layer.objects.active=objects[0];bpy.ops.object.join()
        objects[0].name=parent.get('role',parent.name.split('.')[0])+'_Geometry'
    for o in originals:o.name='SOURCE_'+o.name
    for o in list(coll.objects):
        if o not in originals and o.type=='EMPTY':o.name=o.get('role',o.name.split('.')[0])
    bpy.ops.object.select_all(action='DESELECT')
    exported=[o for o in coll.objects if o not in originals]
    for o in exported:o.select_set(True)
    bpy.context.view_layer.objects.active=next(o for o in exported if o.type=='MESH')
    bpy.ops.export_scene.gltf(filepath=str(OUT/'models'/(hero+'.glb')),export_format='GLB',use_selection=True,export_yup=True,export_materials='EXPORT')
    tris=0
    for o in exported:
        if o.type=='MESH':o.data.calc_loop_triangles();tris+=len(o.data.loop_triangles)
    return tris,sum(o.type=='MESH' for o in exported)


def validate_export_face_uv(hero):
    """Check the actual GLB consumed by Godot, not just Blender source layers.

    A joined mesh silently introduced UV1 when the new skull layer had a unique
    name. Godot consequently sampled the constant/missing UV0 and lost the face.
    Require one exported UV set and feature-spanning UV0 on the head face material.
    """
    path=OUT/'models'/(hero+'.glb')
    raw=path.read_bytes(); json_size=struct.unpack_from('<I',raw,12)[0]
    doc=json.loads(raw[20:20+json_size])
    binary_start=20+json_size+8
    node=next(n for n in doc['nodes'] if n.get('name')=='Head_Geometry')
    mesh=doc['meshes'][node['mesh']]
    primitive=next(p for p in mesh['primitives'] if 'Drawn face' in doc['materials'][p['material']]['name'])
    assert 'TEXCOORD_1' not in primitive['attributes'], 'Unexpected second head UV set'
    accessor=doc['accessors'][primitive['attributes']['TEXCOORD_0']]
    assert accessor['componentType']==5126 and accessor['type']=='VEC2'
    view=doc['bufferViews'][accessor['bufferView']]
    offset=binary_start+view.get('byteOffset',0)+accessor.get('byteOffset',0)
    stride=view.get('byteStride',8)
    coords=[struct.unpack_from('<ff',raw,offset+i*stride) for i in range(accessor['count'])]
    unique={(round(u,5),round(v,5)) for u,v in coords}
    xmin=min(u for u,v in coords);xmax=max(u for u,v in coords)
    ymin=min(v for u,v in coords);ymax=max(v for u,v in coords)
    # The complete mapped face covers ~.32 of the 3x3 atlas in each dimension.
    assert len(unique)>400 and xmax-xmin>.28 and ymax-ymin>.28, (hero,len(unique),xmin,xmax,ymin,ymax)
    mat=doc['materials'][primitive['material']]
    assert mat['pbrMetallicRoughness']['baseColorTexture'].get('texCoord',0)==0
    return {'uv_set':0,'distinct_coordinates':len(unique),'u_span':xmax-xmin,
            'v_span':ymax-ymin,'single_head_uv_set':True}


def measure_facial_depth(skull):
    """Record actual mesh landmark depths for subsequent profile comparisons."""
    front=[p for p in world_points(skull) if p.y < 0]
    samples={}
    for name,x,z in [('chin',0,1.505),('mouth',0,1.550),
                     ('lower_cheek',.17,1.650),('upper_cheek',.17,1.750),
                     ('eye_plane',.14,1.795),('brow',.14,1.875),
                     ('nose_tip',0,1.672),('nose_bridge',0,1.750),
                     ('forehead',0,1.895)]:
        point=min(front,key=lambda p:(p.x-x)**2+(p.z-z)**2)
        samples[name]={'x':point.x,'z':point.z,'front_depth':-point.y}
    return samples


def apply_pilot(hero):
    assert hero in PILOTS
    head=bpy.data.objects['Head'];coll=head.users_collection[0]
    pivots={o.name:tuple(tuple(r) for r in o.matrix_world) for o in coll.objects if o.type=='EMPTY'}
    body={o.name:[tuple(p) for p in world_points(o)] for o in coll.objects if o.type=='MESH' and o.parent!=head}
    skull=next(o for o in coll.objects if o.type=='MESH' and o.get('painted_face'))
    replace_skull(skull,hero);removed=rebuild_hair(hero,head,coll)
    bpy.context.view_layer.update()
    changed=[skull]+[o for o in coll.objects if o.type=='MESH' and o.name.startswith('Pilot ')]
    checks=validate_changed(changed)
    depth_profile=measure_facial_depth(skull)
    assert all(tuple(tuple(r) for r in bpy.data.objects[n].matrix_world)==m for n,m in pivots.items())
    assert all([tuple(p) for p in world_points(bpy.data.objects[n])]==points for n,points in body.items())
    source=ROOT/'assets/blender/rogue'/(hero+'.blend')
    bpy.context.preferences.filepaths.save_version=0
    bpy.ops.wm.save_as_mainfile(filepath=str(source),compress=True)
    triangles,batches=export_batched(hero,coll)
    uv_check=validate_export_face_uv(hero)
    report_path=OUT/(hero+'-build.json')
    report=json.loads(report_path.read_text()) if report_path.exists() else {'hero':hero}
    report.update({'triangles':triangles,'mesh_batches':batches,'source':str(source.relative_to(ROOT)),
      'head_shape':'Anime depth refinement: convex face, supported eye plane and broad integrated nose',
      'facial_depth_revision':'2.34.1','facial_depth_profile':depth_profile,
      'hair_shape':'Large closed swept clumps; original class identity and colors',
      'pilot_generator':'tools/sculpt_rogue_pilot.py','painted_atlas_changed':False,
      'export_face_uv_check':uv_check,
      'pivot_invariance':True,'body_and_weapon_geometry_invariance':True,'pilot_mesh_checks':checks})
    report_path.write_text(json.dumps(report,indent=2)+'\n')
    print('ROGUE_PILOT_COMPLETE',hero,triangles,'triangles',batches,'batches',flush=True)


def build(hero, baseline=None):
    if baseline:
        path=Path(baseline)/'assets/blender/rogue'/(hero+'.blend')
    else:
        spec=importlib.util.spec_from_file_location('rogue_base_style',ROOT/'tools/style_rogue_roster.py')
        module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
        module.build(hero)
        path=ROOT/'assets/blender/rogue'/(hero+'.blend')
    bpy.ops.wm.open_mainfile(filepath=str(path));bpy.context.view_layer.update()
    apply_pilot(hero)


if __name__=='__main__':
    args=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else list(PILOTS)
    baseline=None
    if '--baseline' in args:
        i=args.index('--baseline');baseline=args[i+1];del args[i:i+2]
    for hero in args or PILOTS:build(hero,baseline)
