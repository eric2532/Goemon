"""Protect reviewed keys, native contact markers, archive limits and original sprite samples."""
import json
import re
import struct
import sys
import unittest
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
ASSETS=ROOT/'assets/characters/crossgate'
SOURCE=ROOT.parent/'Magic Power'
CONFIG=json.loads((ROOT/'tools/crossgate_pet_families.json').read_text())


class CompanionFamiliesTest(unittest.TestCase):
    def test_reviewed_catalog_and_contacts(self):
        data=json.loads((ASSETS/'guard_pets/motions.json').read_text())
        expected=[v for f in CONFIG['families'] for v in f['variants']]
        catalog=json.loads((ASSETS/'companions/catalog.json').read_text())
        self.assertEqual(catalog['profiles'],[{k:v[k] for k in ('body','visual_scale')} for v in expected])
        for family in CONFIG['families']:
            variants=json.loads((ASSETS/'companions'/family['folder']/'motions.json').read_text())['variants']
            self.assertEqual([(v['key'],v['body'],v['visual_scale']) for v in variants],
                             [(v['key'],v['body'],v['visual_scale']) for v in family['variants']])
        self.assertEqual(len(CONFIG['families']),24)
        self.assertEqual([(v['id'],v['key']) for v in data['variants'][82:]],[(v['id'],v['key']) for v in expected])
        self.assertEqual(len({v['key'] for v in data['variants']}),len(data['variants']))
        self.assertTrue(set(v['key'] for v in expected).isdisjoint(v['key'] for v in CONFIG['unresolved']))
        stride=data['timeline_stride']
        native=(ROOT/'native/terrain_math/crowd/kits.h').read_text()
        self.assertEqual(stride,int(re.search(r'HOUND_TIMELINE_STRIDE=(\d+)',native)[1]))
        self.assertEqual(len(data['timelines']),len(data['variants'])*8*stride)
        count=len(data['variants'])
        for file,pattern in [('scripts/forest/pet_catalog.gd',r'const COUNT=(\d+)'),('scripts/forest/crowd/pet_dimensions.gd',r'const COMPANION_SKINS=(\d+)'),('native/terrain_math/crowd/kits.h',r'HOUND_SKINS=(\d+)'),('assets/materials/hound_sprite.gdshaderinc',r'pet_scales\[(\d+)\]')]:
            self.assertEqual(int(re.search(pattern,(ROOT/file).read_text())[1]),count,file)
        self.assertEqual(next(v['key'] for v in expected if v['id']==120200),'joy-ex:124')
        for i,(variant,profile) in enumerate(zip(data['variants'][82:],expected),82):
            for field in ['label','category','effect','xl','visual_scale','body']:
                self.assertEqual(variant[field],profile[field])
            self.assertGreater(variant['visual_scale'],0)
            for axis in range(3):self.assertGreater(variant['body'][axis+3],variant['body'][axis])
            with Image.open(ROOT/variant['portrait_path'].removeprefix('res://')) as image:
                cell=variant['portrait_cell'];x=cell%5*96;y=cell//5*96
                self.assertIsNotNone(image.crop((x,y,x+96,y+96)).getbbox())
            for clip in variant['clips']:
                if clip.get('unavailable'):self.assertNotIn(clip['action'],[0,3,5,8,10,1])
            for direction,cues in enumerate(variant['attack_directions']):
                at=(i*8+direction)*stride;row=data['timelines'][at:at+stride]
                self.assertEqual(row[1],len(cues));self.assertLessEqual(row[1],(stride-2)//2)
                self.assertTrue(any(q['contact'] for q in cues))
                for n,cue in enumerate(cues):
                    self.assertAlmostEqual(row[2+n*2],cue['atMs']*.03)
                    self.assertEqual(row[3+n*2],cue['id']+(10000 if cue['contact'] else 20000))
                self.assertEqual(row[2+len(cues)*2:],[0]*(stride-2-len(cues)*2))
        self.assertTrue(any(int(data['timelines'][at+1])==14 for at in range(0,len(data['timelines']),stride)))
        water=next(v for v in data['variants'] if v['id']==101512)
        self.assertTrue(all([q['id'] for q in cues if q['contact']]==[265] for cues in water['attack_directions']))

    def test_judas_exact_keys_archives_and_movement(self):
        bosses=next(f['variants'] for f in CONFIG['families'] if f['folder']=='bosses')
        self.assertEqual(len(bosses),36)
        self.assertTrue(all(v['category']=='bosses' for v in bosses))
        self.assertEqual(sum('Archive ' in v['label'] for v in bosses),12)
        self.assertEqual(sum(v['run_action']==1 for v in bosses),31)
        self.assertEqual(sum('motion_key' in v for v in bosses),12)
        self.assertTrue(all(v.get('motion_key')==f"original:{2976+v['id']-101930}" for v in bosses if 'motion_key' in v))
        keys={v['key'] for v in bosses}
        self.assertTrue({'puk3:916','puk3:920','v3:951','update-ex:1980','original:1395','original:605'}.issubset(keys))
        self.assertNotIn('puk3:834',keys)
        data=json.loads((ASSETS/'guard_pets/motions.json').read_text())
        self.assertEqual([v['key']for v in data['variants'][398:434]],[v['key']for v in bosses])
        self.assertTrue({'puk3:839','puk3:920'}.issubset({v['key'] for v in data['variants'] if v['id']==109896}))

    def test_judas_archive_duplicates_match_complete_gameplay(self):
        folder=ASSETS/'companions/bosses'
        data=json.loads((folder/'motions.json').read_text())
        rows=list(struct.iter_unpack('<4f',(folder/'frames.bin').read_bytes()))
        indices={v['key']:i for i,v in enumerate(data['variants'])}
        with Image.open(folder/'palette.png') as palette:
            duplicates=0
            for i,variant in enumerate(data['variants']):
                if 'motion_key' not in variant:continue
                duplicates+=1;other=indices[variant['motion_key']];canonical=data['variants'][other]
                for field in ['body','visual_scale','attack_directions']:self.assertEqual(variant[field],canonical[field])
                for action in [0,variant['run_action'],5,8,10,1]:
                    for direction in range(8):
                        a=rows[(i*len(data['actions'])+data['actions'].index(action))*8+direction]
                        b=rows[(other*len(data['actions'])+data['actions'].index(action))*8+direction]
                        self.assertEqual(a[1:],b[1:])
                        for frame in range(int(a[1])):
                            x=rows[data['clip_count']+(int(a[0])+frame)*2:data['clip_count']+(int(a[0])+frame)*2+2]
                            y=rows[data['clip_count']+(int(b[0])+frame)*2:data['clip_count']+(int(b[0])+frame)*2+2]
                            self.assertEqual(x[0],y[0]);self.assertEqual(x[1][:3],y[1][:3])
                            self.assertEqual(palette.crop((0,int(x[1][3]),256,int(x[1][3])+1)).tobytes(),
                                             palette.crop((0,int(y[1][3]),256,int(y[1][3])+1)).tobytes())
        self.assertEqual(duplicates,12)

    def test_bear_rewards_only_a_and_s_with_original_contacts(self):
        family=next(f for f in CONFIG['families'] if f['folder']=='bear_challenge')
        self.assertEqual(len(family['variants']),73)
        self.assertTrue(all(v['category']=='灰熊厲害' for v in family['variants']))
        self.assertTrue(all(r['medals'].split()[-1] in {'A','S'} for v in family['variants'] for r in v['rewards']))
        keys={v['key'] for v in family['variants']}
        self.assertTrue({'v3:1688','ex:1670','joy-ex:821','joy:773','joy:901','puk3:8','puk3:9'}.issubset(keys))
        self.assertTrue(keys.isdisjoint({'joy:312','puk3:620','puk2:988','ch1:942','ex:1819','joy-ex:1089','ex:971'}))
        data=json.loads((ASSETS/'companions/bear_challenge/motions.json').read_text())
        for key in ['puk3:8','puk3:9']:
            variant=next(v for v in data['variants'] if v['key']==key)
            self.assertTrue(all([(c['id'],c['frame']) for c in cues if c['contact']]==[(0,6)] for cues in variant['attack_directions']))
        self.assertTrue({11,12,13,14,15,16,17,18,19,20}.issubset(data['actions']))

    def test_bear_s_rewards_append_without_duplicate_choices(self):
        family=next(f for f in CONFIG['families'] if f['folder']=='bear_challenge_s')
        self.assertEqual(len(family['variants']),24)
        self.assertTrue(all(v['category']=='灰熊厲害' and
                            all(r['medals'].endswith(' S') for r in v['rewards'])
                            for v in family['variants']))
        combined=json.loads((ASSETS/'guard_pets/motions.json').read_text())['variants']
        self.assertEqual([v['key'] for v in combined[563:587]],[v['key'] for v in family['variants']])
        self.assertEqual(next(v['label'] for v in combined if v['key']=='puk3:580'),'XL · 大可愛優奈')
        typhon=next(v for v in family['variants'] if v['key']=='joy:3')
        self.assertEqual([r['name'] for r in typhon['rewards']],['堤風R','堤風'])
        self.assertNotIn('ex:971',{v['key'] for v in combined})
        for variant in combined[563:587]:
            for direction in variant['attack_directions']:
                self.assertTrue(all(c['contact']==(10000<=c['flag']<20000) for c in direction))
        shigure=next(v for v in combined if v['key']=='ex:688')
        for direction in shigure['attack_directions']:
            self.assertEqual(len(direction),20)
            self.assertEqual([c['frame'] for c in direction if c['contact']],[46])

    def test_bear_a_rewards_keep_both_bone_dragons_and_original_cues(self):
        family=CONFIG['families'][-1]
        self.assertEqual(family['folder'],'bear_challenge_a')
        self.assertEqual(len(family['variants']),30)
        combined=json.loads((ASSETS/'guard_pets/motions.json').read_text())['variants']
        rewards={v['key']:v for v in combined[587:]}
        self.assertEqual(list(rewards),[v['key'] for v in family['variants']])
        self.assertTrue(all(v['category']=='灰熊厲害' and
                            all(r['medals'].endswith(' A') for r in v['rewards'])
                            for v in family['variants']))
        self.assertEqual([rewards[key]['label'] for key in ['puk2:39','puk2:40']],['灼熱龍骨R','冰凍龍骨R'])
        crowned=family['variants'][-1]
        self.assertEqual(combined[455]['key'],'ex:1101')
        self.assertEqual((combined[616]['key'],crowned['label']),('ex:1102','蘿蔔兔（皇冠）'))
        self.assertEqual(crowned['identity_proof']['pixelHash'],crowned['identity_proof']['referencePixelHash'])
        for variant in rewards.values():
            for direction in variant['attack_directions']:
                self.assertTrue(all(c['contact']==(10000<=c['flag']<20000) for c in direction))
        for direction in rewards['ch1:528']['attack_directions']:
            self.assertTrue(any(c['id']==152 for c in direction))
        self.assertEqual([c['frames'] for c in rewards['puk3:724']['clips'] if c['action']==8],[0]*8)
        rows=list(struct.iter_unpack('<4f',(ASSETS/'guard_pets/frames.bin').read_bytes()))
        start=next(i for i,v in enumerate(combined) if v['key']=='puk3:724')*48
        self.assertEqual(rows[start+24:start+32],rows[start:start+8])

    def test_sponsor_rewards_preserve_56_sources_and_exclude_b(self):
        family=next(f for f in CONFIG['families'] if f['folder']=='sponsor')
        self.assertEqual(len(family['variants']),56)
        self.assertTrue(all(v['category']=='贊助' for v in family['variants']))
        self.assertTrue(all(r['rarity']!='B' for v in family['variants'] for r in v['rewards']))
        data=json.loads((ASSETS/'companions/sponsor/motions.json').read_text())
        combined=json.loads((ASSETS/'guard_pets/motions.json').read_text())
        self.assertEqual([v['key'] for v in combined['variants'][507:563]],[v['key'] for v in family['variants']])
        keys={v['key'] for v in family['variants']}
        self.assertTrue({'joy-ex:963','ex:1081','puk2:500','ch1:71','puk2:783','v3:807','puk2:777'}.issubset(keys))
        self.assertTrue(keys.isdisjoint(v['key'] for v in combined['variants'][:507]))
        self.assertFalse(any(r['name']=='卡拉龜' for v in family['variants'] for r in v['rewards']))
        for key,sound,directions in [('ex:1081',332,6),('puk2:500',321,8),('puk2:485',321,8)]:
            variant=next(v for v in data['variants'] if v['key']==key)
            cues=[q for row in variant['attack_directions'] for q in row if q['id']==sound]
            self.assertEqual(len(cues),directions)
            self.assertTrue(all(q['frame']==1 and not q['contact'] and q['missing_audio'] for q in cues))
            self.assertNotIn(str(sound),data['sounds'])
        raikou=next(v for v in family['variants'] if v['key']=='joy-ex:963')
        correction=raikou['graphic_dimensions']['joy-ex']['436171']
        self.assertEqual(correction['original'][5:7],[100,153])
        self.assertEqual(correction['size'],[96,149])

    @unittest.skipUnless((SOURCE/'tools/cg_assets.py').exists(),'Original source archive is not attached')
    def test_original_pixels_anchors_and_motion_samples(self):
        sys.path.insert(0,str(SOURCE/'tools'))
        import cg_assets as cg
        for family in CONFIG['families']:
            folder=ASSETS/'companions'/family['folder']
            data=json.loads((folder/'motions.json').read_text())
            rows=list(struct.iter_unpack('<4f',(folder/'frames.bin').read_bytes()))
            pages=[Image.open(folder/f'atlas-{i}.png').convert('L') for i in range(data['pages'])]
            palette=Image.open(folder/'palette.png').convert('RGBA')
            for skin,variant in enumerate(data['variants']):
                for pack,corrections in variant.get('graphic_dimensions',{}).items():
                    cg.graphic_dimensions().setdefault(pack,{}).update(corrections)
                motion_key=variant.get('motion_key',variant['key'])
                ident,_,source=cg.actor(motion_key);self.assertEqual(ident,variant['id'])
                clips={(c['action'],c['direction']):c for c in source}
                shift=(10 if variant['xl'] else 0)+variant.get('ground_shift',0)
                for action in [0,3,5,8,10,1]:
                    for direction in range(8):
                        clip=clips[action,direction]
                        at=(skin*len(data['actions'])+data['actions'].index(action))*8+direction
                        start,count,duration,pixel_size=rows[at]
                        self.assertEqual(count,len(clip['frames']))
                        self.assertAlmostEqual(duration,clip['duration']/1000,places=5)
                        self.assertAlmostEqual(pixel_size,.0375/(2 if variant['xl'] else 1),places=7)
                        if not count:
                            self.assertEqual((variant['key'],action),('puk3:724',8))
                            continue
                        samples={0,len(clip['frames'])//2,len(clip['frames'])-1}
                        if variant['key']=='joy-ex:963' and action==10 and direction==1:samples.add(9)
                        for frame in samples:
                            expected,x,y=cg.frame_parts(motion_key,clip['index'],frame)
                            bounds=expected.getbbox()
                            if bounds:x+=bounds[0];y+=bounds[1];expected=expected.crop(bounds)
                            else:expected=Image.new('RGBA',(1,1))
                            rect,placement=rows[data['clip_count']+(int(start)+frame)*2:data['clip_count']+(int(start)+frame)*2+2]
                            left,top,width,height=map(int,rect);ox,oy,page,color=map(int,placement)
                            indices=pages[page].crop((left,top,left+width,top+height))
                            actual=Image.frombytes('P',indices.size,indices.tobytes())
                            actual.putpalette(palette.crop((0,color,256,color+1)).tobytes(),'RGBA')
                            actual=actual.convert('RGBA')
                            self.assertEqual((ox,oy),(x,y-shift),variant['key'])
                            self.assertEqual(actual.size,expected.size,variant['key'])
                            normalized=Image.new('RGBA',expected.size);normalized.paste(expected,(0,0),expected.getchannel('A'))
                            self.assertEqual(actual.tobytes(),normalized.tobytes(),variant['key'])
            for page in pages:page.close()


if __name__=='__main__':unittest.main()
