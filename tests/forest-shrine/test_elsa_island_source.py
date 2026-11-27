"""Independent native-plane, original-client and CUT-art preservation checks."""
import base64
from collections import deque
from functools import lru_cache
import hashlib
import json
from pathlib import Path
import struct
import statistics
import sys
import unittest
import zlib

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
import recover_elsa_island as recovery


def decode(row,key):
    return zlib.decompress(base64.b64decode(row[key]))


@lru_cache(maxsize=None)
def terrain_geometry(template):
    return json.loads((ROOT/'assets/maps/falan/elsa/scenery/terrain'/template).read_text())


def prepared_terrain(ident):
    row=json.loads((ROOT/f'assets/maps/falan/elsa/scenery/terrain/{ident}.json').read_text())
    return dict(terrain_geometry(row['template']),**row) if 'template' in row else row


class ElsaSourceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.catalog=json.loads((recovery.OUTPUT/'catalog.json').read_text())

    def test_all_pinned_files_and_full_scope(self):
        proofs=json.loads((recovery.SOURCE/'references.json').read_text())
        for proof in proofs:
            self.assertEqual(hashlib.sha256((recovery.SOURCE/proof['file']).read_bytes()).hexdigest(),proof['sha256'],proof['file'])
        scope=json.loads((recovery.REPORT/'scope.json').read_text())
        self.assertEqual(set(scope['maps']),{row['id'] for row in self.catalog['maps'].values()})
        self.assertGreaterEqual(len(scope['island']),74)
        for actor in recovery.npc_rows():
            if actor['map'] not in scope['island'] or not recovery.active_actor(actor) or not recovery.owned_actor(actor,scope):continue
            for target,x,y in recovery.event_warps(actor['script']):
                if 59530<=target<59800:self.assertIn(target,scope['island'],actor['script'])
        self.assertFalse({59521,59522}&set(scope['maps']))

    def test_native_area_music(self):
        import wave
        tracks=json.loads((ROOT/'assets/audio/crossgate/music/provenance.json').read_text())['tracks']
        sounds={213:'cgbgm_d1',214:'cgbgm_d2',216:'cgbgm_d4',218:None,228:'puk2_field1',229:'puk2_mati',230:'puk2_sinden',232:'puk2_haikyo'}
        for row in self.catalog['maps'].values():
            native=struct.unpack_from('>H',(recovery.SOURCE/str(row['id'])).read_bytes(),56)[0]
            self.assertEqual(row['music'],native,row['id'])
            self.assertIn(native,sounds,row['id'])
        config=(recovery.cg.SOURCE/'bgm/bgm.cf').read_text()
        for sound,key in sounds.items():
            line=next(line for line in config.splitlines() if len(line.split())>1 and line.split()[1]==str(sound))
            if key is None:
                self.assertEqual(line.split(),['-1','218','-2']);continue
            record=tracks[key];original=recovery.cg.SOURCE.parent.parent/record['source']
            self.assertIn(key+'.wav',line.lower())
            self.assertEqual(recovery.sha(original.read_bytes()),record['source_sha256'])
            self.assertEqual(recovery.sha((ROOT/'assets/audio/crossgate/music'/f'{key}.mp3').read_bytes()),record['runtime_sha256'])
            with wave.open(str(original)) as audio:
                self.assertEqual(audio.getnframes(),record['decoded_frames'])
                self.assertAlmostEqual(audio.getnframes()/audio.getframerate(),record['duration'])

    def test_original_bytes_native_completion_and_explicit_remap(self):
        for path,row in self.catalog['maps'].items():
            original=decode(row,'raw');completed=decode(row,'completed_raw');runtime=decode(row,'restored_raw')
            client=recovery.client_map(row['id'])
            if client:self.assertEqual(original,client[0],path)
            self.assertEqual(hashlib.sha256(original).hexdigest(),row['sha256'],path)
            width,height=struct.unpack_from('<II',original,12);cells=width*height
            self.assertEqual(completed[20+cells*4:],original[20+cells*4:],path)
            self.assertEqual(runtime[20+cells*4:],original[20+cells*4:],path)
            source=next(recovery.SOURCE.glob(str(row['id'])+'*')).read_bytes()
            self.assertEqual(source[6:8],b'\xff\xff',path)
            values=struct.unpack(f'>{cells*3}H',source[60:])
            native=struct.unpack(f'<{cells*2}H',completed[20:20+cells*4])
            self.assertEqual(native,values[:cells*2],path)
            mapped=struct.unpack(f'<{cells*2}H',runtime[20:20+cells*4])
            remap={int(k):v for k,v in row['art_remap'].items()}
            self.assertEqual(mapped,tuple(remap.get(v,v) for v in native),path)
            bits=decode(row,'walk')
            self.assertEqual([bool(bits[i>>3]&(1<<(i&7))) for i in range(cells)],
                             [v==0 for v in values[cells*2:]],path)

    def test_native_pixels_and_append_only_graphic_ids(self):
        prior=[json.loads((recovery.OUTPUT.parent/name).read_text()) for name in ['catalog.json','university/catalog.json','../falan/sokia/fixed/catalog.json']]
        taken={s for c in prior for s in c['graphics']}
        self.assertFalse(taken&self.catalog['graphics'].keys())
        offset=self.catalog['page_offset']
        for page,name in enumerate(self.catalog['pages']):
            with Image.open(recovery.OUTPUT.parent/name) as source:
                source=source.convert('RGBA')
                for serial,graphic in self.catalog['graphics'].items():
                    if graphic['page']!=page+offset:continue
                    x,y,w,h=graphic['rect'];pixels=source.crop((x,y,x+w,y+h)).tobytes()
                    self.assertEqual(hashlib.sha256(pixels).hexdigest(),graphic['rgba_sha256'],serial)
                    self.assertEqual(graphic['cut'],list(recovery.cut_records(graphic['cut_map'])[graphic['cut_serial']-1000]))

    def test_archived_journey_corridors(self):
        legs=[(59511,(19,19),(19,17)),(59510,(97,32),(96,138)),
              (59500,(108,124),(124,168)),(59501,(224,68),(264,108)),
              (59520,(112,102),(140,104))]
        for ident,start,end in legs:
            w,h,planes=recovery.reference_map(ident);seen={start};queue=deque([start])
            while queue:
                x,y=queue.popleft()
                for cell in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
                    if cell in seen or not(0<=cell[0]<w and 0<=cell[1]<h):continue
                    if planes[2][cell[1]*w+cell[0]]:continue
                    seen.add(cell);queue.append(cell)
            self.assertIn(end,seen,ident)
        w,h,p=recovery.reference_map(59500)
        self.assertNotEqual(p[2][187*w+124],0,'Do not substitute the public-version forest bridge')
        self.assertIn([59500,124,168,59501,224,68],recovery.fixed_warps())
        self.assertIn([59501,264,108,59520,112,102],recovery.fixed_warps())
        stone=(recovery.SOURCE/'EV_tane_Gate_003.txt').read_bytes().decode('gb18030')
        self.assertIn('Warp 0,1500,27,82',stone)

    def test_puk2_scenery_extended_opacity_header(self):
        art,x,y,clip=recovery.scenery_frame(113305)
        self.assertEqual(clip['opacity'],140)
        self.assertEqual(clip['frames'][0],(1615,0,0,0))
        self.assertEqual(art.size,(248,351))

    def test_shared_map_rooms_and_actual_earth_trigger(self):
        scope=json.loads((recovery.REPORT/'scope.json').read_text())
        self.assertEqual(scope['rooms']['59752']['components'],[26])
        self.assertNotIn(59526,scope['external'],'Unrelated chicken rooms must not add Sinmel to island ownership')
        earth=next(a for a in recovery.npc_rows() if a['id']=='802096')
        self.assertEqual(recovery.activation_cells(earth),[(103,65)])
        self.assertTrue(recovery.owned_actor(earth,scope))
        bishop=next(a for a in recovery.npc_rows() if a['id']=='806499')
        self.assertTrue(recovery.owned_actor(bishop,scope))
        self.assertFalse(recovery.actor_components(bishop)&set(scope['rooms']['59716']['components']))
        self.assertEqual(scope['blocked_rooms'][0]['next_map'],59737)
        ownership=json.loads((ROOT/'assets/maps/falan/elsa/ownership.json').read_text())
        room=ownership['59752'];bits=zlib.decompress(base64.b64decode(room['open']));width=room['size'][0]
        for cell,wanted in [((266,208),True),((264,86),False),((104,116),False)]:
            index=cell[1]*width+cell[0]
            self.assertEqual(bool(bits[index>>3]&(1<<(index&7))),wanted,cell)

    def test_prepared_environment_first_frames_preserve_native_art(self):
        folder=ROOT/'assets/maps/falan/elsa/scenery'
        data=json.loads((folder/'data.json').read_text())
        self.assertEqual(len(data['animations']),96)
        for serial,clip in data['animations'].items():
            art,x,y,source=recovery.scenery_frame(int(serial))
            with Image.open(folder/f'{serial}.png') as atlas:
                actual=atlas.convert('RGBA').crop((x-clip['origin'][0],y-clip['origin'][1],
                    x-clip['origin'][0]+art.width,y-clip['origin'][1]+art.height))
                self.assertEqual(actual.tobytes(),art.tobytes(),serial)
            self.assertEqual(clip['duration'],source['duration'],serial)
            self.assertEqual(clip['opacity'],source['opacity'],serial)

    def test_reassembled_objects_keep_each_native_piece_and_position(self):
        folder=ROOT/'assets/maps/falan/elsa/props'
        props=json.loads((folder/'data.json').read_text());checked=set();pages={}
        self.assertEqual(len(props['maps']),95)
        for ident,placements in props['maps'].items():
            for placement in placements:
                group=props['groups'][placement['group']];x,y,w,h=group['rect']
                page=int(group['page'])
                if page not in pages:pages[page]=Image.open(folder/f'atlas-{page}.png').convert('RGBA')
                for serial,cell in zip(placement['pieces'],placement['cells']):
                    art,origin,record=recovery.cut_image(int(ident),serial)
                    token=(placement['group'],tuple(record))
                    if token in checked:continue
                    checked.add(token)
                    u=(cell[0]+cell[1])*32+origin[0]
                    v=(cell[1]-cell[0])*24+origin[1]
                    dx=u-placement['anchor'][0]-group['origin'][0]
                    dy=v-placement['anchor'][1]-group['origin'][1]
                    self.assertGreaterEqual(min(dx,dy),0,token)
                    self.assertLessEqual(dx+art.width,w,token);self.assertLessEqual(dy+art.height,h,token)
                    actual=pages[page].crop((x+dx,y+dy,x+dx+art.width,y+dy+art.height))
                    self.assertEqual(actual.tobytes(),art.tobytes(),token)
        self.assertGreater(len(checked),500)

    def test_architecture_ground_uses_original_open_cells(self):
        props=json.loads((ROOT/'assets/maps/falan/elsa/props/data.json').read_text())
        hall=set()
        for ident,placements in props['maps'].items():
            width,_,planes=recovery.reference_map(int(ident))
            for placement in placements:
                group=props['groups'][placement['group']]
                if placement.get('ground_cells'):
                    self.assertIn(group.get('ground_role'),{'temple landing','temple stairs','spiral stairs','blue floor panel','metal stair opening','metal stairs'})
                    self.assertNotIn(group['master'],[301041,301043,301044,301047,301048,301049,301050,301051,301052,301055,301296],
                                     'Walls, columns, headers, furniture and machinery must not be duplicated onto the floor')
                for x,y in placement.get('ground_cells',[]):
                    self.assertEqual(planes[2][y*width+x],0,(ident,x,y))
                    if ident=='59530':hall.add((x,y))
        self.assertIn((107,94),hall,'The original stair tread cannot be left visually empty')

    def test_banyan_volume_keeps_native_body_and_leaf_paint(self):
        from asset_pipeline.glb import GLB
        props=json.loads((ROOT/'assets/maps/falan/elsa/props/data.json').read_text())
        groups=[g for g in props['groups'].values() if 'banyan' in g];self.assertEqual(len(groups),24)
        self.assertEqual(sum(len(group['banyan']['crowns']) for group in groups),26)
        for group in groups:
            shape=group['banyan'];x,y,w,h=group['rect']
            native=Image.open(ROOT/f"assets/maps/falan/elsa/props/atlas-{group['page']}.png").convert('RGBA').crop((x,y,x+w,y+h))
            body=Image.open(ROOT/shape['body']['path'].removeprefix('res://')).convert('RGBA')
            leaf_mask=Image.open(ROOT/shape['leaf']['path'].removeprefix('res://')).convert('RGBA');leaf=leaf_mask.convert('RGB')
            for role in ['body','body_solid','leaf']:
                image=Image.open(ROOT/shape[role]['path'].removeprefix('res://'))
                self.assertEqual(recovery.sha(image.tobytes()),shape[role]['sha256'])
            selected={(r,g,b) for yy in range(int(h*.65)) for r,g,b,a in native.crop((0,yy,w,yy+1)).getdata() if a and g>r*.95 and g>b*1.15}
            self.assertTrue(selected and set(leaf.getdata())<=selected)
            self.assertEqual(body.crop((0,shape['box'][3],w,h)).tobytes(),native.crop((0,shape['box'][3],w,h)).tobytes(),
                             'Lower trunk, hanging roots, fruit, crystals and ground art must remain original')
            for yy in range(int(h*.65)):
                for xx in range(w):
                    r,g,b,a=native.getpixel((xx,yy))
                    if a and g>r*.95 and g>b*1.15:
                        self.assertEqual(leaf.getpixel((xx,yy)),(r,g,b));self.assertEqual(body.getpixel((xx,yy))[3],0)
                        self.assertEqual(leaf_mask.getpixel((xx,yy))[3],a)
                    else:
                        self.assertEqual(body.getpixel((xx,yy)),native.getpixel((xx,yy)),'Keep native branches and special features')
                        self.assertEqual(leaf_mask.getpixel((xx,yy))[3],0)
            model=ROOT/shape['model'].removeprefix('res://');glb=GLB.read(model)
            self.assertEqual(recovery.sha(model.read_bytes()),shape['model_sha256']);count=0
            for mesh in glb.doc['meshes']:
                if mesh['name']!='Canopy':continue
                for part in mesh['primitives']:
                    indices=[row[0] for row in glb.accessor(part['indices'])]
                    self.assertEqual(len(indices)%6,0)
                    for i in range(0,len(indices),6):self.assertEqual(len(set(indices[i:i+6])),4)
                    self.assertEqual(len(set(indices)),len(indices)//6*4,'Keep independent reusable leaf quads')
                    count+=len(indices)//6
            for crown in shape['crowns']:
                self.assertEqual(len(crown['points']),count)
                cx,cy=crown['center'];foot=shape['body_parts'][crown['part']]['foot'];ou,ov=group['origin']
                cu,cv=ou+cx,ov+cy;ground=foot[0]*cu+foot[1];vertical=(2*((32/3)**2-8**2))**.5;projection_size=2*(32/3)**2
                for x,y,depth in crown['points']:
                    self.assertGreater(leaf_mask.getpixel((x,y))[3],0,'Every leaf center belongs to the native crown')
                    self.assertLessEqual(abs(depth),w*.225)
                    du,dv=x-cx,y-cy
                    px=cu*3/64-ground/16+du*3/64-dv*8/projection_size-depth/16
                    pz=cu*3/64+ground/16+du*3/64+dv*8/projection_size+depth/16
                    py=(ground-cv)/vertical-dv*vertical/projection_size+depth/vertical
                    self.assertAlmostEqual((px+pz)*32/3,ou+x)
                    self.assertAlmostEqual((pz-px)*8-py*vertical,ov+y,msg='Crown volume must retain the native projection')

    def test_banyan_solid_trunk_uses_native_wood_and_blocked_root_pattern(self):
        props=json.loads((ROOT/'assets/maps/falan/elsa/props/data.json').read_text())
        pairs=[(key,g) for key,g in props['groups'].items() if g.get('banyan',{}).get('trunks')]
        self.assertEqual(len(pairs),1)
        key,group=pairs[0];shape=group['banyan'];trunk=shape['trunks'][0]
        self.assertEqual((group['master'],group['origin'],group['size']),(300843,[-320,-240],[320,432]))
        x,y,w,h=group['rect'];native=Image.open(ROOT/f"assets/maps/falan/elsa/props/atlas-{group['page']}.png").convert('RGBA').crop((x,y,x+w,y+h))
        bark=Image.open(ROOT/trunk['bark']['path'].removeprefix('res://')).convert('RGB')
        self.assertEqual(recovery.sha(bark.tobytes()),trunk['bark']['sha256'])
        body=Image.open(ROOT/shape['body']['path'].removeprefix('res://')).convert('RGBA')
        palette={rgb[:3] for rgb in body.getdata() if rgb[3]}
        self.assertTrue(set(bark.getdata())<=palette,'Solid bark must use this original tree, retaining moss, purple and ochre wood')
        for original,prepared in zip(body.getdata(),bark.getdata()):
            if original[3]:self.assertEqual(original[:3],prepared)
        self.assertEqual(len(trunk['toes']),4)
        for toe in trunk['toes']:
            self.assertGreater(native.getpixel(tuple(toe['pixel']))[3],0)
            self.assertLess(toe['model'][1],.1)
        self.assertEqual(trunk['root_pixel'],[163,327]);self.assertEqual(trunk['root_cells'],[3,3])
        self.assertEqual(shape['body_parts'][trunk['part']]['foot'],[0,87])
        place=next(row for row in props['maps']['59501'] if row['group']==key)
        u=place['anchor'][0]+group['origin'][0]+trunk['root_pixel'][0];v=place['anchor'][1]+group['origin'][1]+trunk['root_pixel'][1]
        center=(round(u/64-v/48),round(u/64+v/48));self.assertEqual(center,(173,48))
        width,_,planes=recovery.reference_map(59501)
        self.assertTrue(all(planes[2][(center[1]+dy)*width+center[0]+dx]&256 for dy in [-1,0,1] for dx in [-1,0,1]))
        self.assertLess(trunk['top'][1],trunk['root_pixel'][1]-60)
        self.assertGreater(trunk['top'][2],30)

    def test_torn_space_wall_planes_follow_native_feet(self):
        props=json.loads((ROOT/'assets/maps/falan/elsa/props/data.json').read_text())
        checked=0
        for group in props['groups'].values():
            if group['master'] not in [301295,301296] or group.get('ground_role'):continue
            shapes=group.get('wall_parts',[dict(box=[0,0,*group['size']],foot=group.get('wall',{}).get('foot'))])
            x,y,w,h=group['rect'];page=Image.open(ROOT/f"assets/maps/falan/elsa/props/atlas-{group['page']}.png").convert('RGBA')
            alpha=page.crop((x,y,x+w,y+h)).getchannel('A');pixels=alpha.load();ox,oy=group['origin']
            for shape in shapes:
                self.assertIsNotNone(shape['foot'],'An upright source form cannot remain below the floor')
                slope,base=shape['foot'];left,top,right,bottom=shape['box'];errors=[]
                for col in range(left,right,3):
                    rows=[row for row in range(top,bottom) if pixels[col,row]>127]
                    if rows:errors.append(abs(max(rows)+1-(slope*(ox+col)+base-oy)))
                self.assertTrue(errors)
                self.assertLess(statistics.median(errors),12,'Fit the actual foot envelope, preserving the native surface projection')
                checked+=1
        self.assertEqual(checked,17)

    def test_tower_excludes_fence_and_stays_in_its_blocked_footprint(self):
        tower=json.loads((ROOT/'assets/maps/falan/elsa/scenery/data.json').read_text())['tower']
        masters={recovery.cut_records(59520)[serial-1000][0] for serial in tower['source_pieces']}
        self.assertEqual(masters,{300780,300781,300782,300783,300784,300785,300787})
        u,v=tower['anchor'];center=(u/64-v/48,u/64+v/48)
        cells={tuple(p) for p in tower['footprint_cells']}
        for x,z in tower['radial']+tower.get('terrace_radial',[]):
            for fraction in [.25,.5,.75,1.]:
                self.assertIn((int(center[0]+x*fraction/3+.5),int(center[1]+z*fraction/3+.5)),cells)
        props=json.loads((ROOT/'assets/maps/falan/elsa/props/data.json').read_text())
        self.assertTrue(any(props['groups'][p['group']]['master']==300786 for p in props['maps']['59520']))

    def test_tower_surface_roles_retain_the_original_visible_paint(self):
        folder=ROOT/'assets/maps/falan/elsa/scenery'
        tower=json.loads((folder/'data.json').read_text())['tower']
        original=Image.open(folder/'tower.png').convert('RGBA')
        self.assertEqual(hashlib.sha256(original.tobytes()).hexdigest(),tower['sha256'])
        self.assertEqual(len(tower['roots']),4)
        for index,root in enumerate(tower['roots']):
            actual=Image.open(folder/f'tower-root-{index}.png').convert('RGBA')
            native=original.crop(tuple(root['rect']))
            self.assertEqual(hashlib.sha256(actual.tobytes()).hexdigest(),root['rgba_sha256'])
            difference=ImageChops.difference(native.convert('RGB'),actual.convert('RGB'))
            for channel in difference.split():self.assertIsNone(ImageChops.multiply(channel,actual.getchannel('A')).getbbox())
        body=Image.open(folder/'tower-body.png').convert('RGBA')
        fill=Image.open(folder/tower['body_fill']['mask']).convert('L')
        self.assertEqual(hashlib.sha256(fill.tobytes()).hexdigest(),tower['body_fill']['sha256'])
        covered=Image.new('L',original.size)
        for index,root in enumerate(tower['roots']):
            alpha=Image.open(folder/f'tower-root-{index}.png').getchannel('A');layer=Image.new('L',original.size);layer.paste(alpha,root['rect'][:2]);covered=ImageChops.lighter(covered,layer)
        self.assertIsNone(ImageChops.subtract(fill,covered).getbbox(),'Inferred blue paint is confined to actual support occlusion')
        preserved=ImageChops.multiply(body.getchannel('A'),ImageChops.invert(fill))
        for channel in ImageChops.difference(original.convert('RGB'),body.convert('RGB')).split():
            self.assertIsNone(ImageChops.multiply(channel,preserved).getbbox())
        source_colors=set(original.convert('RGB').getdata());paint=body.load();mask=fill.load()
        self.assertTrue(all(paint[x,y][:3] in source_colors for y in range(body.height) for x in range(body.width) if mask[x,y]),'Hidden paint only extends original source colors')
        for name,box in tower['surfaces'].items():
            self.assertEqual(Image.open(folder/f'tower-{name}.png').convert('RGBA').tobytes(),original.crop(tuple(box)).tobytes())
        fence=Image.open(folder/'tower-fence.png').convert('RGBA');native=original.crop(tuple(tower['fence']['rect']))
        self.assertEqual(hashlib.sha256(fence.tobytes()).hexdigest(),tower['fence']['rgba_sha256'])
        for channel in ImageChops.difference(native.convert('RGB'),fence.convert('RGB')).split():
            self.assertIsNone(ImageChops.multiply(channel,fence.getchannel('A')).getbbox())

    def test_solid_edge_colors_sample_visible_original_pixels(self):
        folder=ROOT/'assets/maps/falan/elsa/props';data=json.loads((folder/'data.json').read_text());pages={}
        for group in data['groups'].values():
            page=int(group['page'])
            if page not in pages:pages[page]=Image.open(folder/f'atlas-{page}.png').convert('RGBA')
            x,y,w,h=group['rect'];art=pages[page].crop((x,y,x+w,y+h))
            shapes=[(art,group['edges'])]+[(art.crop(tuple(part['box'])),part['edges']) for part in group.get('grounded',[]) if not part['flat']]
            for native,edges in shapes:
                for *_,u,v in edges:self.assertGreater(native.getpixel((int(u),int(v)))[3],0,group['master'])

    def test_shore_depth_preserves_island_ground_and_native_paint(self):
        sea=json.loads((ROOT/'assets/maps/falan/elsa/scenery/data.json').read_text())['shore']
        width,height,planes=recovery.reference_map(59520)
        _,_,labels,_=recovery.components(59520)
        owned=set(json.loads((recovery.REPORT/'scope.json').read_text())['rooms']['59520']['components'])
        tiles={}
        for i,serial in enumerate(planes[0]):
            if serial<1000:continue
            art,offset,_=recovery.cut_image(59520,serial)
            u=(i%width+i//width)*32+offset[0];v=(i//width-i%width)*24+offset[1]
            tiles[(u//64,v//48)]=(art,u,v)
        for token,profile in sea['profiles'].items():
            mask=profile['vertices'];self.assertEqual(len(mask),221)
            self.assertEqual(hashlib.sha256(bytes(mask)).hexdigest(),token)
            coverage=set()
            for x,y,w,h,*corners in profile['quads']:
                cells={(xx,yy) for yy in range(y//4,(y+h)//4) for xx in range(x//4,(x+w)//4)}
                self.assertFalse(coverage&cells);coverage|=cells
                if len(set(corners))==1:
                    self.assertTrue(all(mask[yy*17+xx]==corners[0] for yy in range(y//4,(y+h)//4+1) for xx in range(x//4,(x+w)//4+1)))
                else:self.assertEqual((w,h),(4,4))
            self.assertEqual(coverage,{(x,y) for y in range(12) for x in range(16)})
        for index,token in sea['placements'].items():
            i=int(index);_,offset,_=recovery.cut_image(59520,planes[0][i])
            u=(i%width+i//width)*32+offset[0];v=(i//width-i%width)*24+offset[1]
            for j,lowered in enumerate(sea['profiles'][token]['vertices']):
                if not lowered:continue
                px=u+j%17*4;py=v+j//17*4;art,left,top=tiles[(px//64,py//48)]
                r,g,b,a=art.getpixel((px-left,py-top))
                self.assertTrue(a and r<20 and g<10 and 45<=b<=65)
                x=px/64-py/48;y=px/64+py/48;cx=int(x+.5);cy=int(y+.5)
                self.assertNotIn(labels[cy*width+cx],owned,'A sea fit cannot lower original island paths')
        self.assertGreater(len(sea['placements']),2000,'Unreachable exterior water must not be mistaken for island ground')

    def test_small_spires_keep_their_matching_native_parts(self):
        folder=ROOT/'assets/maps/falan/elsa/props';props=json.loads((folder/'data.json').read_text());pages={}
        self.assertEqual(len(props['spires']),5)
        for spire in props['spires']:
            group=props['groups'][spire['group']];self.assertIn('column',group)
            self.assertEqual(group['source_masters'],[300788,300789,300791])
            art=Image.new('RGBA',tuple(group['size']))
            for member in spire['members']:
                self.assertIn(member,props['maps']['59520'])
                row=props['groups'][member['group']];page=int(row['page'])
                if page not in pages:pages[page]=Image.open(folder/f'atlas-{page}.png').convert('RGBA')
                x,y,w,h=row['rect'];piece=pages[page].crop((x,y,x+w,y+h))
                dx=member['anchor'][0]+row['origin'][0]-spire['anchor'][0]-group['origin'][0]
                dy=member['anchor'][1]+row['origin'][1]-spire['anchor'][1]-group['origin'][1]
                art.alpha_composite(piece,(dx,dy))
            page=int(group['page'])
            if page not in pages:pages[page]=Image.open(folder/f'atlas-{page}.png').convert('RGBA')
            x,y,w,h=group['rect'];actual=pages[page].crop((x,y,x+w,y+h))
            self.assertEqual(art.tobytes(),actual.tobytes())

    def test_compound_rock_fits_keep_each_source_silhouette(self):
        folder=ROOT/'assets/maps/falan/elsa/props';props=json.loads((folder/'data.json').read_text());pages={};compound=0
        for group in props['groups'].values():
            if 'rock' not in group:continue
            shape=group['rock'];self.assertTrue((ROOT/shape['model'].removeprefix('res://')).is_file())
            self.assertEqual(shape['below'],group['master'] in [300401,300942,300944,300945])
            x,y,w,h=group['rect'];page=int(group['page'])
            if page not in pages:pages[page]=Image.open(folder/f'atlas-{page}.png').convert('RGBA')
            alpha=pages[page].crop((x,y,x+w,y+h)).getchannel('A');covered=Image.new('L',(w,h));draw=ImageDraw.Draw(covered)
            for left,top,right,bottom in shape['parts']:
                self.assertTrue(0<=left<right<=w and 0<=top<bottom<=h)
                draw.rectangle((left,top,right-1,bottom-1),fill=255)
            self.assertIsNone(ImageChops.subtract(alpha,covered).getbbox(),'A compound sheet cannot lose its smaller stones')
            compound+=len(shape['parts'])>1
        self.assertGreater(compound,10,'Compound sheets need individual solid stones, not one sheet-sized prop')

    def test_solid_furniture_keeps_original_masks_and_blocked_feet(self):
        folder=ROOT/'assets/maps/falan/elsa/props';props=json.loads((folder/'data.json').read_text())
        furniture=[(key,g) for key,g in props['groups'].items() if g.get('furniture')]
        self.assertEqual(len(furniture),3)
        self.assertEqual(sorted(g['furniture']['kind'] for key,g in furniture),['bench','bench','table'])
        floor=props['floor_infills']['59530'];width,_,planes=recovery.reference_map(floor['map'])
        left,top,right,bottom=floor['background_rect'];background=Image.new('RGBA',(right-left,bottom-top))
        for i,serial in enumerate(planes[0]):
            if serial<1000:continue
            art,origin,_=recovery.cut_image(floor['map'],serial)
            u=(i%width+i//width)*32+origin[0]-left;v=(i//width-i%width)*24+origin[1]-top
            if u+art.width>0 and v+art.height>0 and u<background.width and v<background.height:background.alpha_composite(art,(u,v))
        self.assertEqual(recovery.sha(background.tobytes()),floor['background_sha256'])
        actual=Image.open(folder/'floor-infill-59530.png').convert('RGBA');self.assertEqual(recovery.sha(actual.tobytes()),floor['rgba_sha256'])
        foreground=Image.new('RGBA',actual.size)
        for key,group in furniture:
            placement=next(p for p in props['maps']['59530'] if p['group']==key)
            self.assertIn(placement,floor['members'])
            self.assertNotIn('ground_cells',placement,'Solid furniture is not a room floor or stair tread')
            page=Image.open(folder/f"atlas-{group['page']}.png").convert('RGBA');x,y,w,h=group['rect']
            original=page.crop((x,y,x+w,y+h));gold=Image.open(ROOT/group['furniture']['gold']['path'].removeprefix('res://')).convert('RGB')
            warm={(r,g,b) for r,g,b,a in original.getdata() if a and r-g>=10 and g-b>=8 and r<=g*1.8}
            self.assertEqual(recovery.sha(gold.tobytes()),group['furniture']['gold']['sha256'])
            self.assertTrue(warm and set(gold.getdata())<=warm,'Metal must not extend pale background matte fringes')
            for native,prepared in zip(original.getdata(),gold.getdata()):
                r,g,b,a=native
                if a and r-g>=10 and g-b>=8 and r<=g*1.8:self.assertEqual(prepared,native[:3])
            if group['furniture']['kind']=='bench':
                record=group['furniture']['wood'];wood=Image.open(ROOT/record['path'].removeprefix('res://')).convert('RGB')
                brown={(r,g,b) for r,g,b,a in original.getdata() if a and (r>g*1.6 and g>b*1.2 or max(r,g,b)<=40)}
                self.assertEqual(recovery.sha(wood.tobytes()),record['sha256'])
                self.assertTrue(brown and set(wood.getdata())<=brown,'Wood and metal source paint stay separate')
                for native,prepared in zip(original.getdata(),wood.getdata()):
                    r,g,b,a=native
                    if a and (r>g*1.6 and g>b*1.2 or max(r,g,b)<=40):self.assertEqual(prepared,native[:3])
            u=placement['anchor'][0]+group['origin'][0];v=placement['anchor'][1]+group['origin'][1]
            foreground.alpha_composite(original,(u-floor['origin'][0],v-floor['origin'][1]))
            for x,y in group['furniture']['feet']:
                uu=u+x;vv=v+y
                self.assertNotEqual(planes[2][round(uu/64+vv/48)*width+round(uu/64-vv/48)],0)
        pad=floor['padding'];covered=background.crop((pad,pad,pad+actual.width,pad+actual.height))
        self.assertEqual(actual.getchannel('A').tobytes(),foreground.getchannel('A').tobytes())
        for original,prepared in zip(covered.getdata(),actual.getdata()):
            if prepared[3] and original[3] and max(original[:3])>40:self.assertEqual(original[:3],prepared[:3])
        palette={pixel[:3] for pixel in background.getdata() if pixel[3]}
        self.assertTrue(all(pixel[:3] in palette for pixel in actual.getdata() if pixel[3]))
        self.assertGreater(sum(pixel[3]>0 for pixel in actual.getdata()),100)

    def test_inner_wall_masonry_is_original_background_paint(self):
        folder=ROOT/'assets/maps/falan/elsa/props';props=json.loads((folder/'data.json').read_text());fit=props['bridge_inner']
        tile=Image.open(folder/'wall-inner.png').convert('RGBA');self.assertEqual(recovery.sha(tile.tobytes()),fit['rgba_sha256'])
        width,_,planes=recovery.reference_map(59520);tiles={}
        for i,serial in enumerate(planes[0]):
            if serial<1000:continue
            art,offset,_=recovery.cut_image(59520,serial)
            u=(i%width+i//width)*32+offset[0];v=(i//width-i%width)*24+offset[1]
            tiles[(u//64,v//48)]=(art,u,v)
        for y in range(tile.height):
            for x in range(tile.width):
                u=fit['origin_u']+x;v=round(fit['wall_origin'][1]+(u-fit['wall_origin'][0]-fit['footer'])/fit['slope']+fit['below_footer']+y)
                source,left,top=tiles[(u//64,v//48)]
                self.assertEqual(tile.getpixel((x,y)),source.getpixel((u-left,v-top)))
        self.assertTrue(all(pixel[3]==255 for pixel in tile.getdata()))
        self.assertEqual(sum('inner' in group.get('bridge',{}) for group in props['groups'].values()),2)

    def test_arrival_gate_uses_original_foreground_and_background(self):
        folder=ROOT/'assets/maps/falan/elsa/scenery/gate';data=json.loads((folder/'data.json').read_text())
        for gate in [data]+data.get('others',[]):self.assert_source_gate(folder/gate.get('folder',''),gate)

    def assert_source_gate(self,folder,gate):
        props=json.loads((ROOT/'assets/maps/falan/elsa/props/data.json').read_text());left,top,right,bottom=gate['rect']
        expected=Image.new('RGBA',(right-left,bottom-top));background=Image.new('RGBA',expected.size)
        cells={tuple(c) for member in gate['members'] for c in member['cells']}
        width,_,planes=recovery.reference_map(59520)
        for member in gate['members']:self.assertIn(member,props['maps']['59520'])
        for layer in range(2):
            for i,serial in enumerate(planes[layer]):
                if serial<1000 or layer==1 and (i%width,i//width) not in cells:continue
                art,origin,_=recovery.cut_image(59520,serial)
                u=(i%width+i//width)*32+origin[0]-left;v=(i//width-i%width)*24+origin[1]-top
                if u+art.width<=0 or v+art.height<=0 or u>=expected.width or v>=expected.height:continue
                (background if layer==0 else expected).alpha_composite(art,(u,v))
        actual=Image.open(folder/'foreground.png').convert('RGBA');self.assertEqual(actual.tobytes(),expected.tobytes())
        paint=Image.open(folder/'paint.png').convert('RGBA');solid=Image.open(folder/'solid.png').convert('RGB')
        for foreground,bg,prepared,opaque in zip(expected.getdata(),background.getdata(),paint.getdata(),solid.getdata()):
            if foreground[3]:self.assertEqual(prepared,foreground)
            elif prepared[3]:self.assertEqual(prepared,bg)
            if prepared[3]:self.assertEqual(opaque,prepared[:3])
        for x,y in gate['feet']:self.assertNotEqual(planes[2][int(y+.5)*width+int(x+.5)],0)
        self.assertEqual(planes[2][104*width+124],0,'The source gate passage remains open')

    def test_solid_prop_paint_keeps_dark_opaque_source_colors(self):
        folder=ROOT/'assets/maps/falan/elsa/props';props=json.loads((folder/'data.json').read_text());pages={}
        for group in props['groups'].values():
            page=int(group['page'])
            if page not in pages:pages[page]=(Image.open(folder/f'atlas-{page}.png').convert('RGBA'),Image.open(folder/f'solid-{page}.png').convert('RGB'))
            x,y,w,h=group['rect'];native=pages[page][0].crop((x,y,x+w,y+h));actual=pages[page][1].crop((x,y,x+w,y+h))
            channels=ImageChops.difference(native.convert('RGB'),actual).split()
            difference=ImageChops.lighter(ImageChops.lighter(channels[0],channels[1]),channels[2])
            mask=native.getchannel('A').point(lambda alpha:255 if alpha else 0)
            self.assertIsNone(ImageChops.multiply(difference,mask).getbbox(),group['master'])

    def test_packed_torches_keep_all_twelve_source_stands(self):
        folder=ROOT/'assets/maps/falan/elsa/props';props=json.loads((folder/'data.json').read_text())
        sheet=next(g for g in props['groups'].values() if g['master']==300938 and g['size'][0]>600)
        self.assertEqual(len(sheet['columns']),12)
        x,y,w,h=sheet['rect'];art=Image.open(folder/f"atlas-{sheet['page']}.png").crop((x,y,x+w,y+h)).convert('RGBA')
        covered=Image.new('L',(w,h));draw=ImageDraw.Draw(covered)
        for part in sheet['columns']:
            left,top,right,bottom=part['box'];draw.rectangle((left,top,right-1,bottom-1),fill=255)
            self.assertGreater(len(part['profile']),1)
        self.assertIsNone(ImageChops.subtract(art.getchannel('A'),covered).getbbox())

    def test_trial_cliff_depth_keeps_native_top_paint_and_walking_mask(self):
        data=prepared_terrain(59602)
        width,height,planes=recovery.reference_map(59602)
        self.assertEqual(data['grid_sha256'],hashlib.sha256(struct.pack('<'+'H'*len(planes[0]),*planes[0])).hexdigest())
        self.assertEqual(data['walking_sha256'],hashlib.sha256(struct.pack('<'+'H'*len(planes[2]),*planes[2])).hexdigest())
        _,_,labels,_=recovery.components(59602)
        owned=set(json.loads((recovery.REPORT/'scope.json').read_text())['rooms']['59602']['components']);tiles={}
        for i,serial in enumerate(planes[0]):
            if serial<1000:continue
            art,offset,_=recovery.cut_image(59602,serial)
            u=(i%width+i//width)*32+offset[0];v=(i//width-i%width)*24+offset[1]
            tiles[(u//64,v//48)]=(i,u,v,art)
        for profile in data['profiles'].values():
            self.assertEqual(len(profile['roles']),len(profile['quads']))
            coverage=set()
            for role,(x,y,w,h,*corners) in zip(profile['roles'],profile['quads']):
                cells={(xx,yy) for yy in range(y//8,(y+h)//8) for xx in range(x//8,(x+w)//8)}
                self.assertFalse(coverage&cells);coverage|=cells
                self.assertTrue(all(value<=0 for value in corners))
                if role:
                    self.assertEqual(corners[0]-corners[3],h,'A cliff keeps vertical pixel spacing instead of stretching to ground')
                    self.assertEqual(corners[1]-corners[2],h)
                    self.assertLessEqual(abs(corners[0]-corners[1]),w*2,'Adjacent wall sections share a continuous ledge')
                else:self.assertEqual(corners,[0]*4)
            self.assertEqual(coverage,{(x,y) for y in range(6) for x in range(8)})
        count=0
        for i,label in enumerate(labels):
            if label not in owned:continue
            u=(i%width+i//width)*32;v=(i//width-i%width)*24
            tile=tiles.get((u//64,v//48))
            if not tile or str(tile[0]) not in data['placements']:continue
            r,g,b,a=tile[3].getpixel((int(u-tile[1]),int(v-tile[2])))
            # Blue wall paint can project across a navigation cell while its
            # physical surface stands behind that cell. Only original top
            # paint represents this cell's visible zero-height ground.
            if not(a and r>25 and r>b*1.25 and r>g*1.1):continue
            shape=data['profiles'][data['placements'][str(tile[0])]]
            flat=[quad for role,quad in zip(shape['roles'],shape['quads']) if not role and quad[0]<=u-tile[1]<=quad[0]+quad[2] and quad[1]<=v-tile[2]<=quad[1]+quad[3]]
            self.assertTrue(flat,'Original brown walking ground remains a flat surface')
            count+=1
        self.assertGreater(count,0)

    def test_cliff_family_covers_every_scoped_native_map(self):
        folder=ROOT/'assets/maps/falan/elsa/scenery/terrain';coverage=json.loads((folder/'coverage.json').read_text())
        expected=[];templates=set()
        for ident in json.loads((recovery.REPORT/'scope.json').read_text())['maps']:
            _,_,planes=recovery.reference_map(ident);records=recovery.cut_records(ident)
            if any(serial>=1000 and records[serial-1000][0] in set(range(300374,300401))|{300402} for serial in planes[0]):expected.append(ident)
        self.assertEqual(coverage['maps'],expected)
        for ident in expected:
            row=prepared_terrain(ident);_,_,planes=recovery.reference_map(ident)
            self.assertEqual(row['grid_sha256'],hashlib.sha256(struct.pack('<'+'H'*len(planes[0]),*planes[0])).hexdigest())
            self.assertEqual(row['walking_sha256'],hashlib.sha256(struct.pack('<'+'H'*len(planes[2]),*planes[2])).hexdigest())
            templates.add(row['template'])
        for template in templates:
            self.assertEqual(hashlib.sha256((folder/template).read_bytes()).hexdigest(),Path(template).stem)

    def test_trial_foreground_arch_uses_existing_source_background_depth(self):
        folder=ROOT/'assets/maps/falan/elsa';props=json.loads((folder/'props/data.json').read_text())
        group=props['groups']['562'];path=ROOT/group['source_surface']['path'].removeprefix('res://');raw=path.read_bytes();spec=json.loads(raw)
        self.assertEqual(hashlib.sha256(raw).hexdigest(),group['source_surface']['sha256'])
        self.assertEqual(spec['source_rgba_sha256'],group['rgba_sha256'])
        self.assertEqual(spec['blue_pixels'],27001);self.assertEqual(spec['blue_pixels_on_existing_wall'],27001);self.assertFalse(spec['unmatched'])
        terrain=prepared_terrain(59609);w,h,planes=recovery.reference_map(59609);walls={}
        for index,token in terrain['placements'].items():
            i=int(index);_,origin,_=recovery.cut_image(59609,planes[0][i]);u=(i%w+i//w)*32+origin[0];v=(i//w-i%w)*24+origin[1]
            for role,quad in zip(terrain['profiles'][token]['roles'],terrain['profiles'][token]['quads']):
                if role:walls[u+quad[0],v+quad[1]]=quad[4:]
        u=spec['anchor'][0]+group['origin'][0];v=spec['anchor'][1]+group['origin'][1]
        self.assertEqual(len(spec['quads']),16*36)
        for role,quad in zip(spec['roles'],spec['quads']):
            self.assertEqual(quad[4:],walls[u+quad[0],v+quad[1]] if role else [0]*4)
        places=[p for rows in props['maps'].values() for p in rows if p['group']=='562']
        self.assertEqual(len(places),56);self.assertTrue(all(p['anchor']==spec['anchor'] for p in places))
        maps={ident for ident,rows in props['maps'].items() if any(p['group']=='562' for p in rows)}
        self.assertEqual(set(spec['map_templates']),maps)
        self.assertEqual(len(spec['variants']),2)
        observed={}
        for ident in maps:
            terrain=prepared_terrain(int(ident));variant=spec['variants'][spec['map_templates'][ident]]
            self.assertEqual(variant['background_template'],terrain['template'])
            width,_,planes=recovery.reference_map(int(ident));cuts=recovery.cut_records(int(ident));walls={}
            for index,token in terrain['placements'].items():
                i=int(index);cut=cuts[planes[0][i]-1000]
                left=(i%width+i//width)*32-cut[6];top=(i//width-i%width)*24-cut[7]
                for role,q in zip(terrain['profiles'][token]['roles'],terrain['profiles'][token]['quads']):
                    if role:walls[left+q[0],top+q[1]]=q[4:]
            for role,q in zip(variant['roles'],variant['quads']):
                self.assertEqual(q[4:],walls.get((u+q[0],v+q[1]),[0]*4))
                self.assertEqual(role,int((u+q[0],v+q[1]) in walls))
            observed[ident]=sum(a[4:]!=b[4:] for a,b in zip(variant['quads'],spec['quads']))
        self.assertEqual(sorted(observed.values()),[0]*28+[137]*28,
                         'The other28 maps must not reuse59609 depth for6605 visible source pixels')

    def test_trial_entrance_keeps_native_recess_paint_and_declared_inference(self):
        from prepare_elsa_gate import native_layers
        folder=ROOT/'assets/maps/falan/elsa/scenery';props=json.loads((folder.parent/'props/data.json').read_text())
        fit=json.loads((folder/'trial-surfaces/562.json').read_text())
        path=ROOT/fit['entrance'].removeprefix('res://');spec=json.loads(path.read_text())
        self.assertFalse(spec['candidate_only']);self.assertEqual(set(spec['map_source_proofs']),set(fit['map_templates']))
        self.assertEqual(len(spec['map_source_proofs']),56)
        self.assertEqual(spec['anchor'],[4544,1008]);self.assertEqual(spec['foot_v'],24*(95-45))
        self.assertEqual(spec['crossing']['target'],59602);self.assertEqual(spec['crossing']['landing'],[66,75])
        foreground,background=native_layers(props['maps']['59603'],tuple(spec['source_rect']),59603)
        composite=background.copy();composite.alpha_composite(foreground)
        self.assertEqual(hashlib.sha256(composite.tobytes()).hexdigest(),spec['source_composite_rgba_sha256'])
        paint=Image.open(path.parent/spec['candidate_paint']).convert('RGBA')
        self.assertEqual(hashlib.sha256(paint.tobytes()).hexdigest(),spec['backing_paint_rgba_sha256'])
        left,top,_,_=spec['native_rect'];source_left,source_top,_,_=spec['source_rect']
        for y in range(min(map(int,spec['rows'])),int(spec['foot_v'])+1):
            span=spec['rows'][str(min(y,spec['lower_continuation_from']))]
            for x in range(*span):
                color=composite.getpixel((x-source_left,y-source_top))
                expected=(*color[:3],255) if color[3] else (0,0,0,255)
                self.assertEqual(paint.getpixel((x-left,y-top)),expected)
        self.assertEqual(spec['inferred_floor_thickness'],.5)
        self.assertTrue(spec['inferred'] and spec['inferred_depth']>0)
        self.assertEqual(Image.open(path.parent/'inner-edge.png').getpixel((0,0)),tuple(spec['intrados_rgb']))

    def test_pedestal_keeps_original_body_globe_and_material_boundaries(self):
        folder=ROOT/'assets/maps/falan/elsa/props';props=json.loads((folder/'data.json').read_text());row=props['groups']['406']
        raw=(ROOT/row['pedestal']['path'].removeprefix('res://')).read_bytes();spec=json.loads(raw)
        self.assertEqual(hashlib.sha256(raw).hexdigest(),row['pedestal']['sha256'])
        x,y,w,h=row['rect'];original=Image.open(folder/f"atlas-{row['page']}.png").convert('RGBA').crop((x,y,x+w,y+h))
        self.assertEqual(hashlib.sha256(original.tobytes()).hexdigest(),spec['rgba_sha256'])
        self.assertEqual((spec['master'],spec['origin'],spec['size']),(301044,[-192,48],[128,192]))
        self.assertFalse(spec['candidate_only']);self.assertTrue(spec['body']['native_faces'])
        body=Image.open(ROOT/spec['paints']['body'].removeprefix('res://')).convert('RGB')
        globe=Image.open(ROOT/spec['paints']['globe'].removeprefix('res://')).convert('RGBA')
        blue=Image.new('L',original.size)
        for y in range(h):
            for x in range(w):
                r,g,b,a=original.getpixel((x,y))
                if a and b>r*1.1 and b>g*1.1 and b>100:
                    blue.putpixel((x,y),255)
                    self.assertEqual(globe.getpixel((x,y)),(r,g,b,a))
        self.assertEqual(blue.getbbox(),(39,6,89,51))
        cap=blue.filter(ImageFilter.MaxFilter(11))
        for y in range(h):
            for x in range(w):
                c=original.getpixel((x,y))
                if c[3] and not cap.getpixel((x,y)):self.assertEqual(body.getpixel((x,y)),c[:3])
        for y in [144,145]:
            for x in range(18,112):
                c=body.getpixel((x,y));self.assertLessEqual(max(c)-min(c),5)
        self.assertEqual(spec['body']['molding']['paint_row'],144.5)
        self.assertTrue(any('outside the original blue globe mask' in line for line in spec['inferred']))

    def test_mixed_trial_cap_keeps_native_ground_and_separate_pillars(self):
        from prepare_elsa_gate import native_layers
        folder=ROOT/'assets/maps/falan/elsa/props';props=json.loads((folder/'data.json').read_text())
        group=props['groups']['564'];x,y,w,h=group['rect']
        original=Image.open(folder/f"atlas-{group['page']}.png").convert('RGBA').crop((x,y,x+w,y+h))
        paint=Image.open(folder/'trial-cap-300943-floor.png').convert('RGBA')
        mask=Image.open(folder/'trial-cap-300943-infill-mask.png').convert('L')
        self.assertEqual(paint.getchannel('A').tobytes(),original.getchannel('A').tobytes())
        outside=ImageChops.multiply(ImageChops.difference(paint,original).convert('RGB'),ImageChops.invert(mask).convert('RGB'))
        self.assertIsNone(outside.getbbox(),'Original cap paint outside lifted pillars remains exact')
        place=next(p for p in props['maps']['59609'] if p['group']=='564')
        u=place['anchor'][0]+group['origin'][0];v=place['anchor'][1]+group['origin'][1]
        _,bg=native_layers([],(u,v,u+w,v+h),59609)
        self.assertEqual(hashlib.sha256(bg.tobytes()).hexdigest(),group['floor_paint']['background_rgba_sha256'])
        blank=ImageChops.multiply(mask,ImageChops.invert(bg.getchannel('A')))
        self.assertEqual(group['floor_paint']['inferred_blank_pixels'],sum(bool(p) for p in blank.getdata()))
        expected=original.copy();expected.paste(bg,(0,0),mask);expected.putalpha(original.getchannel('A'))
        confirmed=ImageChops.multiply(mask,bg.getchannel('A'))
        self.assertIsNone(ImageChops.multiply(ImageChops.difference(paint,expected).convert('RGB'),confirmed.convert('RGB')).getbbox(),'Original BG ground is exact where present')
        palette={(r,g,b) for (r,g,b,a),covered in zip(original.getdata(),mask.getdata()) if not covered and a and r>15 and 1.02*g<r<1.55*g and 1.03*b<g<1.8*b}
        self.assertTrue(all(pixel[:3] in palette for pixel,on in zip(paint.getdata(),blank.getdata()) if on),'Only explicitly missing BG pixels use nearby native brown paint')
        template=props['groups']['522']['columns'][0]
        self.assertEqual(len(group['columns']),2)
        for column,offset in zip(group['columns'],[(65,-8),(2,88)]):
            self.assertEqual(column['foot'],[template['foot'][0]+offset[0],template['foot'][1]+offset[1]])
            self.assertEqual(column['profile'],[[x+offset[0],y+offset[1],width] for x,y,width in template['profile']])

    def test_bridge_surface_fit_keeps_the_original_decks_and_arch_paint(self):
        folder=ROOT/'assets/maps/falan/elsa/props';props=json.loads((folder/'data.json').read_text())
        bridges=[g for g in props['groups'].values() if 'bridge' in g]
        self.assertEqual({g['master'] for g in bridges},{300814,300815})
        for group in bridges:
            self.assertGreater(group['bridge']['height_pixels'],0)
            x,y,w,h=group['rect'];art=Image.open(folder/f"atlas-{group['page']}.png").crop((x,y,x+w,y+h)).convert('RGBA')
            self.assertEqual(hashlib.sha256(art.tobytes()).hexdigest(),group['rgba_sha256'])
            covered=Image.new('L',(w,h));draw=ImageDraw.Draw(covered)
            for x,y,w,h in group['bridge']['quads']:draw.rectangle((x,y,x+w-1,y+h-1),fill=255)
            self.assertIsNone(ImageChops.subtract(art.getchannel('A'),covered).getbbox())
        width,_,planes=recovery.reference_map(59520)
        for placement in props['maps']['59520']:
            group=props['groups'][placement['group']]
            if 'bridge' not in group:continue
            span=group['bridge']
            for v in [96,240,400]:
                u=span['edge'][0]*v+span['edge'][1]-8
                native_u=placement['anchor'][0]+group['origin'][0]+u
                ground_v=placement['anchor'][1]+group['origin'][1]+v+span['height_pixels']
                for side in [0,-span['depth_pixels']]:
                    x=(native_u+side)/64-ground_v/48;y=(native_u+side)/64+ground_v/48
                    self.assertNotEqual(planes[2][int(y+.5)*width+int(x+.5)],0,'Both faces of the decorative span stay on its original blocked support')

    def test_zero_area_static_crops_do_not_draw_whole_master_sheets(self):
        count=0
        for row in self.catalog['maps'].values():
            ident=row['id'];width,_,planes=recovery.reference_map(ident);header=recovery.cut_header(ident)
            for serial in planes[1]:
                if serial<1000 or serial-1000>=sum(header[2:4]):continue
                record=recovery.cut_records(ident)[serial-1000]
                if record[4:6]!=(0,0):continue
                graphic=self.catalog['graphics'][str(row['art_remap'][str(serial)])]
                self.assertEqual(graphic['family'],'void','An empty static crop must not become its full master sheet')
                count+=1
        self.assertEqual(count,70)
        props=json.loads((ROOT/'assets/maps/falan/elsa/props/data.json').read_text())
        phantom=next(p for p in props['maps']['59520'] if p['anchor']==[7840,-888] and props['groups'][p['group']]['master']==300806)
        self.assertTrue(phantom['empty_cut'],'Return-stone marker must not draw a phantom gate')
        self.assertNotIn('ground_cells',phantom)

    def test_every_visible_static_piece_has_a_coherent_owner(self):
        props=json.loads((ROOT/'assets/maps/falan/elsa/props/data.json').read_text())
        tower={300780,300781,300782,300783,300784,300785,300787}
        for maprow in self.catalog['maps'].values():
            ident=maprow['id'];width,_,planes=recovery.reference_map(ident);header=recovery.cut_header(ident);expected=set()
            for i,serial in enumerate(planes[1]):
                if not 1000+header[2]<=serial<1000+sum(header[2:4]):continue
                graphic=self.catalog['graphics'][str(maprow['art_remap'][str(serial)])]
                if graphic['family']=='void' or ident==59520 and graphic['cut'][0] in tower:continue
                expected.add((i%width,i//width))
            actual=set()
            for p in props['maps'][str(ident)]:
                if not p.get('empty_cut'):actual.update(tuple(cell) for cell in p['cells'])
            self.assertEqual(actual,expected,f'Every visible source prop, including full city trees, needs one owner in {ident}')

    def test_inner_hall_enclosure_separates_original_floor_and_wall_paint(self):
        from prepare_elsa_gate import native_layers
        folder=ROOT/'assets/maps/falan/elsa/scenery/inner-hall'
        data=json.loads((folder/'data.json').read_text())
        fg,bg=native_layers(data['members'],data['rect'],59535)
        paint=Image.alpha_composite(bg,fg)
        floor=Image.open(folder/'floor.png').convert('RGBA')
        mask=Image.open(folder/'object-mask.png').convert('L')
        for name,image in [('background',bg),('foreground',fg),('paint',paint),('floor',floor),('mask',mask)]:
            self.assertEqual(hashlib.sha256(image.tobytes()).hexdigest(),data['hashes'][name],name)
        self.assertEqual(Image.open(folder/'paint.png').convert('RGBA').tobytes(),paint.tobytes())
        for name,layer in [('foreground',fg),('background',bg)]:
            solid=Image.open(folder/(name+'-solid.png')).convert('RGB')
            self.assertTrue(all(tuple(pixel[:3])==extended for pixel,extended in zip(layer.getdata(),solid.getdata()) if pixel[3]))
        source_palette={pixel[:3] for pixel in paint.getdata() if pixel[3]}
        for name,digest in data['material_hashes'].items():
            material=Image.open(folder/(name+'.png')).convert('RGB')
            self.assertEqual(hashlib.sha256(material.tobytes()).hexdigest(),digest)
            self.assertTrue(set(material.getdata())<=source_palette,name)
        front=Image.open(folder/'background-wall.png').convert('RGB')
        trim=Image.open(folder/'portal-trim.png').convert('RGBA');fit=data['portal']
        self.assertEqual(hashlib.sha256(trim.tobytes()).hexdigest(),fit['rgba_sha256'])
        at=(fit['origin'][0]-data['rect'][0],fit['origin'][1]-data['rect'][1])
        native=paint.crop((at[0],at[1],at[0]+trim.width,at[1]+trim.height))
        self.assertTrue(all(a==b for a,b in zip(trim.getdata(),native.getdata()) if a[3]))
        self.assertGreater(len(fit['edges']),20)
        alpha=trim.getchannel('A')
        for edge in fit['edges']:
            self.assertGreaterEqual(alpha.getpixel((int(edge[4]),int(edge[5]))),128)
            for x,y in [edge[:2],edge[2:4]]:
                neighbors=[alpha.getpixel((xx,yy)) if 0<=xx<trim.width and 0<=yy<trim.height else 0
                           for yy in range(round(y)-1,round(y)+1) for xx in range(round(x)-1,round(x)+1)]
                self.assertTrue(any(v>=128 for v in neighbors) and any(v<128 for v in neighbors),
                                'A solid cap ends at the actual rendered silhouette')
        for x,y in [(280,800),(290,820),(300,840)]:
            point=(3200-data['rect'][0]+x,-673-data['rect'][1]+y)
            raised=trim.getpixel((point[0]-at[0],point[1]-at[1]))
            color=raised[:3] if raised[3] else front.getpixel(point)
            self.assertEqual(color,bg.getpixel(point)[:3],'Original portal paint on its owning surface')
        keep=ImageChops.invert(mask)
        difference=ImageChops.multiply(ImageChops.difference(bg,floor),Image.merge('RGBA',[keep]*4))
        self.assertIsNone(difference.convert('RGB').getbbox())
        self.assertIsNone(difference.getchannel('A').getbbox())
        x,y,w,h=data['paving_rect'];palette=set(bg.crop((x,y,x+w,y+h)).getdata())
        a,b=[data['feet'][i] for i in [7,6]];u=(a[0]+b[0])*.5;v=(a[1]+b[1])*.5-9
        self.assertIn(floor.getpixel((round(u-data['rect'][0]),round(v-data['rect'][1]))),palette,
                      'The exposed strip outside the inset portal wall is paving, not interior blue')
        physical=Image.new('L',paint.size)
        left,top=data['rect'][:2]
        ImageDraw.Draw(physical).polygon([(u-left,v-top) for u,v in data['blue_footprint']],fill=255)
        palette.update((r,g,b,255) for (r,g,b,a),inside in zip(paint.getdata(),physical.getdata())
                       if inside and a and (max(r,g,b)<=3 or r==0 and g==0 and b>0))
        self.assertTrue(all(pixel in palette for pixel,covered in zip(floor.getdata(),mask.getdata()) if covered))
        width,height,planes=recovery.reference_map(59535)
        self.assertEqual(len(data['feet']),8);self.assertEqual(len(data['walls']),6)
        for u,v in data['feet']:
            x=round(u/64-v/48);y=round(u/64+v/48)
            self.assertNotEqual(planes[2][y*width+x],0,(x,y))
            r,g,b,a=paint.getpixel((u-left,v-top-276))
            self.assertTrue(a and r>g*1.3 and r>b*1.3,'Original red cap above each column')
        for wall in data['walls']:
            a,b=[data['feet'][i] for i in wall['feet']]
            for u,top,foot in wall['rows']:
                self.assertLess(top,foot)
                self.assertAlmostEqual(foot,a[1]+(b[1]-a[1])*(u-a[0])/(b[0]-a[0])-wall['inset'],places=6)

    def test_inner_hall_treads_preserve_native_curves_and_walk_mask(self):
        import math
        folder=ROOT/'assets/maps/falan/elsa/scenery/inner-hall'
        data=json.loads((folder/'data.json').read_text());steps=data['steps']
        vertical=math.sqrt(2*((32/3)**2-8**2))
        self.assertEqual([tier['height'] for tier in steps['tiers']],[.5,1.,1.5])
        for tier in steps['tiers']:
            self.assertEqual(len(tier['points']),len(tier['native_curve']))
            for (x,y,z),(u,v) in zip(tier['points'],tier['native_curve']):
                self.assertAlmostEqual((x+z)*32/3,u+data['rect'][0])
                self.assertAlmostEqual((z-x)*8-y*vertical,v+data['rect'][1])
            for x,y,z in tier['back_points']:
                u=(x+z)*32/3
                self.assertAlmostEqual((z-x)*8,data['portal']['foot'][0]*u+data['portal']['foot'][1]-1)
        grid=steps['grid'];self.assertEqual(len(grid['heights']),grid['size'][0]*grid['size'][1])
        self.assertGreater(max(grid['heights']),1.)
        width,height,planes=recovery.reference_map(59535);walkable=0
        for z in range(grid['size'][1]):
            for x in range(grid['size'][0]):
                value=grid['heights'][z*grid['size'][0]+x]
                self.assertGreaterEqual(value,0);self.assertLessEqual(value,1.5)
                if value>0:
                    cx=round((grid['origin'][0]+x*grid['spacing'])/3)
                    cy=round((grid['origin'][1]+z*grid['spacing'])/3)
                    walkable+=planes[2][cy*width+cx]==0
        self.assertGreater(walkable,0,'Steps require physical and native-height support on original open cells')

    def test_inner_hall_outer_room_uses_original_wall_spans(self):
        folder=ROOT/'assets/maps/falan/elsa/scenery/inner-hall'
        data=json.loads((folder/'data.json').read_text());room=data['room']
        source=Image.open(folder/'original-background.png').convert('RGBA')
        paint=Image.open(folder/'room-wall.png').convert('RGB')
        mask=Image.open(folder/'room-mask.png').convert('L')
        occlusion=Image.open(folder/'enclosure-mask.png').convert('L').filter(ImageFilter.MaxFilter(9))
        self.assertEqual(len(room['walls']),4);self.assertEqual(len(room['columns']),7)
        for wall in room['walls']:
            for u,top,foot in wall['rows']:
                x=round(u-data['rect'][0]);y=round(top-data['rect'][1])
                self.assertLess(top,foot)
                if any(abs(u-f[0])<42 for f in room['feet']):continue
                self.assertGreater(max(source.getpixel((x,y))[:3]),3)
                for yy in range(y,round(foot-data['rect'][1])-48,8):
                    native=source.getpixel((x,yy))
                    if native[3] and max(native[:3])>3 and max(native[:3])-min(native[:3])<18 and not occlusion.getpixel((x,yy)):
                        self.assertEqual(paint.getpixel((x,yy)),native[:3])
                        self.assertEqual(mask.getpixel((x,yy)),255)
        self.assertEqual(room['side_faces'],[[0,1],[5,6]])
        self.assertIn('Original walkability is retained',room['inference'])
        for point in [(532,366),(865,360)]:
            color=paint.getpixel(point)
            self.assertLess(max(color)-min(color),16,'The room wall does not own the occluding portal paint')
        columns=Image.open(folder/'room-columns.png').convert('RGB')
        for point,patch in [((487,410),(477,240,497,244)),((865,360),(855,230,875,234))]:
            palette={pixel[:3] for pixel in source.crop(patch).getdata()}
            self.assertIn(columns.getpixel(point),palette,'Hidden shafts continue their own original stone, without portal fragments')

    def test_temple_material_roles_preserve_native_paint_and_crossings(self):
        from prepare_elsa_gate import native_layers
        from prepare_elsa_temple import RECT, rear_contact, VERTICAL
        folder=ROOT/'assets/maps/falan/elsa/scenery/temple'
        data=json.loads((folder/'data.json').read_text())
        _,original=native_layers([],RECT,59520)
        background=Image.open(folder/'original-background.png').convert('RGBA')
        floor=Image.open(folder/'floor.png').convert('RGBA')
        mask=Image.open(folder/'building-mask.png').convert('L')
        self.assertIsNone(ImageChops.difference(original,background).convert('RGB').getbbox())
        gaps=Image.open(folder/'occluded-floor-mask.png').convert('L')
        visible=ImageChops.invert(ImageChops.lighter(mask,gaps))
        outside=ImageChops.multiply(ImageChops.difference(background,floor).convert('RGB'),visible.convert('RGB'))
        self.assertIsNone(outside.getbbox(),'Visible garden and source entrance terraces remain exact')
        x,y,w,h=data['grass_rect'];grass=background.crop((x,y,x+w,y+h))
        allowed=set(grass.getdata());covered=list(mask.getdata())
        self.assertTrue(all(color in allowed for color,on in zip(floor.getdata(),covered) if on))
        for name,row in data['materials'].items():
            u,v,w,h=row['rect'];tile=Image.open(folder/(name+'.png')).convert('RGBA')
            native=background.crop((u-RECT[0],v-RECT[1],u-RECT[0]+w,v-RECT[1]+h))
            self.assertEqual(tile.tobytes(),native.tobytes(),name)
        width,height,planes=recovery.reference_map(59520)
        for part in data['parts']:
            for u,v in part['rear']:
                self.assertEqual(v,rear_contact(u,planes,width,height))
            self.assertIn('inferred',part['inference'])
        links=json.loads((ROOT/'assets/maps/falan/elsa/links.json').read_text())
        self.assertEqual(data['doors'],[r for r in links if r['source']==59520 and r['target']==59530])
        self.assertEqual(len(data['parts']),5)
        from prepare_elsa_temple import BAYS
        central=next(part for part in data['parts'] if part['name']=='central-entrance')
        self.assertEqual(central['bays'],BAYS)
        self.assertIn('inferred',central['bays']['inference'])
        for span in central['bays']['spans']:
            u=round(sum(span)/2)
            r,g,b,a=background.getpixel((u-RECT[0],-3200-RECT[1]))
            self.assertTrue(a and min(r,g,b)>100 and abs(r-g)<35,'The bay centre follows original pale facade paint')
        from prepare_elsa_temple import UPPER
        for part in data['parts']:
            if part['kind']!='pylon':continue
            self.assertEqual(part['upper'],UPPER)
            self.assertNotIn('height',part);self.assertNotIn('taper',part)
            self.assertIn('inferred',part['upper']['inference'])
        front=Image.open(folder/'front-solid.png').convert('RGB')
        difference=ImageChops.multiply(ImageChops.difference(front,background.convert('RGB')),background.getchannel('A').convert('RGB'))
        self.assertIsNone(difference.getbbox(),'Opaque facade paint is unchanged')
        self.assertEqual(front.getpixel((7580-RECT[0],-2840-RECT[1])),(0,0,0),'Dark keyed doorway remains a black recess, not gold edge streaks')

    def test_temple_steps_keep_native_footprints_and_separate_baked_rails(self):
        from prepare_elsa_temple_steps import RECT, gold
        folder=ROOT/'assets/maps/falan/elsa/scenery/temple-steps'
        base=ROOT/'assets/maps/falan/elsa/scenery/temple'
        data=json.loads((folder/'data.json').read_text())
        native=Image.open(base/'original-background.png').convert('RGBA')
        paint=Image.open(folder/'paint.png').convert('RGB')
        rails=Image.open(folder/'rail-mask.png').convert('L')
        paint_infill=Image.open(folder/'paint-infill-mask.png').convert('L')
        front=Image.open(folder/'front-paint.png').convert('RGB')
        old_front=Image.open(base/'front-solid.png').convert('RGB')
        front_mask=Image.open(folder/'front-infill-mask.png').convert('L')
        self.assertIsNone(ImageChops.multiply(ImageChops.difference(front,old_front),ImageChops.invert(front_mask).convert('RGB')).getbbox())
        floor=Image.open(folder/'floor.png').convert('RGB')
        previous=Image.open(base/'floor.png').convert('RGB')
        foot=Image.open(folder/'footprint-mask.png').convert('L')
        self.assertIsNone(ImageChops.multiply(ImageChops.difference(paint,native.convert('RGB')),ImageChops.invert(paint_infill).convert('RGB')).getbbox())
        allowed=ImageChops.lighter(ImageChops.lighter(rails,foot),Image.open(folder/'outer-halo-mask.png').convert('L'))
        self.assertIsNone(ImageChops.multiply(ImageChops.difference(floor,previous),ImageChops.invert(allowed).convert('RGB')).getbbox())
        self.assertEqual(data['rises'],{'west-entrance':3.5,'central-entrance':4.5,'east-entrance':4.0})
        self.assertEqual(len(data['steps']['tiers']),24)
        self.assertEqual(data['steps']['map_origin'],[-447,-447])
        for tier in data['steps']['tiers']:
            for point,(u,v,confirmed) in zip(tier['points'],tier['native_curve']):
                self.assertAlmostEqual((point[0]+point[2])*32/3,u,places=6)
                self.assertAlmostEqual((point[2]-point[0])*8,v,places=6)
                if confirmed:self.assertTrue(any(gold(native,u,round(v)+d) for d in [-4,-3,-2,-1,0,1,2,3,4]))
        props=json.loads((ROOT/'assets/maps/falan/elsa/props/data.json').read_text())
        masters={300066,300774,300777,300778,300779,300786}
        expected={(p['group'],tuple(p['anchor'])) for p in props['maps']['59520'] if props['groups'][p['group']]['master'] in masters}
        self.assertEqual({(r['group'],tuple(r['anchor'])) for r in data['rails']},expected)
        for row in data['rails']:
            placement=next(p for p in props['maps']['59520'] if p['group']==row['group'])
            self.assertEqual(row['anchor'],placement['anchor'])
            g=props['groups'][row['group']];x,y,w,h=g['rect']
            original=Image.open(ROOT/('assets/maps/falan/elsa/props/atlas-%d.png'%g['page'])).convert('RGBA').crop((x,y,x+w,y+h))
            fitted=Image.open(folder/(row['group']+'.png')).convert('RGBA')
            difference=ImageChops.multiply(ImageChops.difference(fitted,original).convert('RGB'),original.getchannel('A').convert('RGB'))
            self.assertIsNone(difference.getbbox(),'Original opaque foreground rail pixels remain exact')
            if row['group']=='294':
                inferred=row['hidden_continuation'];self.assertEqual(inferred['shift'],[17,19])
                mask=Image.open(folder/inferred['mask']).convert('L')
                template=props['groups'][inferred['template']];tx,ty,tw,th=template['rect']
                art=Image.open(ROOT/('assets/maps/falan/elsa/props/atlas-%d.png'%template['page'])).convert('RGBA').crop((tx,ty,tx+tw,ty+th))
                shifted=Image.new('RGBA',original.size);shifted.paste(art,tuple(inferred['shift']))
                self.assertIsNotNone(mask.getbbox())
                self.assertIsNone(ImageChops.multiply(mask,original.getchannel('A')).getbbox())
                self.assertIsNone(ImageChops.multiply(ImageChops.difference(fitted,shifted).convert('RGB'),mask.convert('RGB')).getbbox(),'Inferred continuation uses exact original motif pixels')
        for name,row in data['materials'].items():
            u,v,w,h=row['rect'];tile=Image.open(folder/(name+'.png')).convert('RGB');crop=native.crop((u-RECT[0],v-RECT[1],u-RECT[0]+w,v-RECT[1]+h))
            self.assertIsNone(ImageChops.multiply(ImageChops.difference(tile,crop.convert('RGB')),crop.getchannel('A').convert('RGB')).getbbox())

    def test_landmark_floor_keeps_native_tile_extents_and_shore_profiles(self):
        from prepare_elsa_landmark_floor import RECT
        folder=ROOT/'assets/maps/falan/elsa/scenery/landmark-floor'
        data=json.loads((folder/'data.json').read_text())
        repair=Image.open(folder/'repair-mask.png').convert('L')
        exterior=Image.open(folder/'tower-exterior-mask.png').convert('L')
        native=Image.open(folder/'original-background.png').convert('RGBA')
        floor=Image.open(folder/'floor.png').convert('RGBA')
        infill=Image.open(folder/'ground-infill.png').getchannel('A')
        domain=Image.open(folder/'floor-domain-mask.png').convert('L')
        self.assertIsNotNone(infill.getbbox())
        self.assertIsNone(ImageChops.multiply(infill,native.getchannel('A')).getbbox(),'Occluded infill never flattens opaque native shore/ground')
        self.assertIsNone(ImageChops.multiply(infill,ImageChops.invert(domain)).getbbox(),'Occluded infill stays within its recorded floor domain')
        # Actual fixed-camera probe previously hit no mesh at this point: the
        # original tower photo had been erased over blocked island ground.
        point=(round(7101.67138671875)-RECT[0],round(-2565.76049804688)-RECT[1])
        self.assertGreater(domain.getpixel(point),0)
        self.assertGreater(floor.getpixel(point)[3],0)
        rgb=ImageChops.difference(native,floor).convert('RGB')
        self.assertIsNone(ImageChops.multiply(rgb,ImageChops.invert(repair).convert('RGB')).getbbox())
        w,h,planes=recovery.reference_map(59520)
        shore=json.loads((folder.parent/'data.json').read_text())['shore']['placements']
        pages={}
        self.assertGreater(len(data['placements']),0)
        self.assertTrue(any(row['shoreline'] for row in data['placements'].values()))
        for token,row in data['placements'].items():
            index=int(token);self.assertEqual(row['serial'],planes[0][index])
            art,origin,_=recovery.cut_image(59520,planes[0][index])
            self.assertEqual(row['origin'],list(origin))
            self.assertEqual(row['rect'][2:],list(art.size))
            self.assertEqual(row['shoreline'],token in shore)
            if row['page'] not in pages:pages[row['page']]=Image.open(folder/('atlas-%d.png'%row['page'])).convert('RGBA')
            x,y,tw,th=row['rect'];actual=pages[row['page']].crop((x,y,x+tw,y+th))
            left=(index%w+index//w)*32+origin[0]-RECT[0]
            top=(index//w-index%w)*24+origin[1]-RECT[1]
            box=(left,top,left+tw,top+th)
            outside=ImageChops.invert(repair.crop(box)).convert('RGB')
            self.assertIsNone(ImageChops.multiply(ImageChops.difference(actual,art).convert('RGB'),outside).getbbox())
            self.assertEqual(actual.getchannel('A').tobytes(),ImageChops.subtract(art.getchannel('A'),exterior.crop(box)).tobytes())
            self.assertEqual(hashlib.sha256(art.tobytes()).hexdigest(),row['source_sha256'])
            self.assertEqual(hashlib.sha256(actual.tobytes()).hexdigest(),row['rgba_sha256'])

    def test_return_stone_preserves_its_original_idle_animation(self):
        folder=ROOT/'assets/maps/falan/elsa/scenery/return-stone';data=json.loads((folder/'data.json').read_text())
        ident,_,clips=recovery.cg.actor(data['key']);clip=next(c for c in clips if c['index']==data['clip'])
        self.assertEqual(ident,110500);self.assertEqual(data['frames'],len(clip['frames']));self.assertEqual(data['duration'],clip['duration'])
        self.assertEqual((data['frames'],data['duration']),(4,500))
        atlas=Image.open(folder/'atlas.png').convert('RGBA');self.assertEqual(hashlib.sha256(atlas.tobytes()).hexdigest(),data['rgba_sha256'])
        for i in range(data['frames']):
            art,x,y=recovery.cg.frame_parts(data['key'],data['clip'],i)
            left=i*data['size'][0]+x-data['origin'][0];top=y-data['origin'][1]
            actual=atlas.crop((left,top,left+art.width,top+art.height))
            self.assertEqual(actual.tobytes(),art.tobytes())


if __name__=='__main__':unittest.main()
