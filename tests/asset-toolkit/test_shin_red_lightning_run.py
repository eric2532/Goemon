"""The prepared run carries the original blade with the native sword hand."""
import hashlib
import json
import math
from pathlib import Path
from shutil import copyfile
import sys
from tempfile import TemporaryDirectory
import unittest

from PIL import Image, ImageChops, ImageDraw, ImageFilter

PROJECT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(PROJECT / "tools"))
import prepare_shin_red_lightning_run as run


def prepared_frames(folder, data, direction):
    pages = [Image.open(folder / f"atlas-{i}.png").convert("RGBA") for i in range(data["pages"])]
    pages += [Image.open(folder / f"cast-{i}.png").convert("RGBA") for i in range(data["cast_pages"])]
    result = []
    for page, x, y, w, h, ox, oy in data["clips"][f"3:{direction}"]["frames"]:
        image = Image.new("RGBA", run.SIZE)
        image.alpha_composite(pages[page].crop((x, y, x+w, y+h)), (128+ox, 160+oy))
        result.append(image)
    for page in pages:
        page.close()
    return result


class RedLightningRun(unittest.TestCase):
    def test_native_sword_hand_body_and_visible_blade_in_all_facings(self):
        folder = run.ROOT / "118993"
        data = json.loads((folder / "motions.json").read_text())
        donor = json.loads((run.ROOT / "100181/motions.json").read_text())
        reference = json.loads((run.ROOT / "100193/motions.json").read_text())
        sword = next(s for s in donor["weapons"] if s["weapon"] == "sword")
        white = next(s for s in reference["weapons"] if s["weapon"] == "sword")
        self.assertEqual(data["run_reuse"]["source_id"], sword["source_id"])
        self.assertEqual(data["run_reuse"]["key"], sword["key"])
        self.assertEqual(data["run_reuse"]["part"], "sword_run")
        self.assertEqual(data["run_reuse"]["occluded_facings"], [7])
        for direction in range(8):
            key = f"3:{direction}"
            self.assertEqual(data["clips"][key]["duration"], .5)
            self.assertEqual(len(data["clips"][key]["frames"]), 6)
            originals = run.canvases(folder, data, {"clips": data["original_run"]}, 3, direction)
            bodies = run.canvases(run.ROOT / "100181", donor, sword, 3, direction)
            bare = run.canvases(run.ROOT / "100181", donor, donor, 3, direction)
            refs = run.canvases(run.ROOT / "100193", reference, white, 3, direction)
            bare_refs = run.canvases(run.ROOT / "100193", reference, reference, 3, direction)
            walks = run.canvases(run.ROOT / "100181", donor, sword, 1, direction)
            edited = Image.new("L",run.SIZE)
            for walk in walks:edited=ImageChops.lighter(edited,walk.getchannel("A"))
            edited=ImageChops.offset(edited.filter(ImageFilter.MaxFilter(13)),0,1)
            ImageDraw.Draw(edited).polygon(run.BLADES[direction],fill=255)
            directions = []
            for index, actual in enumerate(prepared_frames(folder, data, direction)):
                body, unarmed = bodies[index], bare[index]
                hand = (147,118)
                start=end=None
                if run.RUN_BLADES[direction]:
                    (start,end,_),_ = run.blade_axis(refs[index],bare_refs[index],run.RUN_BLADES[direction])
                    hand = start
                    vx,vy = end[0]-start[0],end[1]-start[1]
                    directions.append((vx/math.hypot(vx,vy),vy/math.hypot(vx,vy)))
                    # The original glowing weapon must reach the native blade tip.
                    near_tip = [actual.getpixel((x,y)) for y in range(round(end[1])-4,round(end[1])+6)
                                for x in range(round(end[0])-4,round(end[0])+5)]
                    self.assertGreater(sum(a>0 and r>140 and r>g*1.4 and r>b*1.3 for r,g,b,a in near_tip),2,
                                       (direction,index,"Original red blade follows the native sword"))
                preserved = grip = 0
                for y in range(run.SIZE[1]-1):
                    for x in range(run.SIZE[0]):
                        pixel = body.getpixel((x,y))
                        # Shared body pixels and colored hands/arms cannot be cut for the blade.
                        if pixel[3] and (pixel == unarmed.getpixel((x,y)) or max(pixel[:3])>=80):
                            self.assertEqual(actual.getpixel((x,y+1)),pixel,(direction,index,x,y))
                            preserved += 1
                            if math.hypot(x-hand[0],y-hand[1])<(12 if direction==7 else 8) and max(pixel[:3])>=80:
                                grip += 1
                self.assertGreater(preserved,800)
                self.assertGreater(grip,3,(direction,index,"Native wrist/hilt stays intact"))
                # Uncovered outer aura retains exact pixels and ground origins.
                original = originals[index*len(originals)//6]
                outer = 0
                for y in range(run.SIZE[1]):
                    for x in range(run.SIZE[0]):
                        if edited.getpixel((x,y)) or (y>0 and body.getpixel((x,y-1))[3]):continue
                        if start is not None:
                            dx,dy=x-start[0],y-start[1]-1
                            length=math.hypot(end[0]-start[0],end[1]-start[1])
                            along=(dx*directions[-1][0]+dy*directions[-1][1])
                            across=abs(dx*directions[-1][1]-dy*directions[-1][0])
                            if -20<along<length*2.2+20 and across<25:continue
                        if (pixel:=original.getpixel((x,y)))[3]:
                            self.assertEqual(actual.getpixel((x,y)),pixel,(direction,index,"outer aura",x,y))
                            outer += 1
                self.assertGreater(outer,0)
            if directions:
                self.assertTrue(all(x*directions[0][0]+y*directions[0][1]>math.cos(math.radians(10))
                                    for x,y in directions),f"Facing {direction} has no spurious blade rotation")

    def test_rebuild_is_repeatable_and_preserves_original_pages(self):
        folder = run.ROOT / "118993"
        with TemporaryDirectory() as temporary:
            staged = Path(temporary)
            for path in [folder / "motions.json", *folder.glob("*.png")]:
                copyfile(path, staged / path.name)
            def hashes():
                return {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in staged.iterdir()}
            before = hashes()
            run.prepare(staged)
            once = hashes()
            run.prepare(staged)
            self.assertEqual(hashes(),once)
            self.assertEqual(once,before)


if __name__ == "__main__":
    unittest.main()
