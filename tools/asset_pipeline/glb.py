"""Small GLB reader/writer. No Blender dependency and no source-file mutations."""
import base64
import copy
import hashlib
import json
from pathlib import Path
import re
import struct

FORMATS = {5120: 'b', 5121: 'B', 5122: 'h', 5123: 'H', 5125: 'I', 5126: 'f'}
WIDTHS = {'SCALAR': 1, 'VEC2': 2, 'VEC3': 3, 'VEC4': 4, 'MAT4': 16}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def material_key(material):
    # CLUT ids drive runtime outfit swaps, even when two base pages look alike.
    clut = re.search(r'clut_(\d+)', material.get('name', ''))
    return json.dumps([{k: v for k, v in material.items() if k != 'name'},
                       clut.group(1) if clut else None], sort_keys=True)


def texture_slots(material):
    pbr = material.get('pbrMetallicRoughness', {})
    return [(container,key) for container,keys in ((pbr,('baseColorTexture','metallicRoughnessTexture')), (material,('normalTexture','occlusionTexture','emissiveTexture'))) for key in keys if key in container]


class GLB:
    def __init__(self, doc, binary, path=None):
        self.doc, self.binary, self.path = doc, bytearray(binary), Path(path) if path else None

    @classmethod
    def read(cls, path):
        raw = Path(path).read_bytes()
        if len(raw) < 20:
            raise ValueError('Truncated GLB header: ' + str(path))
        magic, version, length = struct.unpack_from('<4sII', raw)
        if magic != b'glTF' or version != 2 or length != len(raw):
            raise ValueError('Invalid GLB header or declared length: ' + str(path))
        chunks, offset = [], 12
        while offset < len(raw):
            if offset + 8 > len(raw): raise ValueError('Truncated GLB chunk header')
            size, kind = struct.unpack_from('<II', raw, offset)
            offset += 8
            if size % 4 or offset + size > len(raw): raise ValueError('Invalid GLB chunk length')
            chunks.append((kind, raw[offset:offset+size])); offset += size
        if not chunks or chunks[0][0] != 0x4e4f534a: raise ValueError('GLB requires a JSON first chunk')
        doc = json.loads(chunks[0][1])
        binary = next((data for kind, data in chunks[1:] if kind == 0x004e4942), b'')
        if len(doc.get('buffers', [])) > 1 or any('uri' in b for b in doc.get('buffers', [])):
            raise ValueError('GLB external/multiple buffers are unsupported; embed buffers first')
        if doc.get('buffers', [{}])[0].get('byteLength', 0) > len(binary):
            raise ValueError('Truncated GLB binary buffer')
        result = cls(doc, binary, path)
        for view in doc.get('bufferViews', []):
            if view.get('buffer', 0) != 0 or view.get('byteOffset', 0) < 0 or view.get('byteLength', 0) < 0 or view.get('byteOffset', 0)+view.get('byteLength', 0) > len(binary):
                raise ValueError('GLB bufferView outside binary buffer')
        return result

    def write(self, path):
        self.doc['buffers'] = [{'byteLength': len(self.binary)}]
        data = json.dumps(self.doc, separators=(',', ':'), allow_nan=False).encode()
        data += b' ' * (-len(data) % 4)
        blob = bytes(self.binary) + b'\0' * (-len(self.binary) % 4)
        Path(path).write_bytes(struct.pack('<4sII', b'glTF', 2, 28+len(data)+len(blob)) + struct.pack('<II', len(data), 0x4e4f534a) + data + struct.pack('<II', len(blob), 0x004e4942) + blob)

    def accessor(self, index):
        a = self.doc['accessors'][index]
        if 'sparse' in a: raise ValueError('Sparse accessors need expansion before optimization')
        if a['type'] not in WIDTHS or a['componentType'] not in FORMATS:
            raise ValueError('Unsupported GLB accessor format')
        width, fmt = WIDTHS[a['type']], FORMATS[a['componentType']]
        size = struct.calcsize('<' + fmt * width)
        if 'bufferView' not in a: return [tuple(0 for _ in range(width))] * a['count']
        view = self.doc['bufferViews'][a['bufferView']]
        start, stride = a.get('byteOffset', 0), view.get('byteStride', size)
        if start < 0 or stride < size or start + max(0, a['count']-1)*stride + (size if a['count'] else 0) > view['byteLength']:
            raise ValueError('GLB accessor outside bufferView')
        return [struct.unpack_from('<' + fmt*width, self.binary, view.get('byteOffset', 0)+start+i*stride) for i in range(a['count'])]

    def append_accessor(self, rows, template):
        a = {k: template[k] for k in ('componentType', 'type', 'normalized') if k in template}
        while len(self.binary) % 4: self.binary.append(0)
        start = len(self.binary)
        fmt = '<' + FORMATS[a['componentType']] * WIDTHS[a['type']]
        for row in rows: self.binary.extend(struct.pack(fmt, *row))
        self.doc.setdefault('bufferViews', []).append({'buffer': 0, 'byteOffset': start, 'byteLength': len(self.binary)-start})
        a.update(bufferView=len(self.doc['bufferViews'])-1, count=len(rows))
        if rows and a['type'] == 'VEC3' and a['componentType'] == 5126:
            a['min'] = [min(row[i] for row in rows) for i in range(3)]
            a['max'] = [max(row[i] for row in rows) for i in range(3)]
        self.doc.setdefault('accessors', []).append(a)
        return len(self.doc['accessors'])-1

    def image_bytes(self, image):
        if 'bufferView' in image:
            v = self.doc['bufferViews'][image['bufferView']]
            return bytes(self.binary[v.get('byteOffset', 0):v.get('byteOffset', 0)+v['byteLength']])
        uri = image.get('uri', '')
        if uri.startswith('data:'): return base64.b64decode(uri.split(',', 1)[1], validate=True)
        if self.path and uri and '://' not in uri:
            from urllib.parse import unquote
            return (self.path.parent / unquote(uri)).read_bytes()
        raise ValueError('Missing or unsupported image URI')

    def texture_key(self, index):
        texture = copy.deepcopy(self.doc['textures'][index])
        texture.pop('name', None)
        if 'source' in texture:
            texture['source'] = digest(self.image_bytes(self.doc['images'][texture['source']]))
        if 'sampler' in texture:
            texture['sampler'] = {k:v for k,v in self.doc.get('samplers',[])[texture['sampler']].items() if k != 'name'}
        return json.dumps(texture,sort_keys=True)

    def material_key(self, index):
        material = copy.deepcopy(self.doc['materials'][index])
        for container, key in texture_slots(material):
            container[key]['index'] = self.texture_key(container[key]['index'])
        return material_key(material)

    def animation_digest(self):
        clips = []
        for animation in self.doc.get('animations', []):
            clips.append({'name': animation.get('name'), 'channels': animation.get('channels', []),
                          'samplers': [{**s, 'input': self.accessor(s['input']), 'output': self.accessor(s['output'])} for s in animation.get('samplers', [])]})
        return digest(json.dumps(clips, sort_keys=True).encode())

    def compact(self):
        """Keep only reachable mesh/animation/skin accessors and their bufferViews."""
        refs = []
        for mesh in self.doc.get('meshes', []):
            for p in mesh.get('primitives', []):
                refs.extend((p['attributes'], k) for k in p['attributes'])
                if 'indices' in p: refs.append((p, 'indices'))
                for target in p.get('targets', []): refs.extend((target, k) for k in target)
        for animation in self.doc.get('animations', []):
            for s in animation.get('samplers', []): refs.extend([(s, 'input'), (s, 'output')])
        for skin in self.doc.get('skins', []):
            if 'inverseBindMatrices' in skin: refs.append((skin, 'inverseBindMatrices'))
        old_accessors = self.doc.get('accessors', [])
        order = sorted({obj[key] for obj, key in refs})
        mapping = {old: new for new, old in enumerate(order)}
        self.doc['accessors'] = [old_accessors[i] for i in order]
        for obj, key in refs: obj[key] = mapping[obj[key]]
        view_refs = [(a, 'bufferView') for a in self.doc['accessors'] if 'bufferView' in a]
        view_refs += [(im, 'bufferView') for im in self.doc.get('images', []) if 'bufferView' in im]
        if any('sparse' in a for a in self.doc['accessors']): raise ValueError('Sparse accessors cannot be compacted')
        order = sorted({obj[key] for obj, key in view_refs})
        mapping, views, blob = {}, [], bytearray()
        for old in order:
            v = dict(self.doc['bufferViews'][old])
            while len(blob) % 4: blob.append(0)
            offset = v.get('byteOffset', 0)
            data = self.binary[offset:offset+v['byteLength']]
            v.update(buffer=0, byteOffset=len(blob)); blob.extend(data)
            mapping[old] = len(views); views.append(v)
        for obj, key in view_refs: obj[key] = mapping[obj[key]]
        self.doc['bufferViews'], self.binary = views, blob
