"""The private ancient-tree assembly retains source pixels/cells and one junction."""
import base64
import hashlib
import json
import struct
import unittest
import zlib
from pathlib import Path

from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
FOLDER=ROOT/'assets/maps/falan/east_region/root_compounds'


class RootCompoundsSource(unittest.TestCase):
    def test_original_core_and_exact_six_layouts(self):
        data=json.loads((FOLDER/'data.json').read_text())
        self.assertEqual(len(data['maps']),6)
        self.assertEqual(len(data['body']['source_pieces']),132)
        self.assertEqual({p['native_graphic'] for p in data['body']['source_pieces']},set(range(4100,4232)))
        catalog=json.loads((ROOT/'assets/maps/original_crossgate/east/catalog.json').read_text())
        for context in data['maps']:
            row=next(r for r in catalog['maps'].values() if r['id']==context['map'])
            encoded=row['reference_variant_raw'] if row.get('active_layout_variant')=='pinned-reference' else row.get('restored_raw',row['raw'])
            raw=zlib.decompress(base64.b64decode(encoded))
            self.assertEqual(hashlib.sha256(raw).hexdigest(),context['source_raw_sha256'])
            width,height=context['size'];self.assertEqual(len(context['exact_bg_core']),132)
            for cell in context['exact_bg_core']:
                x,y=cell['cell'];self.assertEqual(struct.unpack_from('<H',raw,20+(y*width+x)*2)[0],cell['native_graphic'])

    def test_exact_alpha_partition_and_shared_body_crown_junction(self):
        data=json.loads((FOLDER/'data.json').read_text())
        original=Image.open(FOLDER/'native-bg-core.png').convert('RGBA')
        body=Image.open(FOLDER/'body-front.png').convert('RGBA')
        ground=Image.open(FOLDER/'source-ground.png').convert('RGBA')
        inferred=Image.open(FOLDER/'ground-reconstruction.png').convert('RGBA')
        for source,solid,floor,filled in zip(original.getdata(),body.getdata(),ground.getdata(),inferred.getdata()):
            self.assertEqual(source[:3],solid[:3]);self.assertEqual(source[:3],floor[:3])
            self.assertEqual(source[3],solid[3]+floor[3])
            if solid[3]==0:self.assertEqual(source,filled)
        body_point=[a+b for a,b in zip(data['body']['native_origin'],data['prototype']['top_pixel'])]
        crown_point=[a+b for a,b in zip(data['crown']['native_origin'],data['prototype']['crown_junction_pixel'])]
        self.assertEqual(body_point,crown_point)
        self.assertEqual(data['prototype']['ground_native_y']-body_point[1],data['prototype']['height_pixels'])

    def test_crown_wood_leaf_partition_retains_exact_original_pixels(self):
        data=json.loads((FOLDER/'data.json').read_text())['crown']
        original=Image.open(FOLDER/'native-crown.png').convert('RGBA')
        leaves=Image.open(FOLDER/'native-crown-leaves.png').convert('RGBA')
        wood=Image.open(FOLDER/'native-crown-wood.png').convert('RGBA')
        self.assertEqual(hashlib.sha256(original.tobytes()).hexdigest(),data['source_rgba_sha256'])
        self.assertEqual(hashlib.sha256(leaves.tobytes()).hexdigest(),data['leaf_rgba_sha256'])
        self.assertEqual(hashlib.sha256(wood.tobytes()).hexdigest(),data['wood_rgba_sha256'])
        count=0
        for index,(source,leaf,branch) in enumerate(zip(original.getdata(),leaves.getdata(),wood.getdata())):
            self.assertEqual(source[:3],leaf[:3]);self.assertEqual(source[:3],branch[:3]);self.assertEqual(source[3],leaf[3]+branch[3])
            if branch[3]:
                x,y=index%original.width,index//original.width
                self.assertTrue(any(a<=x<c and b<=y<d for a,b,c,d in data['wood_boxes']));count+=1
        self.assertGreater(count,50)

    def test_hidden_bark_uses_only_the_declared_bounded_native_detail(self):
        data=json.loads((FOLDER/'data.json').read_text())
        patch=data['prototype']['bark_patch'];original=Image.open(FOLDER/'native-bg-core.png').convert('RGBA')
        native=original.crop(tuple(patch['box']))
        self.assertEqual(hashlib.sha256(native.tobytes()).hexdigest(),patch['native_rgba_sha256'])
        grain=Image.open(FOLDER/'bark-grain.png').convert('RGBA')
        self.assertEqual(hashlib.sha256(grain.tobytes()).hexdigest(),data['prototype']['bark_rgba_sha256'])
        source_colors={p[:3] for p in native.getdata()}
        self.assertTrue(all(p[:3] in source_colors and p[3]==255 for p in grain.getdata()))
        self.assertEqual(data['combined_reference']['native_origin'],[
            min(data['body']['native_origin'][0],data['crown']['native_origin'][0]),
            min(data['body']['native_origin'][1],data['crown']['native_origin'][1])])


if __name__=='__main__':unittest.main()
