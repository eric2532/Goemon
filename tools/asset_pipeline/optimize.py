"""Lossless parent-space batching; geometry and animation contracts gate publication."""
import collections
import copy
import json
import itertools
import math
from pathlib import Path
import struct
import tempfile

from .audit import audit_asset
from .glb import GLB, digest, texture_slots


def matrix(node):
    if 'matrix' in node:
        a = node['matrix']; return [[a[c*4+r] for c in range(4)] for r in range(4)]
    x,y,z,w = node.get('rotation', [0,0,0,1]); s = node.get('scale', [1,1,1]); t = node.get('translation', [0,0,0])
    r = [[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)], [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)], [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]]
    return [[r[i][j]*s[j] for j in range(3)]+[t[i]] for i in range(3)]+[[0,0,0,1]]


def determinant(m):
    a,b,c = m[0][:3]; d,e,f = m[1][:3]; g,h,i = m[2][:3]
    return a*(e*i-f*h)-b*(d*i-f*g)+c*(d*h-e*g)


def transformed(v, m, semantic):
    if semantic == 'POSITION': return tuple(sum(m[i][j]*v[j] for j in range(3))+m[i][3] for i in range(3))
    a,b,c = m[0][:3]; d,e,f = m[1][:3]; g,h,i = m[2][:3]
    det = determinant(m)
    if abs(det) < 1e-15: raise ValueError('Cannot batch a singular mesh transform')
    if semantic == 'NORMAL':
        cofactor = [[e*i-f*h,f*g-d*i,d*h-e*g], [c*h-b*i,a*i-c*g,b*g-a*h], [b*f-c*e,c*d-a*f,a*e-b*d]]
        out = [sum(cofactor[r][j]*v[j] for j in range(3))/det for r in range(3)]
    else: out = [sum(m[r][j]*v[j] for j in range(3)) for r in range(3)]
    length = math.sqrt(sum(n*n for n in out))
    if length: out = [n/length for n in out]
    return tuple(out)+((v[3]*(-1 if det < 0 else 1),) if semantic == 'TANGENT' else ())


def parents(doc):
    result = {}
    for i,n in enumerate(doc['nodes']):
        for child in n.get('children', []):
            if child in result: raise ValueError('Multi-parent glTF nodes cannot be batched')
            result[child] = i
    return result


def geometry_records(model):
    """Compare oriented corner attributes in their unchanged parent's coordinates."""
    doc = model.doc; parent = parents(doc); corners = []
    for i,n in enumerate(doc['nodes']):
        if 'mesh' not in n: continue
        m = matrix(n)
        for p in doc['meshes'][n['mesh']]['primitives']:
            if p.get('mode',4) != 4: raise ValueError('Preservation check requires triangle lists')
            attrs = {k: model.accessor(v) for k,v in p['attributes'].items()}
            indices = [r[0] for r in model.accessor(p['indices'])] if 'indices' in p else list(range(len(attrs['POSITION'])))
            if len(indices)%3: raise ValueError('Incomplete triangle indices')
            mat = model.material_key(p['material']) if 'material' in p else ''
            for start in range(0,len(indices),3):
                tri = indices[start:start+3]
                if determinant(m) < 0: tri = [tri[0],tri[2],tri[1]]
                values=[]
                for index in tri:
                    vertex=[]
                    for semantic,rows in sorted(attrs.items()):
                        value = transformed(rows[index],m,semantic) if semantic in ('POSITION','NORMAL','TANGENT') else rows[index]
                        vertex.append((semantic,tuple(float(x) for x in value)))
                    values.append(vertex)
                corners.append(((parent.get(i),n.get('skin'),mat,tuple(sorted(attrs))),values))
    return corners


def compare_geometry(before, after, tolerance=1e-5):
    # Numeric matching avoids false failures at decimal-rounding boundaries.
    buckets = collections.defaultdict(list)
    def cell(values):
        position = dict(values[0])['POSITION']
        return tuple(int(math.floor(x*1000)) for x in position)
    for key, values in geometry_records(before): buckets[(key,cell(values))].append(values)
    maximum = 0.0
    for key, values in geometry_records(after):
        location = cell(values); found = False
        for delta in itertools.product((-1,0,1),repeat=3):
            candidates = buckets.get((key,tuple(location[i]+delta[i] for i in range(3))),[])
            for i, original in enumerate(candidates):
                error = max(abs(a-b) for left,right in zip(original,values) for (_,xs),(_,ys) in zip(left,right) for a,b in zip(xs,ys))
                if error <= tolerance:
                    maximum=max(maximum,error);candidates.pop(i);found=True;break
            if found:break
        if not found:return {'passed':False,'max_attribute_error':maximum,'tolerance':tolerance}
    return {'passed':not any(buckets.values()),'max_attribute_error':maximum,'tolerance':tolerance}


def validate_preservation(before, after):
    before = before if isinstance(before,GLB) else GLB.read(before)
    after = after if isinstance(after,GLB) else GLB.read(after)
    b,a = before.doc,after.doc
    node_ok = len(a['nodes']) >= len(b['nodes'])
    for i,n in enumerate(b['nodes']):
        for key,value in n.items():
            if key in ('mesh','skin','children'): continue
            node_ok = node_ok and a['nodes'][i].get(key) == value
        node_ok = node_ok and all(c in a['nodes'][i].get('children',[]) for c in n.get('children',[]))
    def skins(model):
        return [{**s, 'inverseBindMatrices': model.accessor(s['inverseBindMatrices']) if 'inverseBindMatrices' in s else None} for s in model.doc.get('skins',[])]
    geometry = compare_geometry(before,after)
    checks = {'nodes_and_sockets': node_ok, 'skins_and_bind_poses': skins(before)==skins(after),
              'animation_samples': before.animation_digest()==after.animation_digest(),
              'texture_bytes': [digest(before.image_bytes(i)) for i in b.get('images',[])] == [digest(after.image_bytes(i)) for i in a.get('images',[])],
              'oriented_corner_attributes': geometry['passed']}
    return {'passed': all(checks.values()), 'checks': checks, 'geometry': geometry}


def optimize(source, destination):
    source, destination = Path(source).resolve(), Path(destination).resolve()
    if source == destination: raise ValueError('Refusing to overwrite authored source')
    before = GLB.read(source); model = GLB(copy.deepcopy(before.doc), before.binary, source)
    doc = model.doc
    allowed = {'KHR_materials_unlit','KHR_materials_emissive_strength'}
    if set(doc.get('extensionsUsed',[]))-allowed:
        raise ValueError('Optimizer only accepts core geometry plus unlit/emissive materials; decode other extensions first')
    if any('uri' in im for im in doc.get('images',[])):
        raise ValueError('Embed image resources before optimizing into another directory')
    parent = parents(doc)
    animated = {c['target'].get('node') for a in doc.get('animations',[]) for c in a.get('channels',[])}
    texture_canonical, texture_remap = {}, {}
    for i in range(len(doc.get('textures',[]))):
        texture_remap[i] = texture_canonical.setdefault(model.texture_key(i),i)
    for material in doc.get('materials',[]):
        for container,key in texture_slots(material):
            container[key]['index'] = texture_remap[container[key]['index']]
    canonical, remap = {}, {}
    for i,m in enumerate(doc.get('materials',[])):
        remap[i] = canonical.setdefault(model.material_key(i), i)
    groups = collections.defaultdict(list)
    for i,n in enumerate(doc['nodes']):
        if 'mesh' not in n or i in animated: continue
        mesh = doc['meshes'][n['mesh']]
        if mesh.get('weights') or mesh.get('extensions') or any(p.get('targets') or p.get('extensions') or p.get('mode',4)!=4 for p in mesh['primitives']): continue
        if 'skin' in n and matrix(n) != matrix({}): continue
        if abs(determinant(matrix(n))) < 1e-15: continue
        scene_ids = tuple(s for s,scene in enumerate(doc.get('scenes',[])) if i in scene.get('nodes',[]))
        if i not in parent and not scene_ids: continue
        groups[(parent.get(i),n.get('skin'),scene_ids)].append(i)
    for (pivot,skin,scene_ids), node_ids in groups.items():
        if len(node_ids)<2: continue
        surfaces = {}
        for i in node_ids:
            n=doc['nodes'][i]; m=matrix(n)
            for p in doc['meshes'][n['mesh']]['primitives']:
                attrs=p['attributes']; mat=remap[p['material']] if 'material' in p else None
                formats=tuple((k,doc['accessors'][v]['componentType'],doc['accessors'][v]['type'],doc['accessors'][v].get('normalized',False)) for k,v in sorted(attrs.items()))
                key=(mat,formats)
                if key not in surfaces: surfaces[key]={'attributes':{k:[] for k in attrs},'indices':[],'templates':{k:doc['accessors'][v] for k,v in attrs.items()}}
                out=surfaces[key]; offset=len(out['attributes']['POSITION'])
                for semantic,accessor in attrs.items():
                    rows=model.accessor(accessor)
                    if semantic in ('POSITION','NORMAL','TANGENT'):
                        if doc['accessors'][accessor]['componentType'] != 5126: raise ValueError('Decode quantized transforms before batching')
                        rows=[transformed(row,m,semantic) for row in rows]
                    out['attributes'][semantic].extend(rows)
                indices=[r[0] for r in model.accessor(p['indices'])] if 'indices' in p else list(range(len(model.accessor(attrs['POSITION']))))
                if len(indices)%3: raise ValueError('Incomplete triangle primitive')
                if determinant(m)<0:
                    indices=[indices[j+k] for j in range(0,len(indices),3) for k in (0,2,1)]
                out['indices'].extend(index+offset for index in indices)
        primitives=[]
        for (mat,_),out in surfaces.items():
            p={'attributes':{k:model.append_accessor(rows,out['templates'][k]) for k,rows in out['attributes'].items()},
               'indices':model.append_accessor([(i,) for i in out['indices']],{'componentType':5125,'type':'SCALAR'})}
            if mat is not None:p['material']=mat
            primitives.append(p)
        mesh_index=len(doc['meshes']);doc['meshes'].append({'name':'OptimizedBatch_%s'%('Scene' if pivot is None else doc['nodes'][pivot].get('name',pivot)),'primitives':primitives})
        node_index=len(doc['nodes']);node={'name':'AssetBatch_%d'%node_index,'mesh':mesh_index}
        if skin is not None:node['skin']=skin
        doc['nodes'].append(node)
        if pivot is not None:doc['nodes'][pivot].setdefault('children',[]).append(node_index)
        else:
            for s in scene_ids:doc['scenes'][s]['nodes'].append(node_index)
        for i in node_ids:
            del doc['nodes'][i]['mesh'];doc['nodes'][i].pop('skin',None)
    used=sorted({n['mesh'] for n in doc['nodes'] if 'mesh'in n});mesh_map={old:new for new,old in enumerate(used)}
    doc['meshes']=[doc['meshes'][i] for i in used]
    for n in doc['nodes']:
        if 'mesh'in n:n['mesh']=mesh_map[n['mesh']]
    for mesh in doc['meshes']:
        for p in mesh['primitives']:
            if 'material'in p:p['material']=remap[p['material']]
    used=sorted({p['material'] for m in doc['meshes'] for p in m['primitives'] if 'material'in p});material_map={old:new for new,old in enumerate(used)}
    doc['materials']=[doc['materials'][i] for i in used]
    for mesh in doc['meshes']:
        for p in mesh['primitives']:
            if 'material'in p:p['material']=material_map[p['material']]
    model.compact()
    preservation=validate_preservation(before,model)
    if not preservation['passed']:raise ValueError('Preservation validation failed: '+json.dumps(preservation))
    destination.parent.mkdir(parents=True,exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=destination.parent,suffix='.glb',delete=False) as stream: staged=Path(stream.name)
    try:
        model.write(staged)
        if not validate_preservation(before,GLB.read(staged))['passed']:raise ValueError('Written GLB failed preservation validation')
        staged.replace(destination)
    finally:staged.unlink(missing_ok=True)
    return {'source':str(source),'output':str(destination),'source_sha256':digest(source.read_bytes()),'output_sha256':digest(destination.read_bytes()),
            'before':audit_asset(source),'after':audit_asset(destination),'preservation':preservation}
