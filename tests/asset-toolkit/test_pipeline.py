"""Synthetic contracts for real GLB parsing and lossless render batching."""
import copy
import importlib
import json
import math
from pathlib import Path
import struct
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools'))


def fixture(path, animated_mesh=False, skinned=False, differing_clut=False):
    blob = bytearray()
    doc = {'asset': {'version': '2.0'}, 'buffers': [{}], 'bufferViews': [], 'accessors': [],
           'materials': [{'name': 'tpage_24_clut_16918'}, {'name': 'tpage_24_clut_' + ('17046' if differing_clut else '16918') + '.001'}],
           'meshes': [], 'nodes': [], 'scenes': [{'nodes': [0]}], 'scene': 0}
    def add(rows, kind, component=5126):
        while len(blob) % 4: blob.append(0)
        start = len(blob)
        fmt = {5126: 'f', 5123: 'H'}[component]
        for row in rows: blob.extend(struct.pack('<' + fmt * len(row), *row))
        doc['bufferViews'].append({'buffer': 0, 'byteOffset': start, 'byteLength': len(blob)-start})
        doc['accessors'].append({'bufferView': len(doc['bufferViews'])-1, 'componentType': component, 'count': len(rows), 'type': kind})
        return len(doc['accessors'])-1
    pos = add([(0,0,0), (1,0,0), (0,1,0)], 'VEC3')
    norm = add([(0,0,1)]*3, 'VEC3')
    idx = add([(0,), (1,), (2,)], 'SCALAR', 5123)
    attrs = {'POSITION': pos, 'NORMAL': norm}
    if skinned:
        attrs['JOINTS_0'] = add([(0,0,0,0)]*3, 'VEC4', 5123)
        attrs['WEIGHTS_0'] = add([(1,0,0,0)]*3, 'VEC4')
    for i in range(2):
        doc['meshes'].append({'primitives': [{'attributes': dict(attrs), 'indices': idx, 'material': i}]})
    doc['nodes'] = [{'name': 'Root', 'children': [1,2]}, {'name': 'PartA', 'mesh': 0}, {'name': 'PartB', 'mesh': 1}]
    if skinned:
        for node in doc['nodes'][1:]: node['skin'] = 0
        doc['skins'] = [{'joints': [0]}]
    else:
        doc['nodes'][2]['translation'] = [2,0,0]
        doc['nodes'][2]['scale'] = [2,3,1]
    if animated_mesh:
        t = add([(0,), (1,)], 'SCALAR')
        v = add([(0,0,0), (0,1,0)], 'VEC3')
        doc['animations'] = [{'name': 'Move', 'samplers': [{'input': t, 'output': v}], 'channels': [{'sampler': 0, 'target': {'node': 2, 'path': 'translation'}}]}]
    write_glb(path, doc, blob)
    return doc


def write_glb(path, doc, blob):
    doc['buffers'] = [{'byteLength': len(blob)}]
    data = json.dumps(doc).encode()
    data += b' ' * (-len(data) % 4)
    blob = bytes(blob) + b'\0' * (-len(blob) % 4)
    Path(path).write_bytes(struct.pack('<4sII', b'glTF', 2, 28+len(data)+len(blob)) + struct.pack('<II', len(data), 0x4e4f534a) + data + struct.pack('<II', len(blob), 0x004e4942) + blob)


class PipelineTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.source = Path(self.tmp.name) / 'source.glb'
        self.output = Path(self.tmp.name) / 'optimized.glb'

    def test_audit_counts_instanced_geometry_and_material_surfaces(self):
        fixture(self.source)
        audit = importlib.import_module('asset_pipeline.audit')
        row = audit.audit_asset(self.source)
        self.assertEqual((row['triangles'], row['mesh_instances'], row['surfaces']), (2,2,2))
        self.assertEqual(row['duplicate_materials'], 1)

    def test_rejects_truncated_glb(self):
        self.source.write_bytes(b'glTF')
        glb = importlib.import_module('asset_pipeline.glb')
        with self.assertRaisesRegex(ValueError, 'GLB'):
            glb.GLB.read(self.source)

    def test_triangle_strip_count(self):
        fixture(self.source)
        glb = importlib.import_module('asset_pipeline.glb')
        model = glb.GLB.read(self.source)
        for mesh in model.doc['meshes']: mesh['primitives'][0]['mode'] = 5
        model.write(self.source)
        self.assertEqual(importlib.import_module('asset_pipeline.audit').audit_asset(self.source)['triangles'], 2)

    def test_batches_compatible_parts_and_preserves_source(self):
        fixture(self.source)
        original = self.source.read_bytes()
        opt = importlib.import_module('asset_pipeline.optimize')
        result = opt.optimize(self.source, self.output)
        self.assertEqual(self.source.read_bytes(), original)
        self.assertTrue(result['preservation']['passed'])
        self.assertEqual(result['after']['surfaces'], 1)
        self.assertEqual(result['after']['triangles'], 2)
        glb = importlib.import_module('asset_pipeline.glb').GLB.read(self.output)
        pr = glb.doc['meshes'][0]['primitives'][0]
        positions = glb.accessor(pr['attributes']['POSITION'])
        self.assertIn((4.0,0.0,0.0), positions)
        self.assertIn((2.0,3.0,0.0), positions)
        self.assertTrue(all(abs(n[2]-1) < 1e-6 for n in glb.accessor(pr['attributes']['NORMAL'])))

    def test_keeps_directly_animated_mesh_and_animation_bytes(self):
        fixture(self.source, animated_mesh=True)
        opt = importlib.import_module('asset_pipeline.optimize')
        result = opt.optimize(self.source, self.output)
        self.assertTrue(result['preservation']['passed'])
        glb = importlib.import_module('asset_pipeline.glb').GLB
        before, after = glb.read(self.source), glb.read(self.output)
        self.assertIn('mesh', after.doc['nodes'][2])
        self.assertEqual(before.animation_digest(), after.animation_digest())
        self.assertEqual(result['after']['surfaces'], 2)

    def test_keeps_clut_material_bindings_distinct(self):
        fixture(self.source, differing_clut=True)
        result = importlib.import_module('asset_pipeline.optimize').optimize(self.source, self.output)
        self.assertEqual(result['after']['surfaces'], 2)

    def test_skinned_batch_preserves_joint_indices_and_weights(self):
        fixture(self.source, skinned=True)
        result = importlib.import_module('asset_pipeline.optimize').optimize(self.source, self.output)
        self.assertEqual(result['after']['mesh_instances'], 1)
        self.assertEqual(result['after']['surfaces'], 1)
        self.assertTrue(result['preservation']['passed'])
        glb = importlib.import_module('asset_pipeline.glb').GLB.read(self.output)
        pr = glb.doc['meshes'][0]['primitives'][0]
        self.assertTrue(all(row==(0,0,0,0) for row in glb.accessor(pr['attributes']['JOINTS_0'])))
        self.assertTrue(all(row==(1.,0.,0.,0.) for row in glb.accessor(pr['attributes']['WEIGHTS_0'])))

    def test_refuses_overwriting_authored_input(self):
        fixture(self.source)
        with self.assertRaisesRegex(ValueError, 'source'):
            importlib.import_module('asset_pipeline.optimize').optimize(self.source, self.source)

    def test_stale_source_is_rejected_by_manifest_check(self):
        fixture(self.source)
        import hashlib
        cli = importlib.import_module('goemon_assets')
        manifest = {'assets': [{'source': str(self.source), 'output': str(self.output), 'source_sha256': hashlib.sha256(self.source.read_bytes()).hexdigest(), 'output_sha256': 'missing'}]}
        self.source.write_bytes(self.source.read_bytes() + b'changed')
        errors = cli.check_manifest(manifest, Path(self.tmp.name))
        self.assertTrue(any('stale source' in error for error in errors))

    def test_detects_changed_geometry_even_when_counts_match(self):
        fixture(self.source)
        opt = importlib.import_module('asset_pipeline.optimize')
        opt.optimize(self.source,self.output)
        glb = importlib.import_module('asset_pipeline.glb').GLB
        candidate = glb.read(self.output)
        pos = candidate.doc['meshes'][0]['primitives'][0]['attributes']['POSITION']
        accessor = candidate.doc['accessors'][pos]
        view = candidate.doc['bufferViews'][accessor['bufferView']]
        struct.pack_into('<f',candidate.binary,view.get('byteOffset',0),9.0)
        candidate.write(self.output)
        self.assertFalse(opt.validate_preservation(self.source,self.output)['passed'])

    def test_mirrored_transform_preserves_oriented_geometry(self):
        fixture(self.source)
        glb = importlib.import_module('asset_pipeline.glb').GLB
        source = glb.read(self.source)
        source.doc['nodes'][2]['scale'] = [-2,3,1]
        source.write(self.source)
        result = importlib.import_module('asset_pipeline.optimize').optimize(self.source,self.output)
        self.assertTrue(result['preservation']['passed'])

    def test_deduplicates_texture_references_without_changing_image_bytes(self):
        fixture(self.source)
        glb = importlib.import_module('asset_pipeline.glb').GLB
        model = glb.read(self.source)
        offset=len(model.binary);model.binary.extend(b'same-image-payload')
        model.doc['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':18})
        model.doc['images']=[{'bufferView':len(model.doc['bufferViews'])-1,'mimeType':'image/png'}]
        model.doc['textures']=[{'source':0},{'source':0}]
        for i,material in enumerate(model.doc['materials']): material['pbrMetallicRoughness']={'baseColorTexture':{'index':i}}
        model.write(self.source)
        result=importlib.import_module('asset_pipeline.optimize').optimize(self.source,self.output)
        self.assertEqual(result['after']['surfaces'],1)
        self.assertEqual(len(glb.read(self.output).doc['textures']),1)
        self.assertTrue(result['preservation']['passed'])

    def test_audits_glb_outside_project_without_claiming_it_is_unused(self):
        fixture(self.source)
        report=importlib.import_module('asset_pipeline.audit').audit([self.source],project=Path(self.tmp.name)/'another-project')
        self.assertEqual(len(report['assets']),1)
        self.assertEqual(report['errors'],[])
        self.assertIn('outside project',report['assets'][0]['reference_status'])

    def test_preservation_rejects_removed_scene_roots(self):
        fixture(self.source)
        opt=importlib.import_module('asset_pipeline.optimize')
        opt.optimize(self.source,self.output)
        glb=importlib.import_module('asset_pipeline.glb').GLB
        candidate=glb.read(self.output);candidate.doc['scenes'][0]['nodes']=[]
        self.assertFalse(opt.validate_preservation(glb.read(self.source),candidate)['passed'])

    def test_preservation_rejects_new_transform_on_original_node(self):
        fixture(self.source)
        opt=importlib.import_module('asset_pipeline.optimize')
        opt.optimize(self.source,self.output)
        glb=importlib.import_module('asset_pipeline.glb').GLB
        candidate=glb.read(self.output);candidate.doc['nodes'][0]['scale']=[100,100,100]
        self.assertFalse(opt.validate_preservation(glb.read(self.source),candidate)['passed'])

    def test_preservation_rejects_unreachable_generated_mesh_root(self):
        fixture(self.source,skinned=True)
        glb=importlib.import_module('asset_pipeline.glb').GLB
        source=glb.read(self.source);source.doc['nodes'][0].pop('children');source.doc['scenes'][0]['nodes']=[0,1,2];source.write(self.source)
        opt=importlib.import_module('asset_pipeline.optimize');opt.optimize(self.source,self.output)
        candidate=glb.read(self.output)
        candidate.doc['scenes'][0]['nodes']=[i for i in candidate.doc['scenes'][0]['nodes'] if i<len(source.doc['nodes'])]
        self.assertFalse(opt.validate_preservation(source,candidate)['passed'])

    def test_protected_mesh_keeps_its_type_geometry_and_transform(self):
        fixture(self.source)
        result=importlib.import_module('asset_pipeline.optimize').optimize(self.source,self.output,preserve_mesh_nodes='PartA|PartB')
        model=importlib.import_module('asset_pipeline.glb').GLB.read(self.output)
        self.assertIn('mesh',model.doc['nodes'][1]);self.assertIn('mesh',model.doc['nodes'][2])
        self.assertTrue(result['preservation']['passed'])

    def test_material_extension_texture_survives_pruning(self):
        fixture(self.source)
        glb=importlib.import_module('asset_pipeline.glb').GLB
        model=glb.read(self.source);offset=len(model.binary);model.binary.extend(b'image')
        model.doc['bufferViews'].append({'buffer':0,'byteOffset':offset,'byteLength':5})
        model.doc['images']=[{'bufferView':len(model.doc['bufferViews'])-1,'mimeType':'image/png'}];model.doc['textures']=[{'source':0}]
        model.doc['extensionsUsed']=['KHR_materials_specular']
        for mat in model.doc['materials']:mat['extensions']={'KHR_materials_specular':{'specularTexture':{'index':0}}}
        model.write(self.source)
        result=importlib.import_module('asset_pipeline.optimize').optimize(self.source,self.output)
        self.assertTrue(result['preservation']['passed']);self.assertEqual(len(glb.read(self.output).doc['textures']),1)

    def test_zero_scale_animated_mesh_preserves_hidden_rest_pose(self):
        fixture(self.source,animated_mesh=True)
        glb=importlib.import_module('asset_pipeline.glb').GLB
        model=glb.read(self.source);model.doc['nodes'][2]['scale']=[0,0,0];model.write(self.source)
        result=importlib.import_module('asset_pipeline.optimize').optimize(self.source,self.output)
        self.assertTrue(result['preservation']['passed'])

    def test_sparse_vertex_data_survives_optimization(self):
        fixture(self.source)
        glb=importlib.import_module('asset_pipeline.glb').GLB
        model=glb.read(self.source)
        index_offset=len(model.binary);model.binary.extend(struct.pack('<I',1))
        model.doc['bufferViews'].append({'buffer':0,'byteOffset':index_offset,'byteLength':4});indices=len(model.doc['bufferViews'])-1
        value_offset=len(model.binary);model.binary.extend(struct.pack('<fff',2,0,0))
        model.doc['bufferViews'].append({'buffer':0,'byteOffset':value_offset,'byteLength':12});values=len(model.doc['bufferViews'])-1
        model.doc['accessors'][0]['sparse']={'count':1,'indices':{'bufferView':indices,'componentType':5125},'values':{'bufferView':values}}
        model.write(self.source)
        self.assertEqual(glb.read(self.source).accessor(0)[1],(2.,0.,0.))
        result=importlib.import_module('asset_pipeline.optimize').optimize(self.source,self.output)
        self.assertTrue(result['preservation']['passed'])

    def test_welds_only_identical_corner_attributes(self):
        fixture(self.source,skinned=True)
        result=importlib.import_module('asset_pipeline.optimize').optimize(self.source,self.output)
        self.assertEqual(result['after']['vertices'],3)
        self.assertEqual(result['after']['triangles'],2)
        self.assertTrue(result['preservation']['passed'])


if __name__ == '__main__': unittest.main()
