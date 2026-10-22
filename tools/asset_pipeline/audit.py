"""GLB inventory with explicit cost estimates, shared-image hashes and HTML output."""
import collections
import html
import json
from pathlib import Path
import struct

from .glb import GLB, digest, material_key


def image_dimensions(data):
    if data[:8] == b'\x89PNG\r\n\x1a\n' and len(data) >= 24: return struct.unpack_from('>II', data, 16)
    if data[:2] == b'\xff\xd8':
        offset = 2
        while offset+4 <= len(data):
            if data[offset] != 255: break
            marker = data[offset+1]; offset += 2
            if marker in (0xd8, 0xd9): continue
            length = int.from_bytes(data[offset:offset+2], 'big')
            if marker in (0xc0, 0xc1, 0xc2, 0xc3) and offset+7 <= len(data):
                h, w = struct.unpack_from('>HH', data, offset+3); return w, h
            if length < 2: break
            offset += length
    return None


def category(path):
    s = str(path).lower()
    if 'goldmine' in s or 'economy_v1' in s or '/town/' in s: return 'building'
    if '/enemies/' in s: return 'enemy'
    if '/characters/' in s or '/rogue/' in s or path.name == 'musashi.glb': return 'hero'
    if '/environments/' in s or '/edo/' in s or '/architecture/' in s: return 'scenery'
    return 'prop'


def scene_nodes(doc):
    if not doc.get('scenes'): return list(range(len(doc.get('nodes', []))))
    seen, stack = set(), list(doc['scenes'][doc.get('scene', 0)].get('nodes', []))
    while stack:
        i = stack.pop()
        if i in seen: continue
        seen.add(i); stack.extend(doc['nodes'][i].get('children', []))
    return sorted(seen)


def audit_asset(path, budgets=None):
    path = Path(path)
    model = GLB.read(path); doc = model.doc
    instances = [doc['meshes'][doc['nodes'][i]['mesh']] for i in scene_nodes(doc) if 'mesh' in doc['nodes'][i]]
    primitives = [p for m in instances for p in m.get('primitives', [])]
    def triangles(p):
        n = doc['accessors'][p.get('indices', p['attributes']['POSITION'])]['count']
        return n//3 if p.get('mode', 4) == 4 else max(0, n-2) if p.get('mode', 4) in (5,6) else 0
    textures, issues = [], []
    for i, im in enumerate(doc.get('images', [])):
        try:
            data = model.image_bytes(im); dims = image_dimensions(data)
            textures.append({'index': i, 'name': im.get('name', im.get('uri', str(i))), 'sha256': digest(data), 'bytes': len(data), 'dimensions': dims,
                             'rgba8_mip_estimate_bytes': int(dims[0]*dims[1]*4*4/3) if dims else None})
        except (OSError, ValueError) as exc: issues.append('Image %d: %s' % (i, exc))
    materials = {p['material'] for p in primitives if 'material' in p}
    signatures = {model.material_key(i) for i in materials}
    row = {'path': str(path), 'sha256': digest(path.read_bytes()), 'bytes': path.stat().st_size,
           'category': category(path), 'triangles': sum(triangles(p) for p in primitives),
           'vertices': sum(doc['accessors'][p['attributes']['POSITION']]['count'] for p in primitives),
           'mesh_instances': len(instances), 'surfaces': len(primitives), 'materials': len(materials),
           'duplicate_materials': len(materials)-len(signatures), 'textures': textures,
           'texture_rgba8_mip_estimate_bytes': sum(t['rgba8_mip_estimate_bytes'] or 0 for t in {t['sha256']: t for t in textures}.values()),
           'skins': len(doc.get('skins', [])), 'joints': [len(s.get('joints', [])) for s in doc.get('skins', [])],
           'animations': len(doc.get('animations', [])), 'issues': issues}
    if budgets is None: budgets = json.loads(Path(__file__).with_name('budgets.json').read_text())
    budget = budgets.get(row['category'], {})
    for field in ('triangles', 'surfaces'):
        if row[field] > budget.get(field, float('inf')): issues.append('%s %d > budget %d' % (field, row[field], budget[field]))
    if any(max(t['dimensions'] or [0]) > budget.get('texture_edge', float('inf')) for t in textures): issues.append('Texture exceeds category edge budget')
    return row


def audit(paths, budgets=None, project=None):
    rows, errors, hashes = [], [], collections.defaultdict(list)
    references = {}
    if project:
        for folder in ('scripts', 'scenes'):
            for p in (Path(project)/folder).rglob('*'):
                if p.suffix in ('.gd', '.tscn'): references[str(p.relative_to(project))] = p.read_text(errors='replace')
    for path in sorted(set(map(Path, paths))):
        try:
            row = audit_asset(path, budgets)
            if project:
                rel = str(path.resolve().relative_to(Path(project).resolve()))
                row['referenced_by'] = [p for p, text in references.items() if 'res://'+rel in text]
                row['reference_status'] = 'direct reference' if row['referenced_by'] else 'unresolved (may load dynamically)'
            rows.append(row)
            for t in row['textures']: hashes[t['sha256']].append({'asset': str(path), 'image': t['index']})
        except (OSError, ValueError, KeyError, IndexError, struct.error) as exc: errors.append({'path': str(path), 'error': str(exc)})
    return {'assets': rows, 'errors': errors, 'duplicate_images': [{'sha256': h, 'occurrences': v} for h,v in hashes.items() if len(v)>1],
            'notes': ['Surfaces are exported primitives, not measured draw calls.', 'Texture memory assumes RGBA8 plus a full mip chain; engine compression/residency may differ.', 'Budgets are warning thresholds, not automatic reduction targets.', 'Missing direct references do not prove an asset is unused.']}


def write_report(report, output):
    output = Path(output); output.mkdir(parents=True, exist_ok=True)
    (output/'audit.json').write_text(json.dumps(report, indent=2))
    columns = ['path','category','triangles','mesh_instances','surfaces','materials','duplicate_materials','texture_rgba8_mip_estimate_bytes','animations','issues']
    rows = ''.join('<tr>'+''.join('<td>'+html.escape(str(row.get(c,'')))+'</td>' for c in columns)+'</tr>' for row in report['assets'])
    document = '''<!doctype html><meta charset="utf-8"><title>Goemon asset audit</title>
<style>body{font:14px system-ui;background:#182129;color:#e4ebed;margin:28px}input{padding:8px;width:420px}table{border-collapse:collapse;margin-top:18px}th,td{padding:8px;border-bottom:1px solid #40505a;text-align:left}th{cursor:pointer;position:sticky;top:0;background:#26353f}td:first-child{max-width:490px;overflow-wrap:anywhere}</style>
<h1>Goemon asset audit</h1><p>Click columns to sort. Filter by path, category or issue.</p><input id="filter" placeholder="Filter assets"><p>NOTES</p><table><thead><tr>HEADERS</tr></thead><tbody>ROWS</tbody></table><h2>Read errors</h2><pre>ERRORS</pre>
<script>const body=document.querySelector('tbody');document.querySelector('#filter').oninput=e=>{for(const r of body.rows)r.hidden=!r.textContent.toLowerCase().includes(e.target.value.toLowerCase())};for(const [i,h] of [...document.querySelectorAll('th')].entries()){let asc=false;h.onclick=()=>{asc=!asc;for(const r of [...body.rows].sort((a,b)=>a.cells[i].textContent.localeCompare(b.cells[i].textContent,undefined,{numeric:true})*(asc?1:-1)))body.append(r)}};</script>'''
    document = document.replace('NOTES', '<br>'.join(html.escape(s) for s in report['notes'])).replace('HEADERS', ''.join('<th>'+html.escape(c)+'</th>' for c in columns)).replace('ROWS', rows).replace('ERRORS', html.escape(json.dumps(report['errors'],indent=2)))
    (output/'audit.html').write_text(document)
