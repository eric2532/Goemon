"""Independent client-byte, source-encounter and new bomb-frame preservation checks."""
import base64
import hashlib
import json
import struct
import sys
import unittest
import zlib
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
ARCHIVE = ROOT.parent / "Magic Power"
sys.dont_write_bytecode = True
sys.path.insert(0, str(ARCHIVE / "tools"))
sys.path.insert(0, str(ROOT / "tools"))
import cg_assets as cg
import cg_library as lib
import cg_sounds
from recover_habaru_encounter import body_rows


class JenovaBeastSource(unittest.TestCase):
    def test_well_stone_preserves_source_except_the_occluding_posts(self):
        from recover_western_building_surfaces import well_paint
        folder=ROOT/'assets/maps/original_crossgate'
        data=json.loads((folder/'catalog.json').read_text());g=data['graphics']['11393'];x,y,w,h=g['rect']
        original=Image.open(folder/data['pages'][g['page']]).convert('RGBA').crop((x,y,x+w,y+h))
        image,proof=well_paint()
        self.assertEqual(Image.open(folder/'jenova-well-stone.png').convert('RGBA').tobytes(),image.tobytes())
        self.assertEqual(original.getchannel('A').tobytes(),image.getchannel('A').tobytes())
        changed=0
        for y in range(h):
            for x in range(w):
                if original.getpixel((x,y))==image.getpixel((x,y)):continue
                r,g,b,a=original.getpixel((x,y))
                self.assertTrue(21<=x<112 and 105<=y<167 and a>0 and r>40 and r>g*1.35 and r>b*1.5)
                changed+=1
        self.assertGreater(changed,0)
        self.assertEqual(changed,proof['reconstructed_pixels'])

    def test_jenova_wall_crops_exclude_the_raised_porch(self):
        import recover_western_building_surfaces as surfaces
        atlas, _, proof = surfaces.prepare()
        folder = ROOT / 'assets/maps/original_crossgate'
        self.assertEqual(Image.open(folder / 'building-surfaces.png').tobytes(), atlas.tobytes())
        self.assertEqual(json.loads((folder / 'building-surfaces.json').read_text()), json.loads(json.dumps(proof)))
        self.assertEqual(proof['patches']['jenova_11400_left'][1], [(28,170),(144,250),(144,331),(28,251)])
        self.assertEqual(proof['patches']['jenova_11400_right'][1], [(145,253),(293,151),(293,239),(145,341)])
        from prepare_tina_roof_underlay import prepare
        roof, provenance = prepare(11404)
        self.assertEqual(Image.open(ROOT / 'assets/maps/falan/tina/buildings/11404-main-roof.png').tobytes(), roof.tobytes())
        self.assertEqual(provenance['source_graphic'], 11404)

    def test_castle_carvings_recover_source_faces_and_raised_depth(self):
        folder=ROOT/'assets/maps/original_crossgate'
        original=Image.open(folder/'beast-castle.png').convert('RGBA')
        atlas=Image.open(folder/'beast-castle-carvings.png').convert('RGBA')
        depth=Image.open(folder/'beast-castle-carvings-depth.png').convert('L')
        proof=json.loads((folder/'beast-castle-carvings.json').read_text())
        self.assertEqual(proof['frieze_left']['quad'],[[204,60],[253,92],[253,112],[204,80]])
        for name,row in proof.items():
            ul,ur,lr,ll=row['quad'];x,y,w,h=row['rect']
            expected=original.transform((w,h),Image.Transform.QUAD,(*ul,*ll,*lr,*ur),Image.Resampling.BICUBIC)
            self.assertEqual(atlas.crop((x,y,x+w,y+h)).tobytes(),expected.tobytes(),name)
            self.assertEqual(hashlib.sha256(expected.tobytes()).hexdigest(),row['rgba_sha256'])
            relief=depth.crop((x,y,x+w,y+h))
            self.assertEqual(relief.getextrema(),(0,255))
            self.assertEqual(relief.crop((0,0,w,1)).getextrema(),(0,0))
            self.assertGreater(row['rise'],0)
        surfaces=Image.open(folder/'beast-castle-sculpture-surfaces.png').convert('RGBA')
        for box,quad in [((264,8,375,119),(390,370,390,402,458,353,443,333)),
                         ((8,264,119,375),(116,299,116,320,129,329,129,308)),
                         ((136,264,247,375),(28,440,28,458,49,472,49,454))]:
            expected=original.transform((111,111),Image.Transform.QUAD,quad,Image.Resampling.BICUBIC)
            self.assertEqual(surfaces.crop(box).tobytes(),expected.tobytes())

    def test_portal_columns_use_their_own_original_paint(self):
        folder=ROOT/'assets/maps/original_crossgate'
        original=Image.open(folder/'beast-castle.png').convert('RGBA')
        atlas=Image.open(folder/'beast-castle-columns.png').convert('RGBA')
        mask=Image.open(folder/'beast-castle-mask.png').convert('RGB')
        for pixel in [(361,480),(410,450)]:self.assertEqual(mask.getpixel(pixel),(255,0,255))
        for i,quad in enumerate([(356,454,356,531,366,524,366,447),(404,424,404,501,414,494,414,417)]):
            expected=original.transform((128,256),Image.Transform.QUAD,quad,Image.Resampling.BICUBIC)
            self.assertEqual(atlas.crop((i*128,0,(i+1)*128,256)).tobytes(),expected.tobytes())

    def test_separate_castle_banners_preserve_the_original_geometry_mask(self):
        folder=ROOT/'assets/maps/original_crossgate'
        original=Image.open(folder/'beast-castle.png').convert('RGBA')
        mask=Image.open(folder/'beast-castle-mask.png').convert('RGB')
        self.assertEqual(mask.getchannel('R').tobytes(),original.getchannel('A').tobytes())
        self.assertEqual(mask.getchannel('B').tobytes(),original.getchannel('A').tobytes())
        self.assertEqual(mask.getpixel((340,500)),(255,0,255))
        self.assertEqual(mask.getpixel((470,415)),(255,0,255))
        self.assertEqual(mask.getpixel((280,400))[0],mask.getpixel((280,400))[1])
        atlas=Image.open(folder/'beast-castle-sculpture-surfaces.png').convert('RGBA')
        for box,quad in [((8,136,119,247),(331,451,331,558,349,545,349,438)),
                         ((136,136,247,247),(460,363,460,472,479,461,479,352))]:
            expected=original.transform((111,111),Image.Transform.QUAD,quad,Image.Resampling.BICUBIC)
            self.assertEqual(atlas.crop(box).tobytes(),expected.tobytes())

    def test_armor_body_uses_all_four_original_silhouettes(self):
        import math
        import re
        folder=ROOT/'assets/maps/original_crossgate'
        proof=json.loads((folder/'beast-sculptures-core.json').read_text())
        for serial,angle in proof['views'].items():
            camera_x=-math.cos(angle)-math.sin(angle)
            self.assertLess(camera_x,0) if int(serial) in (16193,16194) else self.assertGreater(camera_x,0)
            for name in ('crest_anchors','grip_anchors'):
                self.assertGreater(proof[name][serial]['samples'],0)
        data=(folder/'beast-sculptures.gd').read_text()
        raw=zlib.decompress(base64.b64decode(re.search(r'const CORE_FACES="([^"]+)"',data)[1]))
        self.assertEqual(len(raw),proof['bytes']);self.assertGreater(proof['voxels'],3000)
        records=json.loads((folder/'beast-sculptures.json').read_text())
        paint=Image.open(folder/'beast-sculptures.png').convert('RGBA')
        masks={int(n):paint.crop((g['rect'][0],g['rect'][1],g['rect'][0]+g['rect'][2],g['rect'][1]+g['rect'][3])) for n,g in records.items()}
        vertical=math.sqrt(2*((32/3)**2-64))
        for i,j,k in {tuple(raw[n:n+3]) for n in range(0,len(raw),4)}:
            x=proof['origin'][0]+(i+.5)*proof['step'];y=(j+.5)*proof['step'];z=proof['origin'][2]+(k+.5)*proof['step']
            for n,(xx,zz) in {16193:(x,z),16194:(z,-x),16195:(-z,x),16196:(-x,-z)}.items():
                origin=records[str(n)]['origin']
                u=math.floor((xx+zz)*32/3-origin[0]);v=math.floor((zz-xx)*8-y*vertical-origin[1])
                self.assertGreater(masks[n].getpixel((u,v))[3],0)

    def test_original_armor_sculpture_paint(self):
        folder=ROOT/'assets/maps/original_crossgate'
        records=json.loads((folder/'beast-sculptures.json').read_text())
        atlas=Image.open(folder/'beast-sculptures.png').convert('RGBA')
        native=Image.open(folder/'beast-sculptures-native.png').convert('RGBA')
        parts=Image.open(folder/'beast-sculptures-parts.png').convert('L')
        for serial,record in records.items():
            original=lib.image_from_record(record['pack'],record['row'])
            x,y,w,h=record['rect'];box=(x,y,x+w,y+h)
            self.assertEqual(native.crop(box).tobytes(),original.tobytes())
            self.assertEqual(hashlib.sha256(original.tobytes()).hexdigest(),record['rgba_sha256'])
            removed=0
            for a,b in zip(original.getdata(),atlas.crop(box).getdata()):
                self.assertEqual(a[:3],b[:3])
                if a[3]!=b[3]:
                    self.assertEqual((a,b),((71,71,71,255),(71,71,71,0)))
                    removed+=1
            self.assertEqual(removed,record['removed_ground_shadow_pixels'])
            shaft=record['lance_line'];labels=parts.crop(box)
            for py in range(shaft['body_start_y'],h):
                for px in range(w):
                    if labels.getpixel((px,py))==1:
                        self.assertLessEqual(abs(px-shaft['x_at_zero']-shaft['x_per_y']*py),2)

    def test_client_cells_are_authoritative(self):
        catalog = json.loads((ROOT / "assets/maps/original_crossgate/catalog.json").read_text())
        restored = 0
        for path, row in catalog["maps"].items():
            if row["group"] not in ("jenova", "beast", "beast_cache") and path != "BlueCrossgate/map/0/400.dat":
                continue
            with lib.connection() as db:
                ident = db.execute("SELECT id FROM files WHERE path=?", (path,)).fetchone()[0]
            original = lib.source_file(ident)[1].read_bytes()
            raw = zlib.decompress(base64.b64decode(row["raw"]))
            self.assertEqual(raw, original)
            self.assertEqual(hashlib.sha256(raw).hexdigest(), row["sha256"])
            if "restored_raw" not in row:
                continue
            complete = zlib.decompress(base64.b64decode(row["restored_raw"]))
            w, h, f, o, flags = lib.parse_map(raw)
            _, _, ff, oo, new_flags = lib.parse_map(complete)
            self.assertEqual(flags, new_flags)
            for i, flag in enumerate(flags):
                if flag & 0xC000:
                    self.assertEqual((f[i], o[i]), (ff[i], oo[i]), (path, i%w, i//w))
            reference = ROOT / "build/Other Files/Asset Toolkit/Jenova Beast Recovery/Source" / Path(row["completion_reference"]["path"]).name
            self.assertEqual(hashlib.sha256(reference.read_bytes()).hexdigest(), row["completion_reference"]["sha256"])
            self.assertEqual(hashlib.sha256(complete).hexdigest(), row["restored_sha256"])
            restored += 1
        self.assertEqual(restored, 20)
        self.assertEqual(len(catalog["beast_templates"]), 33)
        for row in catalog["beast_templates"]:
            source = catalog["maps"][row["path"]]
            raw = zlib.decompress(base64.b64decode(source["raw"]))
            w,h,f,o,_ = lib.parse_map(raw)
            self.assertIn(1191, f); self.assertIn(17065, o)
            self.assertEqual(o[row["up"][1]*w+row["up"][0]], 12000)
            self.assertEqual(o[row["down"][1]*w+row["down"][0]], 12002)

    def test_reference_roster_and_original_castle_paint(self):
        catalog = json.loads((ROOT / "assets/maps/original_crossgate/catalog.json").read_text())
        proof = catalog["beast_encounters"]
        self.assertEqual(proof["patrols"], [["original:2906","大炸彈"],["original:2935","大地翼龍"]])
        self.assertEqual(proof["levels"], [35,37])
        self.assertEqual((proof["boss"]["key"],proof["boss"]["level"]), ("original:2820",50))
        self.assertEqual(proof["boss"]["ai"],200018)
        self.assertEqual(proof["encounter"][0], proof["dungeon_config"][49])
        self.assertEqual(proof["dungeon_config"][9:12], ["16510","25","7"])
        self.assertEqual(proof["dungeon_config"][15:18], ["16511","26","72"])
        self.assertEqual(proof["dungeon_config"][39:41], ["12","12"])
        image = Image.open(ROOT / "assets/maps/original_crossgate/beast-castle.png").convert("RGBA")
        self.assertEqual(hashlib.sha256(image.tobytes()).hexdigest(), catalog["beast_castle"]["rgba_sha256"])
        self.assertEqual(catalog["beast_castle"]["source_pieces"], 71)

    def test_passage_outlines_follow_original_alpha(self):
        catalog = json.loads((ROOT / "assets/maps/original_crossgate/catalog.json").read_text())
        for serial in (10045,10046,16468,16467):
            record = catalog["graphics"][str(serial)]
            source = lib.image_from_record(record["pack"],record["row"])
            outline = record["solid_outline"]
            self.assertGreater(len(outline),100)
            half = len(outline)//2
            for (left,y),(right,yy) in zip(outline[:half],reversed(outline[half:])):
                self.assertEqual(y,yy)
                visible = [x for x in range(source.width) if source.getpixel((x,y))[3]>=128]
                self.assertEqual((left,right),(min(visible),max(visible)+1))

    def test_original_bomb_frames_origins_clocks_contacts_and_audio(self):
        folder = ROOT / "assets/characters/crossgate/beast_maze"
        data = json.loads((folder / "motions.json").read_text())
        raw = (folder / "frames.bin").read_bytes()
        pages = [Image.open(folder/f"atlas-{i}.png").convert("L") for i in range(data["pages"])]
        palette = Image.open(folder/"palette.png").convert("RGBA")
        colors = [palette.getpixel((i,0)) for i in range(256)]
        ident,_,source_clips = cg.actor("original:2906")
        self.assertEqual(ident,101522)
        self.assertEqual(data["variants"][0]["id"],ident)
        clips = {(c["action"],c["direction"]):c for c in source_clips}
        idle,_,oy = cg.frame_parts("original:2906",clips[0,4]["index"],0)
        _,foot = body_rows(idle); shift = oy+foot-10
        audio = json.loads((ARCHIVE/"godot/assets/sounds/manifest.json").read_text())["sounds"]
        frames = 0
        for action_index,action in enumerate(data["actions"]):
            for direction in range(8):
                clip = clips[action,direction]
                row = action_index*8+direction
                start,count,duration,_ = struct.unpack_from("<4f",raw,row*16)
                self.assertEqual(int(count),len(clip["frames"]))
                self.assertAlmostEqual(duration,clip["duration"]/1000,places=6)
                for frame in range(int(count)):
                    at = (data["clip_count"]+(int(start)+frame)*2)*16
                    x,y,w,h = map(round,struct.unpack_from("<4f",raw,at))
                    ox,py,page,pal = map(round,struct.unpack_from("<4f",raw,at+16))
                    source,sx,sy = cg.frame_parts("original:2906",clip["index"],frame)
                    bounds = source.getbbox(); source = source.crop(bounds)
                    self.assertEqual((ox,py),(sx+bounds[0],sy+bounds[1]-shift))
                    self.assertEqual((w,h),source.size); self.assertEqual(pal,0)
                    decoded = bytes(v for i in pages[page].crop((x,y,x+w,y+h)).tobytes() for v in colors[i])
                    expected = bytes(v for p in source.getdata() for v in (p if p[3] else (0,0,0,0)))
                    self.assertEqual(decoded,expected,(action,direction,frame)); frames += 1
                if action != 5:
                    continue
                cues = cg_sounds.clip_cues(clip)
                self.assertEqual(data["timelines"][direction*28:direction*28+2],[clip["duration"]*.03,len(cues)])
                for cue_index,cue in enumerate(cues):
                    contact = 10000 <= cue["flag"] < 20000
                    opcode = 135 if contact else 106
                    self.assertEqual(data["timelines"][direction*28+2+cue_index*2:direction*28+4+cue_index*2],[cue["atMs"]*.03,opcode])
                    self.assertEqual((folder/data["sounds"][f"0:{opcode}"]).read_bytes(),(ARCHIVE/"godot/assets"/audio[str(cue["id"])]["file"]).read_bytes())
        print("BEAST_BOMB_SOURCE",frames,"original frames, eight facings, clocks, contacts and audio verified")


if __name__ == "__main__":
    unittest.main()
