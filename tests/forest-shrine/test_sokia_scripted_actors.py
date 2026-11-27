"""The two humanoid bosses retain exact coherent source actors and native cue clocks."""
import hashlib
import json
from pathlib import Path
import sys
import unittest

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from prepare_sokia_scripted_actors import records
from test_sokia_blood_demon_source import verify_source,cg


def source_signature(key):
    ident,_,clips=cg.actor(key);lookup={(c['action'],c['direction']):c for c in clips}
    digest=hashlib.sha256();frames=0
    for action in [0,3,5,8,10,1,9]:
        for direction in range(8):
            clip=lookup[action,direction]
            digest.update(json.dumps([action,direction,clip['duration'],[f[3]for f in clip['frames']]]).encode())
            for i in range(len(clip['frames'])):
                image,x,y=cg.frame_parts(key,clip['index'],i);box=image.getbbox();assert box
                crop=image.crop(box);digest.update(json.dumps([crop.size,x+box[0],y+box[1]]).encode());digest.update(crop.tobytes());frames+=1
    return ident,frames,digest.hexdigest()


class ScriptedActorSource(unittest.TestCase):
    def test_coherent_original_records_match_existing_playable_source(self):
        for original,playable in [('original:2719','joy:754'),('original:2737','joy:598')]:
            self.assertEqual(source_signature(original),source_signature(playable))

    def test_source_pixels_origins_clips_and_native_contacts(self):
        result=verify_source(ROOT/'assets/characters/crossgate/sokia_region',records(),16)
        self.assertEqual(result,dict(actors=2,clips=112,frames=792,cues=32))

    def test_existing_playable_pixel_scales_are_retained(self):
        jet,maze=records()
        self.assertEqual((jet['key'],jet['source_body_pixels'],jet['height']),('original:2719',88,88/86))
        self.assertEqual((maze['key'],maze['source_body_pixels'],maze['height']),('original:2737',82,82/83))
        from prepare_sokia_population import prepare
        _,data=prepare()
        for skin in [16,17]:
            member=data['base_species_count']+skin
            self.assertFalse(any(m[0]==member for g in data['groups'].values()for m in g['members']))


if __name__=='__main__':unittest.main()
