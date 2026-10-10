"""Verify Ranger-only hat scope against the captured latest source and hashes.
Blender -b --python tools/verify_ranger_hat_art.py -- BASELINE_DIR OUTPUT_JSON
"""
import bpy, hashlib, json, math, struct, sys
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree

ROOT=Path(__file__).resolve().parents[1];sys.path.insert(0,str(ROOT/'tools'))
from equip_ranger_hat import REMOVED, snapshot, lower_edge
from sculpt_rogue_pilot import world_points, validate_changed, validate_export_face_uv
args=sys.argv[sys.argv.index('--')+1:];baseline=Path(args[0]);output=Path(args[1])
report={'checks':0,'failures':[],'preserved':{}}
def check(ok,label):
    report['checks']+=1
    if not ok:report['failures'].append(label)
def inspect(path):
    bpy.ops.wm.open_mainfile(filepath=str(path));bpy.context.view_layer.update()
    return {o.name:snapshot(o) for o in bpy.data.objects if o.type in ['MESH','EMPTY']}
before=inspect(baseline/'assets/blender/rogue/ranger.blend')
after=inspect(ROOT/'assets/blender/rogue/ranger.blend')
counts={'pivots':0,'unchanged_meshes':0,'body_and_weapons':0,'painted_faces':0,'hair_meshes':0}
for name,old in before.items():
    if name in REMOVED:check(name not in after,'old hood removed '+name);continue
    check(name in after and old==after[name],'exact source component '+name)
    if old['type']=='EMPTY':counts['pivots']+=1
    else:
        counts['unchanged_meshes']+=1
        if old['parent']!='Head':counts['body_and_weapons']+=1
        if 'face' in name.lower():counts['painted_faces']+=1
        if name.startswith('Roster ranger '):counts['hair_meshes']+=1
hat=[o for o in bpy.data.objects if o.type=='MESH' and o.name.startswith('Ranger hat ')]
report['meshes']=validate_changed(hat);check(len(hat)==4,'four closed hat components')
report['counts']=counts
for o in bpy.data.objects:
    if o.type=='MESH':check([u.name for u in o.data.uv_layers]==['Painted palette'],'source UV0 '+o.name)
report['export_uv']=validate_export_face_uv('ranger')
raw=(ROOT/'assets/rogue/styled/models/ranger.glb').read_bytes()
size=struct.unpack_from('<I',raw,12)[0];doc=json.loads(raw[20:20+size])
check(all('TEXCOORD_1' not in p['attributes'] and 'TEXCOORD_0' in p['attributes'] for m in doc['meshes'] for p in m['primitives']),'GLB single UV0')
def exported_components(path):
    data=path.read_bytes();length=struct.unpack_from('<I',data,12)[0]
    document=json.loads(data[20:20+length]);blob=data[28+length:]
    sizes={5120:1,5121:1,5122:2,5123:2,5125:4,5126:4}
    widths={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT4':16}
    def accessor(index):
        a=document['accessors'][index];v=document['bufferViews'][a['bufferView']]
        item=sizes[a['componentType']]*widths[a['type']]
        offset=v.get('byteOffset',0)+a.get('byteOffset',0);stride=v.get('byteStride',item)
        packed=b''.join(blob[offset+i*stride:offset+i*stride+item] for i in range(a['count']))
        return (a['componentType'],a['type'],a['count'],hashlib.sha256(packed).hexdigest())
    result={}
    for node in document['nodes']:
        if 'mesh' not in node or node.get('name')=='Head_Geometry':continue
        parts=[]
        for primitive in document['meshes'][node['mesh']]['primitives']:
            parts.append((document['materials'][primitive['material']]['name'],
                sorted((name,accessor(index)) for name,index in primitive['attributes'].items()),
                accessor(primitive['indices'])))
        result[node['name']]=sorted(parts)
    return result
old_export=exported_components(baseline/'assets/rogue/styled/models/ranger.glb')
new_export=exported_components(ROOT/'assets/rogue/styled/models/ranger.glb')
for name,geometry in old_export.items():
    check(name in new_export and new_export[name]==geometry,'exact exported body/weapon '+name)
report['exported_unchanged_geometry_batches']=list(old_export)
# Sample the real sculpted scalp outside the deliberately visible forehead/face.
# Cast inward from outside: crown/brim must occlude every radial scalp sample.
crown=bpy.data.objects['Ranger hat full crown and nape']
surface=BVHTree.FromPolygons(world_points(crown),[list(p.vertices) for p in crown.data.polygons])
skull=next(o for o in bpy.data.objects if o.type=='MESH' and o.get('painted_face'))
samples=[];uncovered=[]
for p in world_points(skull):
    a=math.atan2(p.x,-p.y);c=math.cos(a)
    # Above brows at front, upper temple at side, all rear scalp down to nape.
    threshold=1.93+.065*max(c,0)-.385*max(-c,0)**.75
    if p.z<threshold:continue
    direction=Vector((p.x,p.y,0))
    if direction.length<.005:direction=Vector((0,0,1))
    else:direction.normalize()
    hit,normal,index,distance=surface.ray_cast(p+direction*2,-direction,2.001)
    samples.append(list(p))
    if hit is None:uncovered.append(list(p))
report['scalp_coverage']={'sample_count':len(samples),'uncovered_samples':uncovered,
    'method':'Radial occlusion rays against the closed crown, excluding intended forehead and lower jaw'}
check(not uncovered,'complete crown and rear scalp coverage')
for path,old in json.loads((baseline/'sha256.json').read_text()).items():
    if path in ['assets/blender/rogue/ranger.blend','assets/rogue/styled/models/ranger.glb','assets/rogue/styled/portraits/ranger-portrait.png']:continue
    same=hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==old
    report['preserved'][path]=same;check(same,'protected asset '+path)
report['success']=not report['failures'];output.parent.mkdir(parents=True,exist_ok=True)
output.write_text(json.dumps(report,indent=2)+'\n')
print('RANGER_HAT_VERIFY',report['checks'],len(report['failures']),report['scalp_coverage']['sample_count'],flush=True)
print(json.dumps(report['failures'],indent=2));assert report['success'],report['failures']
