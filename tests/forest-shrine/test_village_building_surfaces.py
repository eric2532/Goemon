import hashlib
import sys
import tempfile
import unittest
from pathlib import Path
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from build_village_building_surfaces import build, PATCHES, CELL, INSET
from build_east_road import build as road


class VillagePaintTest(unittest.TestCase):
    def test_recovery_is_repeatable_and_preserves_original_paint(self):
        source=ROOT/'assets/maps/falan'
        names=[f'{v}_{kind}' for v in ['il','alyut'] for kind in ['buildings.png','restoration_data.gd']]
        before={n:hashlib.sha256((source/n).read_bytes()).hexdigest() for n in names}
        with tempfile.TemporaryDirectory() as folder:
            output=Path(folder)
            for n in names:(output/n).write_bytes((source/n).read_bytes())
            build(output)
            first=(output/'village_building_surfaces.png').read_bytes()
            build(output)
            self.assertEqual(first,(output/'village_building_surfaces.png').read_bytes())
            self.assertEqual(first,(source/'village_building_surfaces.png').read_bytes())
            image=Image.open(output/'village_building_surfaces.png')
            for i,(name,(_,_,feature,_)) in enumerate(PATCHES.items()):
                x,y=i%4*CELL,i//4*CELL
                tile=image.crop((x+INSET,y+INSET,x+CELL-INSET,y+CELL-INSET))
                if not feature:self.assertEqual(tile.getchannel('A').getextrema(),(255,255),name)
                else:self.assertGreater(tile.getchannel('A').getbbox()[2],0,name)
            self.assertEqual(before,{n:hashlib.sha256((output/n).read_bytes()).hexdigest() for n in names})

    def test_joined_bridge_reuses_existing_source_cells(self):
        source=ROOT/'assets/maps/falan'
        with tempfile.TemporaryDirectory() as folder:
            output=Path(folder)
            for n in ['east_approach_surface.png','east_coast_surface.png']:(output/n).write_bytes((source/n).read_bytes())
            road(output)
            joined=Image.open(output/'east_road_surface.png')
            coast=Image.open(source/'east_coast_surface.png')
            gate=Image.open(source/'east_approach_surface.png')
            self.assertEqual(joined.size,(386,459))
            self.assertEqual(joined.getpixel((66,100)),gate.getpixel((1,100)))
            for x,y in [(100,160),(150,200),(250,120)]:
                self.assertEqual(joined.getpixel((320-y,138+x)),coast.getpixel((x,y)))
            self.assertEqual((output/'east_road_surface.png').read_bytes(),(source/'east_road_surface.png').read_bytes())


if __name__=='__main__':unittest.main()
